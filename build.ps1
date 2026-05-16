# ImageGenerator 전체 빌드 스크립트
# 실행: .\build.ps1
# 옵션: .\build.ps1 -SkipBackend  / -SkipFrontend / -SkipPackage

param(
    [switch]$SkipBackend,
    [switch]$SkipFrontend,
    [switch]$SkipPackage
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$AppName = "ImageGenerator"
$OutDir  = "$Root\dist\$AppName"

Write-Host "=== $AppName 빌드 시작 ===" -ForegroundColor Cyan

# ── 1. Python 백엔드 (PyInstaller) ──────────────────────────────────
if (-not $SkipBackend) {
    Write-Host "`n[1/3] Python 백엔드 빌드 중..." -ForegroundColor Yellow

    & "$Root\venv\Scripts\pip" install pyinstaller --quiet
    if ($LASTEXITCODE -ne 0) { throw "pip install pyinstaller 실패" }

    & "$Root\venv\Scripts\pyinstaller" "$Root\backend.spec" `
        --distpath "$Root\dist\backend" `
        --workpath "$Root\build\pyinstaller" `
        --noconfirm
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller 빌드 실패" }

    Write-Host "[1/3] 백엔드 빌드 완료" -ForegroundColor Green
}

# ── 2. Flutter Windows 앱 ────────────────────────────────────────────
if (-not $SkipFrontend) {
    Write-Host "`n[2/3] Flutter 앱 빌드 중..." -ForegroundColor Yellow

    $flutterBin = "D:\flutter\flutter\bin\flutter.bat"
    if (-not (Test-Path $flutterBin)) { $flutterBin = "flutter" }

    Push-Location "$Root\frontend"
    & $flutterBin build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Flutter 빌드 실패" }
    Pop-Location

    Write-Host "[2/3] Flutter 빌드 완료" -ForegroundColor Green
}

# ── 3. 패키징 ────────────────────────────────────────────────────────
if (-not $SkipPackage) {
    Write-Host "`n[3/3] 배포 패키지 조립 중..." -ForegroundColor Yellow

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    # Flutter 실행파일 복사
    $flutterRelease = "$Root\frontend\build\windows\x64\runner\Release"
    Copy-Item "$flutterRelease\*" $OutDir -Recurse -Force

    # Python 백엔드 복사 (sd_backend/ 폴더째)
    $backendDist = "$Root\dist\backend\sd_backend"
    if (Test-Path $backendDist) {
        Copy-Item $backendDist "$OutDir\sd_backend" -Recurse -Force
    }

    # safety.json 복사 (백엔드 exe 옆에 위치)
    Copy-Item "$Root\backend\safety.json" "$OutDir\sd_backend\backend\safety.json" -Force -ErrorAction SilentlyContinue

    # EULA.txt 복사
    Copy-Item "$Root\EULA.txt" "$OutDir\EULA.txt" -Force

    # 필요 폴더 생성
    foreach ($dir in @("models\base", "models\lora", "models\cache", "output", "logs")) {
        New-Item -ItemType Directory -Force -Path "$OutDir\$dir" | Out-Null
    }

    # config.json 템플릿
    $cfg = [ordered]@{
        server     = [ordered]@{ port = 8000; auto_port_search = $true }
        model      = [ordered]@{ base_model_path = "models/base/"; lora_path = "models/lora/"; vae_path = "" }
        generation = [ordered]@{ width = 512; height = 512; steps = 20; cfg_scale = 7.0; sampler = "DPM++ 2M Karras"; seed = -1; batch_size = 1; clip_skip = 1; precision = "fp16"; vram_optimization = $false; cpu_offload = $false }
        output     = [ordered]@{ output_path = "output/" }
        log        = [ordered]@{ retention_days = 60; max_file_size_mb = 10 }
    }
    $cfg | ConvertTo-Json -Depth 5 | Out-File "$OutDir\config.json" -Encoding utf8NoBOM
    '{"presets":[]}' | Out-File "$OutDir\presets.json" -Encoding utf8NoBOM

    Write-Host "[3/3] 패키징 완료" -ForegroundColor Green
    Write-Host "`n=== 빌드 완료 ===" -ForegroundColor Cyan
    Write-Host "배포 폴더: $OutDir" -ForegroundColor White
    Write-Host ""
    Write-Host "배포 시 포함 필요:" -ForegroundColor Yellow
    Write-Host "  models\base\  ← .safetensors 모델 파일" -ForegroundColor Gray
    Write-Host "  (models, output, logs 폴더는 자동 생성됨)" -ForegroundColor Gray
}
