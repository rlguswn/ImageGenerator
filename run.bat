@echo off
chcp 65001 > nul
title ImageGenerator

:: 배포 버전 실행 (dist\ImageGenerator\sd_local_app.exe)
set EXE=%~dp0dist\ImageGenerator\sd_local_app.exe

if not exist "%EXE%" (
    echo.
    echo [오류] 배포 버전이 없습니다.
    echo 먼저 빌드를 실행하세요:
    echo.
    echo   python build.py
    echo.
    pause
    exit /b 1
)

echo 앱 실행 중...
start "" "%EXE%"
