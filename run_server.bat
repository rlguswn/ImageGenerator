@echo off
chcp 65001 > nul
title ImageGenerator - 백엔드 서버

:: 기존 백엔드 종료
taskkill /F /IM sd_backend.exe > nul 2>&1
wmic process where "commandline like '%%backend\\main.py%%'" delete > nul 2>&1
timeout /t 1 /nobreak > nul

:: venv 확인
if not exist "%~dp0venv\Scripts\python.exe" (
    echo.
    echo [1/2] 가상환경 생성 중...
    python -m venv "%~dp0venv"
    "%~dp0venv\Scripts\python.exe" -m pip install -r "%~dp0requirements.txt" --quiet
    echo [1/2] 가상환경 준비 완료
    echo.
)

echo 백엔드 서버 시작 중... (http://127.0.0.1:8000)
echo 종료하려면 Ctrl+C 를 누르세요.
echo.

cd /d "%~dp0"
venv\Scripts\python.exe backend\main.py

if errorlevel 1 (
    echo.
    echo [오류] 백엔드 실행 실패
    pause
)
