@echo off
set EXE=%~dp0frontend\build\windows\x64\runner\Release\sd_local_app.exe
if not exist "%EXE%" (
    echo.
    echo [오류] 빌드된 앱이 없습니다.
    echo 먼저 아래 명령어로 빌드를 실행하세요:
    echo.
    echo   python build.py --flutter-only
    echo.
    pause
    exit /b 1
)
start "" "%EXE%"
