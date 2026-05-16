import gc
import time
import threading
from pathlib import Path
from typing import Optional, Callable

import torch
from diffusers import (
    StableDiffusionPipeline,
    StableDiffusionImg2ImgPipeline,
    StableDiffusionInpaintPipeline,
    DPMSolverMultistepScheduler,
)
from PIL import Image


SAMPLERS = {
    "DPM++ 2M Karras": lambda config: DPMSolverMultistepScheduler.from_config(
        config, use_karras_sigmas=True
    ),
    "DPM++ 2M": lambda config: DPMSolverMultistepScheduler.from_config(config),
}


class SDEngine:
    def __init__(self):
        self.pipeline: Optional[StableDiffusionPipeline] = None
        self.img2img_pipeline: Optional[StableDiffusionImg2ImgPipeline] = None
        self.inpaint_pipeline: Optional[StableDiffusionInpaintPipeline] = None
        self.pipeline_mode: str = "default"
        self.loaded_model_path: Optional[str] = None
        self.loaded_loras: dict[str, float] = {}
        self._cancel_event = threading.Event()
        self._lock = threading.Lock()

    @staticmethod
    def _cache_dir(model_path: str, precision: str) -> Path:
        stem = Path(model_path).stem
        return Path(model_path).parent.parent / "cache" / f"{stem}_{precision}"

    def load_model(
        self,
        model_path: str,
        precision: str = "fp16",
        vram_optimization: bool = False,
        cpu_offload: bool = False,
        progress_callback: Optional[Callable[[str], None]] = None,
    ):
        def log(msg):
            if progress_callback:
                progress_callback(msg)

        dtype = torch.float16 if precision == "fp16" else torch.float32
        cache_dir = self._cache_dir(model_path, precision)
        start = time.time()

        if cache_dir.exists() and (cache_dir / "model_index.json").exists():
            log("캐시에서 모델 로딩 중...")
            self.pipeline = StableDiffusionPipeline.from_pretrained(
                str(cache_dir),
                torch_dtype=dtype,
                safety_checker=None,
                requires_safety_checker=False,
            )
        else:
            log("SD 모델 로딩 중 (최초 실행, 캐시 생성)...")
            self.pipeline = StableDiffusionPipeline.from_single_file(
                model_path,
                torch_dtype=dtype,
                safety_checker=None,
                requires_safety_checker=False,
            )
            log("캐시 저장 중...")
            cache_dir.mkdir(parents=True, exist_ok=True)
            self.pipeline.save_pretrained(str(cache_dir))
            log("캐시 저장 완료")

        if cpu_offload:
            self.pipeline.enable_model_cpu_offload()
        else:
            self.pipeline = self.pipeline.to("cuda")

        if vram_optimization:
            self.pipeline.enable_attention_slicing()
            self.pipeline.enable_vae_slicing()

        self.img2img_pipeline = StableDiffusionImg2ImgPipeline(
            vae=self.pipeline.vae,
            text_encoder=self.pipeline.text_encoder,
            tokenizer=self.pipeline.tokenizer,
            unet=self.pipeline.unet,
            scheduler=self.pipeline.scheduler,
            safety_checker=None,
            feature_extractor=None,
            requires_safety_checker=False,
        )
        if not cpu_offload:
            self.img2img_pipeline = self.img2img_pipeline.to("cuda")

        self.loaded_model_path = model_path
        self.inpaint_pipeline = None
        self.pipeline_mode = "default"
        elapsed = time.time() - start
        log(f"모델 로딩 완료 ({elapsed:.1f}s)")

    def apply_safety_checker(
        self,
        checkpoint: str = "CompVis/stable-diffusion-safety-checker",
        feature_extractor: str = "openai/clip-vit-base-patch32",
        progress_callback: Optional[Callable[[str], None]] = None,
    ):
        def log(msg):
            if progress_callback:
                progress_callback(msg)

        from transformers import CLIPFeatureExtractor
        from diffusers.pipelines.stable_diffusion.safety_checker import StableDiffusionSafetyChecker

        log("Safety checker 로딩 중...")
        checker = StableDiffusionSafetyChecker.from_pretrained(checkpoint)
        extractor = CLIPFeatureExtractor.from_pretrained(feature_extractor)

        for pipe in [self.pipeline, self.img2img_pipeline, self.inpaint_pipeline]:
            if pipe is not None:
                pipe.safety_checker = checker
                pipe.feature_extractor = extractor
        log("Safety checker 적용 완료")

    def remove_safety_checker(self):
        for pipe in [self.pipeline, self.img2img_pipeline, self.inpaint_pipeline]:
            if pipe is not None:
                pipe.safety_checker = None
                pipe.feature_extractor = None

    def _set_sampler(self, pipeline, sampler_name: str):
        if sampler_name in SAMPLERS:
            pipeline.scheduler = SAMPLERS[sampler_name](pipeline.scheduler.config)

    def _make_callback(self, total_steps: int, progress_callback: Optional[Callable]):
        step_times = []
        start_time = time.time()

        def callback(pipe, step_index, timestep, callback_kwargs):
            if self._cancel_event.is_set():
                pipe._interrupt = True
                return callback_kwargs

            now = time.time()
            step_times.append(now - start_time)

            if progress_callback and len(step_times) > 1:
                avg_step_time = (step_times[-1] - step_times[0]) / (len(step_times) - 1)
                remaining = avg_step_time * (total_steps - step_index)
                progress_callback({
                    "step": step_index + 1,
                    "total": total_steps,
                    "elapsed": now - start_time,
                    "eta": remaining,
                })
            return callback_kwargs

        return callback

    def apply_loras(self, loras: list[dict], lora_dir: str = "models/lora"):
        """loras: [{"name": "model_name", "weight": 0.8}, ...]"""
        if not self.pipeline:
            return

        for lora in loras:
            name = lora["name"]
            weight = lora.get("weight", 1.0)
            lora_path = Path(lora_dir) / f"{name}.safetensors"
            if lora_path.exists():
                self.pipeline.load_lora_weights(str(lora_path), adapter_name=name)
                self.loaded_loras[name] = weight

        if self.loaded_loras:
            names = list(self.loaded_loras.keys())
            weights = list(self.loaded_loras.values())
            self.pipeline.set_adapters(names, adapter_weights=weights)

    def unload_loras(self):
        if self.pipeline and self.loaded_loras:
            self.pipeline.unload_lora_weights()
            self.loaded_loras.clear()

    def txt2img(
        self,
        prompt: str,
        negative_prompt: str = "",
        width: int = 512,
        height: int = 512,
        steps: int = 20,
        cfg_scale: float = 7.0,
        seed: int = -1,
        batch_size: int = 1,
        clip_skip: int = 1,
        sampler: str = "DPM++ 2M Karras",
        loras: Optional[list] = None,
        lora_dir: str = "models/lora",
        progress_callback: Optional[Callable] = None,
    ) -> tuple[list[Image.Image], int]:
        if not self.pipeline:
            raise RuntimeError("모델이 로딩되지 않았습니다")

        self._cancel_event.clear()
        self.unload_loras()
        if loras:
            self.apply_loras(loras, lora_dir)

        self._set_sampler(self.pipeline, sampler)

        if seed == -1:
            seed = torch.randint(0, 2**32 - 1, (1,)).item()
        generator = torch.Generator("cuda").manual_seed(seed)

        callback = self._make_callback(steps, progress_callback)

        result = self.pipeline(
            prompt=prompt,
            negative_prompt=negative_prompt,
            width=width,
            height=height,
            num_inference_steps=steps,
            guidance_scale=cfg_scale,
            num_images_per_prompt=batch_size,
            generator=generator,
            clip_skip=clip_skip if clip_skip > 1 else None,
            callback_on_step_end=callback,
        )

        return result.images, seed

    def img2img(
        self,
        init_image: Image.Image,
        prompt: str,
        negative_prompt: str = "",
        denoising_strength: float = 0.75,
        width: int = 512,
        height: int = 512,
        steps: int = 20,
        cfg_scale: float = 7.0,
        seed: int = -1,
        batch_size: int = 1,
        clip_skip: int = 1,
        sampler: str = "DPM++ 2M Karras",
        resize_mode: str = "Just resize",
        loras: Optional[list] = None,
        lora_dir: str = "models/lora",
        progress_callback: Optional[Callable] = None,
    ) -> tuple[list[Image.Image], int]:
        if not self.img2img_pipeline:
            raise RuntimeError("모델이 로딩되지 않았습니다")

        self._cancel_event.clear()
        self.unload_loras()
        if loras:
            self.apply_loras(loras, lora_dir)

        self._set_sampler(self.img2img_pipeline, sampler)

        init_image = init_image.convert("RGB").resize((width, height))

        if seed == -1:
            seed = torch.randint(0, 2**32 - 1, (1,)).item()
        generator = torch.Generator("cuda").manual_seed(seed)

        callback = self._make_callback(steps, progress_callback)

        result = self.img2img_pipeline(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=init_image,
            strength=denoising_strength,
            num_inference_steps=steps,
            guidance_scale=cfg_scale,
            num_images_per_prompt=batch_size,
            generator=generator,
            clip_skip=clip_skip if clip_skip > 1 else None,
            callback_on_step_end=callback,
        )

        return result.images, seed

    def switch_to_inpaint(self, cpu_offload: bool = False):
        """기존 파이프라인 컴포넌트를 공유해 인페인트 파이프라인을 구성 (추가 VRAM 없음)."""
        if not self.pipeline:
            raise RuntimeError("먼저 모델을 로딩하세요")
        self.inpaint_pipeline = StableDiffusionInpaintPipeline(
            vae=self.pipeline.vae,
            text_encoder=self.pipeline.text_encoder,
            tokenizer=self.pipeline.tokenizer,
            unet=self.pipeline.unet,
            scheduler=self.pipeline.scheduler,
            safety_checker=None,
            feature_extractor=None,
            requires_safety_checker=False,
        )
        if not cpu_offload:
            self.inpaint_pipeline = self.inpaint_pipeline.to("cuda")
        self.pipeline_mode = "inpaint"

    def inpaint(
        self,
        init_image: Image.Image,
        mask_image: Image.Image,
        prompt: str,
        negative_prompt: str = "",
        denoising_strength: float = 0.75,
        width: int = 512,
        height: int = 512,
        steps: int = 20,
        cfg_scale: float = 7.0,
        seed: int = -1,
        clip_skip: int = 1,
        sampler: str = "DPM++ 2M Karras",
        loras: Optional[list] = None,
        lora_dir: str = "models/lora",
        progress_callback: Optional[Callable] = None,
    ) -> tuple[list[Image.Image], int]:
        if not self.inpaint_pipeline:
            raise RuntimeError("인페인트 파이프라인이 초기화되지 않았습니다")

        self._cancel_event.clear()
        self.unload_loras()
        if loras:
            self.apply_loras(loras, lora_dir)

        self._set_sampler(self.inpaint_pipeline, sampler)

        init_image = init_image.convert("RGB").resize((width, height))
        mask_image = mask_image.convert("L").resize((width, height))

        if seed == -1:
            seed = torch.randint(0, 2**32 - 1, (1,)).item()
        generator = torch.Generator("cuda").manual_seed(seed)

        callback = self._make_callback(steps, progress_callback)

        result = self.inpaint_pipeline(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=init_image,
            mask_image=mask_image,
            strength=denoising_strength,
            num_inference_steps=steps,
            guidance_scale=cfg_scale,
            generator=generator,
            clip_skip=clip_skip if clip_skip > 1 else None,
            callback_on_step_end=callback,
        )

        return result.images, seed

    def cancel(self):
        self._cancel_event.set()

    def unload(self):
        self.pipeline = None
        self.img2img_pipeline = None
        self.inpaint_pipeline = None
        self.pipeline_mode = "default"
        self.loaded_model_path = None
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()


engine = SDEngine()
