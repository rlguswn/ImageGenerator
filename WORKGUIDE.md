# 작업 가이드

## 환경 정보

| 항목 | 값 |
|---|---|
| OS | Windows 10 Pro |
| Python | 3.10.6 |
| GPU | NVIDIA RTX 2070 (VRAM 8GB) |
| CUDA | 12.6 |
| PyTorch | 2.6.0+cu124 |
| 가상환경 | `venv/` (Python 3.10) |

---

## 프로젝트 실행 방법

### 백엔드 서버 실행
```powershell
cd D:\project\ImageGenerator
venv\Scripts\activate
cd backend
python main.py
```
서버 주소: `http://127.0.0.1:8000`
API 문서: `http://127.0.0.1:8000/docs`

### Flutter 앱 실행
```powershell
cd D:\project\ImageGenerator\frontend
D:\flutter\flutter\bin\flutter.bat run -d windows
```

### Flutter 릴리스 빌드
```powershell
cd D:\project\ImageGenerator\frontend
D:\flutter\flutter\bin\flutter.bat build windows --release
# 결과: frontend\build\windows\x64\runner\Release\sd_local_app.exe
```

### 전체 빌드 (백엔드 + 프론트엔드)
```powershell
cd D:\project\ImageGenerator
python build.py                   # 전체 빌드
python build.py --flutter-only    # Flutter만 (가장 자주 사용)
python build.py --skip-backend    # Flutter + 패키징만
python build.py --skip-frontend   # 백엔드 + 패키징만
python build.py --skip-package    # 빌드만, 패키징 생략
```
> `build.py`는 venv Python 없이 시스템 Python으로 실행 가능.
> Flutter 경로는 `D:\flutter\flutter\bin\flutter.bat` 또는 PATH의 `flutter`를 자동 탐색.

---

## 디렉토리 구조

```
ImageGenerator/
├── backend/
│   ├── main.py               # FastAPI 진입점 + 모든 엔드포인트
│   ├── sd_engine.py          # diffusers 래퍼 (SDEngine 클래스)
│   ├── lora_train.py         # LoRA 학습 (LoRATrainer 클래스)
│   ├── port_check.py         # 포트 탐색 + 점유 프로세스 조회 (psutil)
│   ├── mcp_server.py         # MCP stdio 서버 (Claude/Gemini 연동)
│   ├── logger.py             # SDLogger (날짜별 로그 + error.log)
│   └── safety.json           # 프롬프트 필터 / safety checker / AI 메타데이터 설정
├── frontend/
│   └── lib/
│       ├── main.dart
│       ├── screens/
│       │   ├── eula_screen.dart        # 최초 실행 시 EULA 동의 화면
│       │   ├── startup_screen.dart
│       │   ├── splash_screen.dart
│       │   ├── home_screen.dart
│       │   ├── txt2img_screen.dart
│       │   ├── img2img_screen.dart
│       │   ├── inpaint_screen.dart     # 마스크 드로잉 캔버스 (브러시/지우개/되돌리기)
│       │   ├── lora_screen.dart
│       │   ├── gallery_screen.dart
│       │   ├── settings_screen.dart
│       │   └── debug_screen.dart       # 개발자 모드 전용
│       ├── widgets/
│       │   └── compare_slider.dart     # 좌우 드래그 비교 슬라이더
│       └── services/
│           ├── api_service.dart
│           ├── process_manager.dart
│           ├── app_paths.dart          # 프로젝트 루트 경로 유틸
│           ├── dev_mode.dart           # devModeNotifier
│           ├── home_nav.dart           # homeTabNotifier
│           ├── regen_request.dart      # regenNotifier
│           ├── generation_service.dart # genService 싱글턴 + GenState/GenStatus
│           └── session_storage.dart    # preferences.json / last_session.json 로컬 저장
├── models/
│   ├── base/                 # 베이스 모델 (.safetensors) — gitignore
│   ├── lora/                 # 학습된 LoRA — gitignore
│   └── cache/                # diffusers 포맷 캐시 — gitignore
├── output/                   # 생성 이미지 + 메타데이터 JSON — gitignore
├── logs/                     # 로그 파일 — gitignore
├── venv/                     # Python 가상환경 — gitignore
├── config.json               # 서버/모델/생성 설정 — gitignore
├── presets.json              # 프리셋 목록 — gitignore
├── eula.json                 # EULA 동의 상태 — gitignore
├── requirements.txt
├── backend.spec              # PyInstaller 스펙
├── build.py                  # 빌드 자동화 스크립트 (Python)
├── run.bat                   # 앱 실행 단축키
├── run_server.bat            # 백엔드만 실행
├── EULA.txt                  # 최종 사용자 라이선스 계약
├── THIRD_PARTY_NOTICES.txt   # 오픈소스 라이브러리 저작권 고지
├── CLAUDE.md                 # Claude Code 가이드
├── GEMINI.md                 # Gemini CLI 가이드
├── .gitignore
├── PROGRESS.md               # 개발 진행 현황 (변경 이력)
├── WORKGUIDE.md              # 이 파일
└── PLAN.md                   # 전체 기획서
```

