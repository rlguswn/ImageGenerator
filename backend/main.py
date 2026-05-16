import io
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from PIL import Image
import base64

from sd_engine import engine
from lora_train import trainer
from port_check import find_available_port
from logger import get_logger

app = FastAPI(title="SD Local API")

CONFIG_PATH = Path("config.json")
SAFETY_PATH = Path(__file__).parent / "safety.json"
_generation_progress: dict = {}
PRESETS_PATH = Path("presets.json")
OUTPUT_DIR = Path("output")  # default; actual path is read from config at save time

log = get_logger()


def load_safety() -> dict:
    if SAFETY_PATH.exists():
        return json.loads(SAFETY_PATH.read_text(encoding="utf-8"))
    return {}


def check_prompt(prompt: str) -> Optional[str]:
    """블록리스트 키워드 포함 시 에러 메시지 반환, 통과 시 None."""
    safety = load_safety()
    pf = safety.get("prompt_filter", {})
    if not pf.get("enabled", False):
        return None
    lower = prompt.lower()
    for kw in pf.get("keywords", []):
        if kw.lower() in lower:
            return pf.get("error_message", "허용되지 않는 프롬프트입니다.")
    return None


@app.on_event("startup")
async def on_startup():
    config = load_config()
    log_cfg = config.get("log", {})
    global log
    log = get_logger(
        retention_days=log_cfg.get("retention_days", 60),
        max_file_size_mb=log_cfg.get("max_file_size_mb", 10),
    )
    log.info("앱 시작")


@app.on_event("shutdown")
async def on_shutdown():
    log.info("앱 종료")


def load_config() -> dict:
    if CONFIG_PATH.exists():
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    return {}


def save_config(data: dict):
    CONFIG_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def load_presets() -> dict:
    if PRESETS_PATH.exists():
        return json.loads(PRESETS_PATH.read_text(encoding="utf-8"))
    return {"presets": []}


def save_presets(data: dict):
    PRESETS_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def save_image_with_metadata(images: list[Image.Image], metadata: dict) -> list[str]:
    config = load_config()
    output_dir = Path(config.get("output", {}).get("output_path", "output"))
    output_dir.mkdir(parents=True, exist_ok=True)
    saved = []
    base_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    for i, img in enumerate(images):
        suffix = f"_{i + 1}" if len(images) > 1 else ""
        img_path = output_dir / f"{base_ts}{suffix}.png"
        counter = 1
        while img_path.exists():
            img_path = output_dir / f"{base_ts}{suffix}_{counter}.png"
            counter += 1
        json_path = img_path.with_suffix(".json")
        png_info = Image.Exif()
        safety = load_safety()
        ai_meta = safety.get("ai_metadata", {})
        if ai_meta.get("enabled", False):
            from PIL.PngImagePlugin import PngInfo
            png_meta = PngInfo()
            png_meta.add_text(ai_meta.get("png_info_key", "AI-Generated"), ai_meta.get("png_info_value", "true"))
            png_meta.add_text("Software", ai_meta.get("software_tag", "ImageGenerator"))
            img.save(img_path, "PNG", pnginfo=png_meta)
        else:
            img.save(img_path, "PNG")
        json_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
        saved.append(str(img_path))
    return saved


# ─── 요청/응답 스키마 ─────────────────────────────────────────────

class LoadModelRequest(BaseModel):
    model_path: str
    precision: str = "fp16"
    vram_optimization: bool = False
    cpu_offload: bool = False


class Txt2ImgRequest(BaseModel):
    prompt: str
    negative_prompt: str = ""
    width: int = 512
    height: int = 512
    steps: int = 20
    cfg_scale: float = 7.0
    seed: int = -1
    batch_size: int = 1
    clip_skip: int = 1
    sampler: str = "DPM++ 2M Karras"
    loras: list = []


class Img2ImgRequest(BaseModel):
    prompt: str
    negative_prompt: str = ""
    image_base64: str
    denoising_strength: float = 0.75
    width: int = 512
    height: int = 512
    steps: int = 20
    cfg_scale: float = 7.0
    seed: int = -1
    batch_size: int = 1
    clip_skip: int = 1
    sampler: str = "DPM++ 2M Karras"
    resize_mode: str = "Just resize"
    loras: list = []


class InpaintRequest(BaseModel):
    prompt: str
    negative_prompt: str = ""
    image_base64: str
    mask_base64: str
    denoising_strength: float = 0.75
    width: int = 512
    height: int = 512
    steps: int = 20
    cfg_scale: float = 7.0
    seed: int = -1
    clip_skip: int = 1
    sampler: str = "DPM++ 2M Karras"
    loras: list = []


