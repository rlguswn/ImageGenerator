@echo off
chcp 65001 > nul
title ImageGenerator - 개발 모드

:: 기존 백엔드 프로세스 종료
taskkill /F /IM sd_backend.exe > nul 2>&1
wmic process where "commandline like '%%backend\\main.py%%'" delete > nul 2>&1
timeout /t 1 /nobreak > nul

:: Flutter 경로 탐색
set FLUTTER=
if exist "D:\flutter\flutter\bin\flutter.bat" set FLUTTER=D:\flutter\flutter\bin\flutter.bat
if exist "C:\flutter\bin\flutter.bat"         set FLUTTER=C:\flutter\bin\flutter.bat
if "%FLUTTER%"=="" (
    where flutter.bat > nul 2>&1 && set FLUTTER=flutter.bat
)
if "%FLUTTER%"=="" (
    echo.
    echo [오류] Flutter를 찾을 수 없습니다. PATH 또는 경로를 확인하세요.
    pause
    exit /b 1
)

echo Flutter: %FLUTTER%
echo.
echo Flutter 앱 실행 중... (백엔드는 앱이 자동으로 시작합니다)
echo.

cd /d "%~dp0frontend"
"%FLUTTER%" run -d windows

if errorlevel 1 (
    echo.
    echo [오류] Flutter 실행 실패
    pause
)