---

## 패키지 설치

### 최초 설치
```powershell
python -m venv venv
venv\Scripts\activate
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124
pip install -r requirements.txt
```

> PyTorch는 별도 인덱스에서 받아야 하므로 requirements.txt에서 분리.

### 패키지 추가 시
```powershell
venv\Scripts\activate
pip install <패키지>
# requirements.txt 수동 업데이트
```

---

## 개발 규칙

### 코드 스타일 (Python)
- 타입 힌트 사용 (`Optional`, `list`, `dict` 등)
- 클래스 단위로 엔진 분리 (`SDEngine`, `LoRATrainer`)
- 전역 싱글턴 인스턴스: `engine`, `trainer`
- 주석은 WHY가 명확할 때만 작성

### API 규칙
- 요청/응답 모두 Pydantic 모델로 정의
- 에러는 HTTPException으로 통일
- 이미지 전송: base64 인코딩 사용

### 파일 저장 규칙
- 생성 이미지: `output/YYYYMMDD_HHMMSS.png`
- 메타데이터: 이미지와 동일한 이름 `.json`
- 로그: `logs/YYYY-MM-DD.log`, 오류는 `logs/error.log`

### Flutter 규칙
- 화면: `screens/` 디렉토리
- 서비스: `services/` 디렉토리
- API 통신: `api_service.dart`에서 중앙 관리
- Python 프로세스: `process_manager.dart`에서 관리
- 탭 전환 상태 보존: 각 State 클래스에 `static Map<String, dynamic>? _savedState` 패턴
- 전역 상태: `ValueNotifier` 사용 (`devModeNotifier`, `homeTabNotifier`, `regenNotifier`)
- 경로 유틸: `app_paths.dart`의 `findProjectRoot()` / `outputDirPath` 공유
- async 안전: await 전에 `ScaffoldMessenger.of(context)` 캡처, await 후 `if (!mounted) return`
- regenNotifier 수신: `initState`에서 `addPostFrameCallback`으로 기존 값 직접 확인 후 addListener 등록 (ValueNotifier는 이미 세팅된 값을 재알림하지 않음)
- 마스크 캔버스: `CustomPainter` + `canvas.saveLayer` 필수 (`BlendMode.clear` 지우개 동작 조건), 스트로크 좌표는 이미지 표시 Rect 기준 로컬 좌표로 저장
- 마스크 내보내기: `ui.PictureRecorder` → `picture.toImage()` → `toByteData(ImageByteFormat.png)` 로 실제 이미지 해상도에 맞게 렌더링
- 마스크 반전: `_maskInverted` 플래그 — 내보내기 시 배경/브러시 색상 반전, `_MaskPainter`는 반전 시 전체 빨간 오버레이 + 브러시 = BlendMode.clear
- 파일 선택: `file_picker` 패키지 — `FilePicker.platform.pickFiles(type: FileType.image)` / `getDirectoryPath()` 사용. 항상 await 후 `if (!mounted) return` 체크
- 토스트 알림: `local_notifier` 패키지 — `LocalNotification(title:, body:).show()` 비동기, await 불필요
- 비교 슬라이더: `widgets/compare_slider.dart`의 `CompareSlider(before:, after:)` — 드래그로 좌우 비율 조정, `_SplitClipper`로 before 이미지 클리핑
- 갤러리→인페인트: `regenNotifier.value = RegenPayload('inpaint', {'imagePath': ...})` 후 `homeTabNotifier.value = 2`; inpaint_screen의 addPostFrameCallback이 픽업
- config 직렬화: `const JsonEncoder.withIndent('  ').convert(map)`으로 Pretty Print JSON 내보내기
- 전역 생성 서비스: `genService.run(mode, apiCall)` — 내부에서 elapsed/progress 타이머, 토스트, GenState 발행; 화면 전환 중에도 생성 유지
- 생성 결과 픽업: 각 화면 `initState`에서 `genService.notifier.addListener(_onServiceChanged)` + `addPostFrameCallback`으로 마운트 시점의 done 상태도 처리
- 생성 버튼: `ValueListenableBuilder<GenState>(valueListenable: genService.notifier, ...)` — `s.isActive`일 때 비활성화, 타이머 tick이 화면 전체를 rebuild하지 않음
- 사이드바: `home_screen.dart`의 `_GenSidebar` (200px) — `genService.notifier`를 직접 구독, 4가지 상태(idle/generating/done/error) 렌더링
- EULA 패턴: `main.dart`의 `_isEulaAccepted()`가 `eula.json` 존재 여부 확인 → `home:` 라우트를 `EulaScreen` 또는 `StartupScreen`으로 분기; `EulaScreen`은 스크롤 끝 도달 + 체크박스 체크 후 동의 버튼 활성화, 동의 시 `eula.json` 기록
- Batch 입력: `_intInputRow()` 위젯 패턴 — `TextEditingController` + `Slider` 동기화, 슬라이더 범위(1~16)와 텍스트 입력(무제한) 공존; dispose에서 controller 해제 필수
- 배포/개발 분기: `splash_screen.dart`에서 exe 옆 `sd_backend/sd_backend.exe` 존재 여부로 release/dev 자동 감지 → `processManager.start()` vs `processManager.startDev()`

