#!/bin/bash
cd "$(dirname "$0")"

echo "ImageGenerator - Dev Mode (macOS)"
echo

# 기존 백엔드 프로세스 종료
pkill -f "sd_backend" > /dev/null 2>&1
pkill -f "backend/main.py" > /dev/null 2>&1
sleep 1

# Flutter 찾기
FLUTTER=""
if command -v flutter > /dev/null 2>&1; then
    FLUTTER="flutter"
elif [ -x "/opt/homebrew/bin/flutter" ]; then
    FLUTTER="/opt/homebrew/bin/flutter"
elif [ -x "$HOME/flutter/bin/flutter" ]; then
    FLUTTER="$HOME/flutter/bin/flutter"
fi

if [ -z "$FLUTTER" ]; then
    echo "[ERROR] Flutter를 찾을 수 없습니다. PATH 또는 설치 경로를 확인하세요."
    read -p "엔터를 누르면 창이 닫힙니다..."
    exit 1
fi

echo "Flutter: $FLUTTER"
echo
echo "Flutter 앱 시작 중... (백엔드는 앱이 자동으로 실행합니다)"
echo

cd frontend
"$FLUTTER" run -d macos

echo
read -p "종료하려면 엔터를 누르세요..."
