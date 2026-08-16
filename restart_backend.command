#!/bin/bash
cd "$(dirname "$0")"

echo "백엔드만 재시작 (Flutter 앱은 그대로 둡니다)"
echo

pkill -f "sd_backend" > /dev/null 2>&1
pkill -f "backend/main.py" > /dev/null 2>&1
sleep 1

venv/bin/python3 backend/main.py

echo
read -p "종료하려면 엔터를 누르세요..."
