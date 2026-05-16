#!/usr/bin/env python3
"""
ImageGenerator 빌드 스크립트
사용법:
  python build.py                  # 전체 빌드
  python build.py --skip-backend   # Flutter + 패키징만
  python build.py --skip-frontend  # 백엔드 + 패키징만
  python build.py --skip-package   # 빌드만 (패키징 생략)
  python build.py --flutter-only   # Flutter 빌드만 (가장 자주 사용)
"""
import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.resolve()
APP_NAME = "ImageGenerator"
OUT_DIR = ROOT / "dist" / APP_NAME

CYAN   = "\033[96m"
YELLOW = "\033[93m"
GREEN  = "\033[92m"
RED    = "\033[91m"
GRAY   = "\033[90m"
RESET  = "\033[0m"

def log(msg, color=RESET):
    print(f"{color}{msg}{RESET}", flush=True)

def run(cmd: list[str], cwd=None):
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        log(f"오류: {' '.join(str(c) for c in cmd)}", RED)
        sys.exit(result.returncode)

def find_flutter() -> str:
    candidates = [
        r"D:\flutter\flutter\bin\flutter.bat",
        r"C:\flutter\bin\flutter.bat",
        shutil.which("flutter") or "",
        shutil.which("flutter.bat") or "",
    ]
    for c in candidates:
        if c and Path(c).exists():
            return c
    log("Flutter를 찾을 수 없습니다. PATH 또는 경로를 확인하세요.", RED)
    sys.exit(1)

def ensure_venv():
    venv_pip = ROOT / "venv" / "Scripts" / "pip.exe"
    if not venv_pip.exists():
        log("\n[0/3] 가상환경 생성 중...", YELLOW)
        run([sys.executable, "-m", "venv", str(ROOT / "venv")])
        req = ROOT / "requirements.txt"
        if req.exists():
            run([str(venv_pip), "install", "-r", str(req), "--quiet"])
        log("[0/3] 가상환경 준비 완료", GREEN)

def build_backend():
    log("\n[1/3] Python 백엔드 빌드 중...", YELLOW)
    pip = ROOT / "venv" / "Scripts" / "pip.exe"
    pyinstaller = ROOT / "venv" / "Scripts" / "pyinstaller.exe"
    run([str(pip), "install", "pyinstaller", "--quiet"])
    run([
        str(pyinstaller), str(ROOT / "backend.spec"),
        "--distpath", str(ROOT / "dist" / "backend"),
        "--workpath", str(ROOT / "build" / "pyinstaller"),
        "--noconfirm",
    ])
    log("[1/3] 백엔드 빌드 완료", GREEN)

def build_frontend():
    log("\n[2/3] Flutter 앱 빌드 중...", YELLOW)
    flutter = find_flutter()
    # 실행 중인 앱 종료 (exe 잠금 방지)
    if platform.system() == "Windows":
        subprocess.run(["taskkill", "/IM", "sd_local_app.exe", "/F"],
                       capture_output=True)
    run([flutter, "build", "windows", "--release"], cwd=ROOT / "frontend")
    log("[2/3] Flutter 빌드 완료", GREEN)

def package():
    log("\n[3/3] 배포 패키지 조립 중...", YELLOW)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Flutter 빌드 결과 복사
    flutter_release = ROOT / "frontend" / "build" / "windows" / "x64" / "runner" / "Release"
    if not flutter_release.exists():
        log("Flutter 빌드 결과물이 없습니다. --skip-frontend 없이 다시 실행하세요.", RED)
        sys.exit(1)
    shutil.copytree(flutter_release, OUT_DIR, dirs_exist_ok=True)

    # 백엔드 복사
    backend_dist = ROOT / "dist" / "backend" / "sd_backend"
    if backend_dist.exists():
        shutil.copytree(backend_dist, OUT_DIR / "sd_backend", dirs_exist_ok=True)
        # safety.json 복사
        safety_src = ROOT / "backend" / "safety.json"
        safety_dst = OUT_DIR / "sd_backend" / "backend" / "safety.json"
        if safety_src.exists():
            safety_dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(safety_src, safety_dst)

    # EULA.txt, THIRD_PARTY_NOTICES.txt 복사
    for fname in ["EULA.txt", "THIRD_PARTY_NOTICES.txt"]:
        src = ROOT / fname
        if src.exists():
            shutil.copy2(src, OUT_DIR / fname)

    # 필요 폴더 생성
    for d in ["models/base", "models/lora", "models/cache", "output", "logs"]:
        (OUT_DIR / d).mkdir(parents=True, exist_ok=True)

    # config.json 템플릿
    config = {
        "server":     {"port": 8000, "auto_port_search": True},
        "model":      {"base_model_path": "models/base/", "lora_path": "models/lora/", "vae_path": ""},
        "generation": {"width": 512, "height": 512, "steps": 20, "cfg_scale": 7.0,
                       "sampler": "DPM++ 2M Karras", "seed": -1, "batch_size": 1,
                       "clip_skip": 1, "precision": "fp16",
                       "vram_optimization": False, "cpu_offload": False},
        "output":     {"output_path": "output/"},
        "log":        {"retention_days": 60, "max_file_size_mb": 10},
    }
    (OUT_DIR / "config.json").write_text(
        json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT_DIR / "presets.json").write_text('{"presets":[]}', encoding="utf-8")

    log("[3/3] 패키징 완료", GREEN)
    log(f"\n=== 빌드 완료 ===", CYAN)
    log(f"배포 폴더: {OUT_DIR}")
    log("\n배포 시 포함 필요:", YELLOW)
    log(f"  {OUT_DIR / 'models' / 'base'}  ← .safetensors 모델 파일", GRAY)
    log("  (models, output, logs 폴더는 자동 생성됨)", GRAY)


def main():
    parser = argparse.ArgumentParser(description="ImageGenerator 빌드 스크립트")
    parser.add_argument("--skip-backend",  action="store_true", help="백엔드 빌드 생략")
    parser.add_argument("--skip-frontend", action="store_true", help="Flutter 빌드 생략")
    parser.add_argument("--skip-package",  action="store_true", help="패키징 생략")
    parser.add_argument("--flutter-only",  action="store_true", help="Flutter 빌드만 실행")
    args = parser.parse_args()

    if args.flutter_only:
        ensure_venv()
        build_frontend()
        return

    log(f"=== {APP_NAME} 빌드 시작 ===", CYAN)

    if not args.skip_backend:
        ensure_venv()
        build_backend()
    if not args.skip_frontend:
        build_frontend()
    if not args.skip_package:
        package()


if __name__ == "__main__":
    main()
