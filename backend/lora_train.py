import shutil
import time
import uuid
import threading
from pathlib import Path
from typing import Optional, Callable

import torch
from torch.amp import GradScaler, autocast
from diffusers import StableDiffusionPipeline, DDPMScheduler
from peft import LoraConfig, get_peft_model
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image


class ImageDataset(Dataset):
    def __init__(self, image_dir: str, size: int = 512):
        self.paths = (
            list(Path(image_dir).glob("*.png"))
            + list(Path(image_dir).glob("*.jpg"))
            + list(Path(image_dir).glob("*.jpeg"))
        )
        if not self.paths:
            raise FileNotFoundError(f"이미지가 없습니다: {image_dir}")
        self.transform = transforms.Compose([
            transforms.Resize((size, size)),
            transforms.ToTensor(),
            transforms.Normalize([0.5], [0.5]),
        ])

    def __len__(self):
        return len(self.paths)

    def __getitem__(self, idx):
        img = Image.open(self.paths[idx]).convert("RGB")
        return self.transform(img)


class LoRATrainer:
    def __init__(self):
        self._jobs: dict[str, dict] = {}

    def start_training(
        self,
        base_model_path: str,
        image_dir: str,
        output_name: str,
        steps: int = 1000,
        learning_rate: float = 1e-4,
        network_rank: int = 32,
        output_dir: str = "models/lora",
        progress_callback: Optional[Callable] = None,
    ) -> str:
        job_id = str(uuid.uuid4())
        self._jobs[job_id] = {
            "status": "running",
            "step": 0,
            "total": steps,
            "elapsed": 0,
            "error": None,
        }

        thread = threading.Thread(
            target=self._train,
            args=(job_id, base_model_path, image_dir, output_name,
                  steps, learning_rate, network_rank, output_dir, progress_callback),
            daemon=True,
        )
        thread.start()
        return job_id

    def get_status(self, job_id: str) -> Optional[dict]:
        return self._jobs.get(job_id)

    def _train(
        self,
        job_id: str,
        base_model_path: str,
        image_dir: str,
        output_name: str,
        steps: int,
        learning_rate: float,
        network_rank: int,
        output_dir: str,
        progress_callback: Optional[Callable],
    ):
        start_time = time.time()
        job = self._jobs[job_id]

        try:
            pipeline = StableDiffusionPipeline.from_single_file(
                base_model_path,
                torch_dtype=torch.float32,  # 학습은 fp32 (GradScaler로 fp16 혼합)
                safety_checker=None,
                requires_safety_checker=False,
            ).to("cuda")

            # 학습 전용 DDPM 스케줄러 (add_noise 지원)
            noise_scheduler = DDPMScheduler.from_config(pipeline.scheduler.config)

            unet = pipeline.unet
            lora_config = LoraConfig(
                r=network_rank,
                lora_alpha=network_rank,
                target_modules=["to_q", "to_v", "to_k", "to_out.0"],
                lora_dropout=0.0,
                bias="none",
            )
            unet = get_peft_model(unet, lora_config)
            unet.train()

            # VAE, text_encoder는 고정
            pipeline.vae.requires_grad_(False)
            pipeline.text_encoder.requires_grad_(False)

            dataset = ImageDataset(image_dir)
            dataloader = DataLoader(dataset, batch_size=1, shuffle=True)

            optimizer = torch.optim.AdamW(unet.parameters(), lr=learning_rate)
            scaler = GradScaler("cuda")

            global_step = 0
            data_iter = iter(dataloader)

            while global_step < steps:
                try:
                    batch = next(data_iter)
                except StopIteration:
                    data_iter = iter(dataloader)
                    batch = next(data_iter)

                batch = batch.to("cuda")

                with torch.no_grad():
                    latents = pipeline.vae.encode(batch).latent_dist.sample() * 0.18215

                noise = torch.randn_like(latents)
                timesteps = torch.randint(
                    0, noise_scheduler.config.num_train_timesteps,
                    (latents.shape[0],), device="cuda"
                ).long()
                noisy_latents = noise_scheduler.add_noise(latents, noise, timesteps)

                with torch.no_grad():
                    encoder_hidden_states = pipeline.text_encoder(
                        pipeline.tokenizer(
                            [""] * batch.shape[0],
                            padding="max_length",
                            max_length=pipeline.tokenizer.model_max_length,
                            return_tensors="pt",
                        ).input_ids.to("cuda")
                    )[0]

                optimizer.zero_grad()
                with autocast("cuda"):
                    noise_pred = unet(noisy_latents, timesteps, encoder_hidden_states).sample
                    loss = torch.nn.functional.mse_loss(
                        noise_pred.float(), noise.float()
                    )

                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()

                global_step += 1
                job["step"] = global_step
                job["elapsed"] = time.time() - start_time

                if progress_callback:
                    progress_callback(job_id, global_step, steps)

            # LoRA 저장: 임시 디렉토리 → 단일 .safetensors 파일로 추출
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            tmp_dir = Path(output_dir) / f"_tmp_{output_name}"
            unet.save_pretrained(str(tmp_dir), safe_serialization=True)

            src = tmp_dir / "adapter_model.safetensors"
            dst = Path(output_dir) / f"{output_name}.safetensors"
            shutil.copy(str(src), str(dst))
            shutil.rmtree(str(tmp_dir))

            job["status"] = "completed"
            job["elapsed"] = time.time() - start_time

        except Exception as e:
            job["status"] = "failed"
            job["error"] = str(e)


trainer = LoRATrainer()