class LoRATrainRequest(BaseModel):
    image_dir: str
    output_name: str
    steps: int = 1000
    learning_rate: float = 1e-4
    network_rank: int = 32


class PresetSaveRequest(BaseModel):
    name: str
    mode: str
    prompt: str
    negative_prompt: str = ""
    settings: dict = {}
    lora: list = []


# ─── 엔드포인트 ──────────────────────────────────────────────────

@app.get("/health")
def health():
    config = load_config()
    return {
        "status": "ok",
        "model_loaded": engine.loaded_model_path is not None,
        "model_path": engine.loaded_model_path,
        "pipeline_mode": engine.pipeline_mode,
        "cuda_available": torch.cuda.is_available(),
        "vram_total": torch.cuda.get_device_properties(0).total_memory // 1024**2 if torch.cuda.is_available() else 0,
        "vram_free": (torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated(0)) // 1024**2 if torch.cuda.is_available() else 0,
    }


@app.post("/model/load")
def load_model(req: LoadModelRequest):
    messages = []
    log.info(f"모델 로딩 시작: {req.model_path}")
    try:
        def on_progress(msg):
            messages.append(msg)
            log.info(msg)
        engine.load_model(
            model_path=req.model_path,
            precision=req.precision,
            vram_optimization=req.vram_optimization,
            cpu_offload=req.cpu_offload,
            progress_callback=on_progress,
        )
        safety = load_safety()
        sc = safety.get("safety_checker", {})
        if sc.get("enabled", False):
            engine.apply_safety_checker(
                checkpoint=sc.get("checkpoint", "CompVis/stable-diffusion-safety-checker"),
                feature_extractor=sc.get("feature_extractor", "openai/clip-vit-base-patch32"),
                progress_callback=on_progress,
            )
        else:
            engine.remove_safety_checker()
        return {"status": "ok", "messages": messages}
    except Exception as e:
        log.error(f"모델 로딩 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/txt2img")
