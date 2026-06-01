@echo off
title ImageGenerator - Dev Mode

:: Kill existing backend
taskkill /F /IM sd_backend.exe > nul 2>&1
wmic process where "commandline like '%%backend\\main.py%%'" delete > nul 2>&1
timeout /t 1 /nobreak > nul

:: Find Flutter
set FLUTTER=
if exist "D:\flutter\flutter\bin\flutter.bat" set FLUTTER=D:\flutter\flutter\bin\flutter.bat
if exist "C:\flutter\bin\flutter.bat"         set FLUTTER=C:\flutter\bin\flutter.bat
if "%FLUTTER%"=="" (
    where flutter.bat > nul 2>&1 && set FLUTTER=flutter.bat
)
if "%FLUTTER%"=="" (
    echo.
    echo [ERROR] Flutter not found. Check PATH or install location.
    pause
    exit /b 1
)

echo Flutter: %FLUTTER%
echo.
echo Starting Flutter app... (backend will be launched automatically)
echo.

cd /d "%~dp0frontend"
"%FLUTTER%" run -d windows

if errorlevel 1 (
    echo.
    echo [ERROR] Flutter failed to start
    pause
)
