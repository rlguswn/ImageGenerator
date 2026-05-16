@echo off
:: 개발 모드 실행 (빌드 없이 flutter run으로 직접 실행)
:: 백엔드는 Flutter 앱 내 splash_screen이 자동으로 시작함

:: venv가 없으면 먼저 생성
if not exist "%~dp0venv\Scripts\python.exe" (
    echo [1/2] 가상환경 생성 중...
    python -m venv "%~dp0venv"
    "%~dp0venv\Scripts\pip.exe" install -r "%~dp0requirements.txt" --quiet
    echo [1/2] 가상환경 준비 완료
)

:: Flutter 실행 경로 자동 탐색
set FLUTTER=
if exist "D:\flutter\flutter\bin\flutter.bat" set FLUTTER=D:\flutter\flutter\bin\flutter.bat
if exist "C:\flutter\bin\flutter.bat"         set FLUTTER=C:\flutter\bin\flutter.bat
if "%FLUTTER%"=="" (
    where flutter.bat >nul 2>&1 && set FLUTTER=flutter.bat
)
if "%FLUTTER%"=="" (
    echo [오류] Flutter를 찾을 수 없습니다. PATH 또는 경로를 확인하세요.
    pause
    exit /b 1
)

echo [2/2] Flutter 앱 실행 중...
cd /d "%~dp0frontend"
"%FLUTTER%" run -d windows