---

## SD 모델 파일 추가 방법

1. CivitAI (https://civitai.com) 또는 Hugging Face에서 `.safetensors` 다운로드
2. `models/base/` 폴더에 복사
3. `config.json`의 `model.base_model_path` 확인 (기본값 `models/base/`)
4. 서버 실행 후 `/models/base` API로 목록 확인

### 추천 베이스 모델
- **SD 1.5**: `v1-5-pruned-emaonly.safetensors` — 경량, 빠름, 커뮤니티 자료 풍부
- **SDXL 1.0**: `sd_xl_base_1.0.safetensors` — 고품질, VRAM 8GB 필요

---

## MCP 서버 사용법

### 연결 방법
`~/.claude.json`의 `mcpServers`에 자동 등록되어 있음. Claude Code 재시작 시 활성화.

### 사용 순서
1. ImageGenerator 앱 실행 → 모델 로딩 완료
2. Claude Code에서 자연어로 명령

### 사용 예시
```
"고양이가 우주복 입은 이미지 만들어줘"
"512x768 사이즈로 일본 풍경 생성해줘"
"현재 생성 상태 확인해줘"
"사용 가능한 모델 목록 보여줘"
```

### 노출된 도구
| 도구 | 설명 |
|---|---|
| get_health | 서버 상태, VRAM, 모델 로딩 여부 확인 |
| list_models | models/base/ 모델 목록 |
| list_loras | models/lora/ LoRA 목록 |
| load_model | 모델 로딩 |
| txt2img | 텍스트 → 이미지 생성 |
| get_progress | 생성 진행률 확인 |
| cancel_generation | 생성 취소 |
| get_gallery | 최근 생성 이미지 목록 |
| get_presets | 프리셋 목록 |
| get_logs | 최근 로그 조회 (lines, level 파라미터) |
| get_config | config.json 전체 조회 |
| set_config | 점 구분 키로 설정 변경 (예: generation.steps=30) |

---

## diffusers 캐시

첫 모델 로딩 시 `models/cache/{모델명}_{precision}/`에 diffusers 포맷으로 저장합니다.

| 구분 | 소요 시간 |
|---|---|
| 최초 실행 (from_single_file + 캐시 저장) | ~11s |
| 이후 실행 (from_pretrained, 캐시 히트) | ~2~3s |

캐시 디렉토리는 `models/`하위라 gitignore에 포함되어 있습니다.
캐시를 초기화하려면 `models/cache/` 폴더를 삭제하면 됩니다.

---

## 다음 구현 예정

### 다크모드 / 테마 커스텀 (미구현)
- `services/theme_service.dart` 신규 — `ThemeConfig` (isDark, accentValue, bgImagePath, bgOverlay), `ThemeService` 싱글턴, `BuildContext` extension (`context.surface`, `context.accent`, `context.onSurface`)
- `main.dart` — MaterialApp을 `ValueListenableBuilder<ThemeConfig>`로 감싸기, `MaterialApp.builder`에서 배경 이미지 Stack 삽입
- `settings_screen.dart` — "테마" 섹션 추가 (다크/라이트 토글, 강조색 팔레트 그리드, 배경 이미지 FilePicker, 오버레이 불투명도 Slider)
- 전체 화면 하드코딩 색상 교체 — `Color(0xFF1A1A2E)` → `context.bg`, `Color(0xFF16213E)` → `context.surface`, `Colors.blueAccent` → `context.accent`

---

## 진행 중 이슈 및 해결책

### 모델 파일 없이 개발하는 방법
- 백엔드 서버 구동 자체는 가능 (`/health` 응답 확인 가능)
- 생성 기능은 모델 로딩 후에만 활성화
- Flutter UI 개발은 모델 없이 진행 가능 (API mock 처리)

### VRAM 부족 시
`config.json` 수정:
```json
"vram_optimization": true,
"cpu_offload": true,
"precision": "fp16"
```

### 포트 충돌 시
`config.json`의 `server.auto_port_search`가 `true`면 자동으로 빈 포트 탐색.
또는 `server.port` 값을 직접 변경.

---

## 법적 보호 조치 현황

| 항목 | 구현 방법 | 파일 |
|---|---|---|
| 만 18세 이상 사용 제한 | EULA 제2조 명시 | `EULA.txt` |
| CSAM 키워드 차단 | prompt_filter 키워드 23개 | `backend/safety.json` |
| 비동의 성적 딥페이크 차단 | 키워드 필터 + EULA 제4조 | `backend/safety.json`, `EULA.txt` |
| 불법 음란물 방지 | EULA 제4조 + 키워드 필터 | `EULA.txt`, `backend/safety.json` |
| AI 생성물 표시 | PNG 메타데이터 자동 삽입 | `backend/safety.json` ai_metadata |
| LoRA 학습 저작권 경고 | 학습 시작 전 확인 다이얼로그 | `frontend/lib/screens/lora_screen.dart` |
| 모델 라이선스 고지 | 시작 화면 안내 문구 + EULA 제5조 | `startup_screen.dart`, `EULA.txt` |
| EULA 동의 게이트 | 최초 실행 시 스크롤+체크+동의 | `frontend/lib/screens/eula_screen.dart` |

> safety checker (AI 기반 이미지 검열)는 `safety.json`에서 `enabled: true`로 활성화 가능.
> 단, HuggingFace 모델 다운로드 필요 (`CompVis/stable-diffusion-safety-checker`).

---

## GitHub 업로드 기준

### 올려도 되는 것
- `backend/` 전체 소스코드 (`safety.json` 포함 — 프롬프트 필터 키워드는 법적 준수 목적)
- `frontend/` 전체 소스코드
- `requirements.txt`, `backend.spec`, `build.py`, `run.bat`, `run_server.bat`
- `EULA.txt`, `CLAUDE.md`, `GEMINI.md`
- `PLAN.md`, `PROGRESS.md`, `WORKGUIDE.md`, `.gitignore`

### 올리면 안 되는 것 (.gitignore 처리됨)
- `models/` — 모델 파일 (라이선스 별도)
- `output/` — 생성된 이미지
- `logs/` — 로그
- `venv/` — 가상환경
- `config.json` — 실제 경로·포트 포함 가능성
- `presets.json` — 사용자 데이터
- `eula.json` — 동의 상태 (사용자별)
- `preferences.json`, `last_session.json` — 사용자 설정

---

## 라이선스 요약

| 라이브러리 | 라이선스 | 상업적 사용 |
|---|---|---|
| PyTorch | BSD 3-Clause | ✅ |
| diffusers | Apache 2.0 | ✅ |
| FastAPI | MIT | ✅ |
| Flutter | BSD 3-Clause | ✅ |
| PyInstaller | GPL + 예외조항 | ✅ (앱 코드 비감염) |
| SD 1.5 모델 | CreativeML OpenRAIL-M | ✅ |
| SD 3.x 모델 | Stability AI Community | ✅ (연매출 $1M 미만) |
