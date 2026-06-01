@echo off
title ImageGenerator

:: Run release build (dist\ImageGenerator\sd_local_app.exe)
set EXE=%~dp0dist\ImageGenerator\sd_local_app.exe

if not exist "%EXE%" (
    echo.
    echo [ERROR] Release build not found.
    echo Run build first:
    echo.
    echo   python build.py
    echo.
    pause
    exit /b 1
)

echo Starting app...
start "" "%EXE%"
