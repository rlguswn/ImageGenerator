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

echo [2/2] Flutter 앱 실행 중...
cd /d "%~dp0frontend"
D:\flutter\flutter\bin\flutter.bat run -d windows