def txt2img(req: Txt2ImgRequest):
    if not engine.pipeline:
        raise HTTPException(status_code=400, detail="모델이 로딩되지 않았습니다")
    if err := check_prompt(req.prompt):
        raise HTTPException(status_code=400, detail=err)

    config = load_config()
    lora_dir = config.get("model", {}).get("lora_path", "models/lora")
    start = time.time()
    global _generation_progress
    _generation_progress = {}
    try:
        def on_progress(p):
            global _generation_progress
            _generation_progress = p
        images, seed = engine.txt2img(
            prompt=req.prompt,
            negative_prompt=req.negative_prompt,
            width=req.width,
            height=req.height,
            steps=req.steps,
            cfg_scale=req.cfg_scale,
            seed=req.seed,
            batch_size=req.batch_size,
            clip_skip=req.clip_skip,
            sampler=req.sampler,
            loras=req.loras,
            lora_dir=lora_dir,
            progress_callback=on_progress,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    generation_time = round(time.time() - start, 1)
    log.info(f"txt2img 생성 완료 ({generation_time}s) seed:{seed}")
    metadata = {
        "date": datetime.now().isoformat(),
        "mode": "txt2img",
        "prompt": req.prompt,
        "negative_prompt": req.negative_prompt,
        "model": engine.loaded_model_path,
        "lora": req.loras,
        "settings": {
            "width": req.width, "height": req.height,
            "steps": req.steps, "cfg_scale": req.cfg_scale,
            "sampler": req.sampler, "seed": seed, "clip_skip": req.clip_skip,
        },
        "generation_time": generation_time,
    }
    paths = save_image_with_metadata(images, metadata)

    encoded = []
    for img in images:
        buf = io.BytesIO()
        img.save(buf, "PNG")
        encoded.append(base64.b64encode(buf.getvalue()).decode())

    return {"images": encoded, "seed": seed, "generation_time": generation_time, "paths": paths}


@app.post("/img2img")
def img2img(req: Img2ImgRequest):
    if not engine.img2img_pipeline:
        raise HTTPException(status_code=400, detail="모델이 로딩되지 않았습니다")
    if err := check_prompt(req.prompt):
        raise HTTPException(status_code=400, detail=err)

    try:
        img_data = base64.b64decode(req.image_base64)
        init_image = Image.open(io.BytesIO(img_data))
    except Exception:
        raise HTTPException(status_code=400, detail="이미지 디코딩 실패")

    config = load_config()
    lora_dir = config.get("model", {}).get("lora_path", "models/lora")
    start = time.time()
    global _generation_progress
    _generation_progress = {}
    try:
        def on_progress(p):
            global _generation_progress
            _generation_progress = p
        images, seed = engine.img2img(
            init_image=init_image,
            prompt=req.prompt,
            negative_prompt=req.negative_prompt,
            denoising_strength=req.denoising_strength,
            width=req.width,
            height=req.height,
            steps=req.steps,
            cfg_scale=req.cfg_scale,
            seed=req.seed,
            batch_size=req.batch_size,
            clip_skip=req.clip_skip,
            sampler=req.sampler,
            resize_mode=req.resize_mode,
            loras=req.loras,
            lora_dir=lora_dir,
            progress_callback=on_progress,
        )
    except Exception as e:
        log.error(f"img2img 생성 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    generation_time = round(time.time() - start, 1)
    log.info(f"img2img 생성 완료 ({generation_time}s) seed:{seed}")
    metadata = {
        "date": datetime.now().isoformat(),
        "mode": "img2img",
        "prompt": req.prompt,
        "negative_prompt": req.negative_prompt,
        "model": engine.loaded_model_path,
        "lora": req.loras,
        "settings": {
            "width": req.width, "height": req.height,
            "steps": req.steps, "cfg_scale": req.cfg_scale,
            "sampler": req.sampler, "seed": seed, "clip_skip": req.clip_skip,
            "denoising_strength": req.denoising_strength,
        },
        "generation_time": generation_time,
    }
    paths = save_image_with_metadata(images, metadata)

    encoded = []
    for img in images:
        buf = io.BytesIO()
        img.save(buf, "PNG")
        encoded.append(base64.b64encode(buf.getvalue()).decode())

    return {"images": encoded, "seed": seed, "generation_time": generation_time, "paths": paths}


@app.post("/inpaint")
def inpaint(req: InpaintRequest):
    if not engine.pipeline:
        raise HTTPException(status_code=400, detail="모델이 로딩되지 않았습니다")
    if err := check_prompt(req.prompt):
        raise HTTPException(status_code=400, detail=err)

    if engine.pipeline_mode != "inpaint":
        config = load_config()
        cpu_offload = config.get("vram_optimization", False) and config.get("cpu_offload", False)
        try:
            engine.switch_to_inpaint(cpu_offload=cpu_offload)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"인페인트 파이프라인 전환 실패: {e}")

    try:
        img_data = base64.b64decode(req.image_base64)
        init_image = Image.open(io.BytesIO(img_data))
        mask_data = base64.b64decode(req.mask_base64)
        mask_image = Image.open(io.BytesIO(mask_data))
    except Exception:
        raise HTTPException(status_code=400, detail="이미지 디코딩 실패")

    config = load_config()
    lora_dir = config.get("model", {}).get("lora_path", "models/lora")
    start = time.time()
    global _generation_progress
    _generation_progress = {}
    try:
        def on_progress(p):
            global _generation_progress
            _generation_progress = p
        images, seed = engine.inpaint(
            init_image=init_image,
            mask_image=mask_image,
            prompt=req.prompt,
            negative_prompt=req.negative_prompt,
            denoising_strength=req.denoising_strength,
            width=req.width,
            height=req.height,
            steps=req.steps,
            cfg_scale=req.cfg_scale,
            seed=req.seed,
            clip_skip=req.clip_skip,
            sampler=req.sampler,
            loras=req.loras,
            lora_dir=lora_dir,
            progress_callback=on_progress,
        )
    except Exception as e:
        log.error(f"inpaint 생성 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    generation_time = round(time.time() - start, 1)
    log.info(f"inpaint 생성 완료 ({generation_time}s) seed:{seed}")
    metadata = {
        "date": datetime.now().isoformat(),
        "mode": "inpaint",
        "prompt": req.prompt,
        "negative_prompt": req.negative_prompt,
        "model": engine.loaded_model_path,
        "lora": req.loras,
        "settings": {
            "width": req.width, "height": req.height,
            "steps": req.steps, "cfg_scale": req.cfg_scale,
            "sampler": req.sampler, "seed": seed, "clip_skip": req.clip_skip,
            "denoising_strength": req.denoising_strength,
        },
        "generation_time": generation_time,
    }
    paths = save_image_with_metadata(images, metadata)

    encoded = []
    for img in images:
        buf = io.BytesIO()
        img.save(buf, "PNG")
        encoded.append(base64.b64encode(buf.getvalue()).decode())

    return {"images": encoded, "seed": seed, "generation_time": generation_time, "paths": paths}


@app.get("/generate/progress")
def get_progress():
    return _generation_progress


@app.post("/generate/cancel")
def cancel():
    engine.cancel()
    return {"status": "cancelled"}


@app.post("/lora/train")
def lora_train(req: LoRATrainRequest):
    config = load_config()
    base_model_path = engine.loaded_model_path
    if not base_model_path:
        raise HTTPException(status_code=400, detail="먼저 베이스 모델을 로딩하세요")

    log.info(f"LoRA 학습 시작: {req.output_name} ({req.steps}steps)")
    job_id = trainer.start_training(
        base_model_path=base_model_path,
        image_dir=req.image_dir,
        output_name=req.output_name,
        steps=req.steps,
        learning_rate=req.learning_rate,
        network_rank=req.network_rank,
        output_dir=config.get("model", {}).get("lora_path", "models/lora"),
    )
    return {"job_id": job_id}


@app.get("/lora/status/{job_id}")
def lora_status(job_id: str):
    status = trainer.get_status(job_id)
    if status is None:
        raise HTTPException(status_code=404, detail="job_id를 찾을 수 없습니다")
    return status


@app.get("/lora/list")
def lora_list():
    config = load_config()
    lora_dir = Path(config.get("model", {}).get("lora_path", "models/lora"))
    files = list(lora_dir.glob("*.safetensors")) if lora_dir.exists() else []
    return {"loras": [f.stem for f in files]}


@app.get("/presets")
def get_presets():
    return load_presets()


@app.post("/presets")
def save_preset(req: PresetSaveRequest):
    data = load_presets()
    preset_id = f"preset_{int(time.time() * 1000)}"
    preset = {
        "id": preset_id,
        "name": req.name,
        "mode": req.mode,
        "prompt": req.prompt,
        "negative_prompt": req.negative_prompt,
        "settings": req.settings,
        "lora": req.lora,
        "created_at": datetime.now().isoformat(),
    }
    data["presets"].append(preset)
    save_presets(data)
    return {"status": "ok", "id": preset_id}


@app.delete("/presets/{preset_id}")
def delete_preset(preset_id: str):
    data = load_presets()
    original_len = len(data["presets"])
    data["presets"] = [p for p in data["presets"] if p["id"] != preset_id]
    if len(data["presets"]) == original_len:
        raise HTTPException(status_code=404, detail="프리셋을 찾을 수 없습니다")
    save_presets(data)
    return {"status": "ok"}


@app.get("/config")
def get_config():
    return load_config()


@app.put("/config")
def put_config(data: dict):
    save_config(data)
    return {"status": "ok"}


@app.get("/models/base")
def list_base_models():
    config = load_config()
    base_dir = Path(config.get("model", {}).get("base_model_path", "models/base"))
    if not base_dir.exists():
        return {"models": []}
    files = list(base_dir.glob("*.safetensors")) + list(base_dir.glob("*.ckpt"))
    return {"models": [f.name for f in files]}


@app.get("/debug/port/{port_number}")
def debug_port(port_number: int):
    """해당 포트를 점유 중인 프로세스 정보를 반환합니다."""
    from port_check import is_port_available, get_port_process
    if is_port_available(port_number):
        return {"port": port_number, "status": "available", "process": None}
    proc = get_port_process(port_number)
    return {"port": port_number, "status": "in_use", "process": proc}


@app.get("/debug/logs")
def get_debug_logs(lines: int = 100, level: str = "all"):
    """최근 로그를 반환합니다. level: all | error"""
    log_dir = Path("logs")
    if not log_dir.exists():
        return {"logs": []}

    if level == "error":
        log_file = log_dir / "error.log"
        if not log_file.exists():
            return {"logs": []}
        all_lines = log_file.read_text(encoding="utf-8").splitlines()
        return {"logs": all_lines[-lines:], "file": "error.log"}

    today = __import__("datetime").date.today().strftime("%Y-%m-%d")
    candidates = sorted(log_dir.glob(f"{today}*.log"), reverse=True)
    if not candidates:
        candidates = sorted(log_dir.glob("*.log"), key=lambda f: f.stat().st_mtime, reverse=True)
        candidates = [f for f in candidates if f.name != "error.log"]

    if not candidates:
        return {"logs": []}

    log_file = candidates[0]
    all_lines = log_file.read_text(encoding="utf-8").splitlines()
    return {"logs": all_lines[-lines:], "file": log_file.name}


if __name__ == "__main__":
    import uvicorn
    import sys

    config = load_config()
    port = config.get("server", {}).get("port", 8000)
    auto_search = config.get("server", {}).get("auto_port_search", True)

    if auto_search:
        from port_check import find_available_port, is_port_available, get_port_process
        if not is_port_available(port):
            proc = get_port_process(port)
            if proc:
                print(f"포트 {port} 사용 중 — PID {proc['pid']} ({proc['name']}): {proc['cmdline'][:80]}")
            port = find_available_port(port)
            print(f"포트 변경: {port}")

    print(f"서버 시작: http://127.0.0.1:{port}")
    uvicorn.run(app, host="127.0.0.1", port=port)
