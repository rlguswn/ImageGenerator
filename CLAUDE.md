# ImageGenerator — Claude Code 가이드

## 프로젝트 개요
Stable Diffusion 기반 Windows 로컬 이미지 생성 앱.
- **백엔드**: FastAPI + diffusers (Python) — `http://127.0.0.1:8000`
- **프론트엔드**: Flutter Windows 앱

---

## MCP 서버 사용법

이 프로젝트의 MCP 서버(`imagegenerator`)가 등록되어 있습니다.
자연어로 이미지 생성을 직접 제어할 수 있습니다.

### 사전 조건
ImageGenerator 앱이 실행 중이고 모델 로딩이 완료된 상태여야 합니다.
앱이 꺼져있으면 `get_health` 호출 시 연결 오류가 납니다.

### 워크플로우

**1. 상태 확인**
```
get_health → 모델 로딩 여부, VRAM 상태 확인
```

**2. 이미지 생성**
```
txt2img(
  prompt="masterpiece, best quality, ...",
  negative_prompt="lowres, bad anatomy, ...",
  width=512, height=512,
  steps=20, cfg_scale=7.0,
  seed=-1  # -1이면 랜덤
)
```

**3. 진행 확인 / 취소**
```
get_progress → step/total/elapsed/eta 반환
cancel_generation → 생성 중단
```

### 프롬프트 작성 규칙
- **영어 태그** 쉼표 구분: `masterpiece, best quality, 1girl, smile`
- **품질 태그** 앞에: `masterpiece, best quality, ultra-detailed`
- **네거티브** 기본값: `lowres, bad anatomy, bad hands, text, error, worst quality, low quality`
- 해상도는 64의 배수: 512, 768, 1024

### 사용 가능한 도구 목록

| 도구 | 필수 파라미터 | 설명 |
|---|---|---|
| `get_health` | 없음 | 서버 상태 확인 |
| `list_models` | 없음 | 사용 가능한 모델 목록 |
| `list_loras` | 없음 | 사용 가능한 LoRA 목록 |
| `load_model` | `model_path` | 모델 로딩 (앱 실행 중 모델 교체) |
| `txt2img` | `prompt` | 텍스트 → 이미지 생성 |
| `get_progress` | 없음 | 생성 진행률 |
| `cancel_generation` | 없음 | 생성 취소 |
| `get_gallery` | 없음 | 최근 생성 이미지 목록 |
| `get_presets` | 없음 | 저장된 프리셋 목록 |
| `get_logs` | 없음 | 최근 로그 조회 (lines, level 옵션) |
| `get_config` | 없음 | 현재 config.json 전체 조회 |
| `set_config` | `key`, `value` | 설정 값 변경 (예: `generation.steps` = 30) |

### 예시 명령

> "고양이가 우주복 입은 이미지 만들어줘"
→ txt2img(prompt="masterpiece, best quality, cat wearing spacesuit, space background, highly detailed")

> "512x768 세로 비율로 일본 풍경 생성해줘"
→ txt2img(prompt="...", width=512, height=768)

> "지금 생성 얼마나 됐어?"
→ get_progress()

> "어떤 모델 있어?"
→ list_models()

> "최근 오류 로그 보여줘"
→ get_logs(lines=50, level="error")

> "현재 steps 설정이 몇이야?"
→ get_config()  # 전체 config 조회 후 generation.steps 확인

> "steps를 30으로 바꿔줘"
→ set_config(key="generation.steps", value=30)

### 프롬프트 필터 주의
`backend/safety.json`의 `prompt_filter`가 활성화되어 있습니다.
금지 키워드(미성년자 관련 등)가 포함된 프롬프트는 HTTP 400 오류를 반환합니다.
오류 발생 시 프롬프트를 수정하고 재시도하세요.

---

## 개발 환경

| 항목 | 값 |
|---|---|
| OS | Windows 10 Pro |
| Python | 3.10.6 (venv: `venv/`) |
| GPU | NVIDIA RTX 2070 (VRAM 8GB) |
| Flutter | 3.41.9 (`D:\flutter\flutter`) |

### 서버 수동 실행
```powershell
cd D:\project\ImageGenerator
venv\Scripts\python.exe backend\main.py
```

### 앱 실행
```powershell
cd D:\project\ImageGenerator\frontend
D:\flutter\flutter\bin\flutter.bat run -d windows
```

---

## 주요 파일

| 파일 | 역할 |
|---|---|
| `backend/main.py` | FastAPI 엔드포인트 전체 |
| `backend/sd_engine.py` | diffusers 래퍼 (txt2img/img2img/inpaint) |
| `backend/mcp_server.py` | MCP stdio 서버 |
| `backend/logger.py` | 날짜별 로그 파일 관리 |
| `backend/safety.json` | 프롬프트 필터 / safety checker / AI 메타데이터 설정 |
| `frontend/lib/main.dart` | Flutter 앱 진입점 (EULA 동의 분기 포함) |
| `frontend/lib/screens/eula_screen.dart` | 최초 실행 EULA 동의 화면 |
| `frontend/lib/services/generation_service.dart` | 전역 생성 상태 관리 |
| `frontend/lib/services/session_storage.dart` | 로컬 설정/세션 저장 |
| `config.json` | 서버/모델/생성 설정 (gitignore) |
| `EULA.txt` | 최종 사용자 라이선스 계약 |
| `build.py` | 전체 빌드 자동화 (Python) |
| `WORKGUIDE.md` | 개발 규칙 및 가이드 |
| `PROGRESS.md` | 변경 이력 |
