@echo off
title ImageGenerator - Backend Server

:: Kill existing backend
taskkill /F /IM sd_backend.exe > nul 2>&1
wmic process where "commandline like '%%backend\\main.py%%'" delete > nul 2>&1
timeout /t 1 /nobreak > nul

:: Check venv
if not exist "%~dp0venv\Scripts\python.exe" (
    echo.
    echo [1/3] Creating venv...
    python -m venv "%~dp0venv"
    echo [2/3] Installing PyTorch (CUDA 12.4)...
    "%~dp0venv\Scripts\python.exe" -m pip install torch==2.6.0+cu124 torchvision==0.21.0+cu124 --index-url https://download.pytorch.org/whl/cu124 --quiet
    echo [3/3] Installing dependencies...
    "%~dp0venv\Scripts\python.exe" -m pip install -r "%~dp0requirements.txt" --quiet
    echo Venv ready
    echo.
)

echo Starting backend server... (http://127.0.0.1:8000)
echo Press Ctrl+C to stop.
echo.

cd /d "%~dp0"
venv\Scripts\python.exe backend\main.py

if errorlevel 1 (
    echo.
    echo [ERROR] Backend failed to start
    pause
)
