# 개발 진행 현황

## 변경 이력 (날짜별)

| 날짜 | 내용 |
|---|---|
| 2026-05-13 | Phase 1: Python 백엔드 전체 구현 (FastAPI, sd_engine, lora_train, port_check, logger) |
| 2026-05-13 | Phase 2~6: Flutter 앱 전체 UI 구현 (startup, splash, home, txt2img, img2img, gallery, lora, settings) |
| 2026-05-13 | Flutter SDK 3.41.9 설치, 빌드 성공 (Developer Mode 없이 window_manager 제거 후 빌드) |
| 2026-05-13 | Phase 7: 로그 시스템 (logger.py, main.py 연동) |
| 2026-05-13 | Phase 8: PyInstaller 스펙(backend.spec), 빌드 자동화(build.ps1) |
| 2026-05-13 | 코드 리뷰: 버그 12건 발견 (Critical 3, High 3, Medium 3, Minor 3) |
| 2026-05-13 | 버그 수정: process_manager 경로, lora_train 스케줄러/GradScaler/저장, clip_skip, 파일명 충돌, 포트 초기체크 외 |
| 2026-05-13 | startup_screen.dart _checkPort() mounted 가드 추가, main.dart 미사용 import 제거 |
| 2026-05-13 | api_service.dart 장시간 HTTP 요청 timeout 추가 (loadModel 5분, txt2img/img2img 10분) |
| 2026-05-13 | 2차 전체 코드 리뷰 — 추가 버그 9건 발견 및 수정 |
| 2026-05-13 | gallery_screen: 중첩 setState 크래시 수정, output 경로 절대경로 처리 (app_paths.dart 생성) |
| 2026-05-13 | home_screen: IndexedStack으로 탭 전환 시 상태 보존 |
| 2026-05-13 | txt2img/img2img: ScaffoldMessenger 사전 캡처, mounted 가드, seed int.tryParse |
| 2026-05-13 | lora_screen: 폴링 콜백 async 후 mounted 체크 추가 |
| 2026-05-13 | settings_screen: _loadConfig/_save mounted 가드 + ScaffoldMessenger 사전 캡처 |
| 2026-05-13 | logger.py: get_logger 두 번째 호출 시 파라미터 반영 안 되던 버그 수정 |
| 2026-05-13 | img2img_screen: 미사용 import 'package:flutter/services.dart' 제거 |
| 2026-05-13 | process_manager: _findProjectRoot() → 공유 함수 findProjectRoot()로 교체 |
| 2026-05-13 | 3차 리뷰 — gallery_screen: _deleteItem/_deleteSelected 중첩 setState + try/catch, 미사용 import 제거 |
| 2026-05-13 | startup_screen: models/base 절대경로 + mounted 가드, _launch() 모델 경로 절대경로 |
| 2026-05-13 | lora_screen: _startTraining() ScaffoldMessenger 사전 캡처 + mounted 가드 |
| 2026-05-13 | lora_train.py: torch.cuda.amp → torch.amp (GradScaler/autocast 최신 API로 교체) |
| 2026-05-13 | 4차 리뷰 — main.py: OUTPUT_DIR 하드코딩 제거, save_image_with_metadata가 config에서 경로 읽도록 |
| 2026-05-13 | sd_engine: apply_loras/txt2img/img2img에 lora_dir 파라미터 추가, main.py에서 config 경로 전달 |
| 2026-05-13 | gallery_screen: 새로고침 버튼 추가 (IndexedStack 도입으로 initState 1회만 실행되기 때문) |
| 2026-05-13 | splash_screen: catch/onLog/waitUntilReady 콜백 mounted 가드 추가, _deleteItem/_deleteSelected await 후 mounted 체크 |
| 2026-05-13 | 5차/6차 리뷰 — txt2img: _savePreset 에러처리 + mounted 가드 추가 |
| 2026-05-13 | splash_screen: 죽은코드 제거 (modelPath != 'models/base/' 불필요해짐) |
| 2026-05-13 | home_screen: IndexedStack 제거 → 직접 인덱싱 (각 탭 위젯이 tab 전환 시 재생성) |
| 2026-05-13 | txt2img: static _savedState 도입 (dispose 저장 / initState 복원), LoRA 탭 UI 완성 (SwitchListTile + 가중치 Slider), _generate()에 selectedLoras 전달 |
| 2026-05-13 | img2img: static _savedState 도입, LoRA 탭 추가 (3탭), _cancel() mounted 가드, loras 파라미터 전달 |
| 2026-05-13 | gallery: static _savedState 도입 (filterMode, filterSort, thumbSize, searchText 복원), 이미지 목록은 항상 새로 스캔 |
| 2026-05-13 | lora_screen: static _savedState 도입, 학습 재개 복원 (isTraining==true 시 _startPolling 재개), dart:io 미사용 import 제거 |
| 2026-05-13 | 신규: home_nav.dart (homeTabNotifier), regen_request.dart (RegenPayload + regenNotifier) |
| 2026-05-13 | 신규: dev_mode.dart (devModeNotifier), 개발자 모드 토글 → 디버그 탭 동적 추가 |
| 2026-05-13 | debug_screen: 헬스체크 / 로그 뷰어 / 설정 JSON 3탭, health API 응답 파싱 오류 수정 (vram_total/vram_free 플랫 구조) |
| 2026-05-13 | 갤러리 재생성 버튼: 메타데이터 → regenNotifier 발행 + homeTabNotifier로 탭 이동 |
| 2026-05-13 | 갤러리 내보내기 버튼: 경로 입력 다이얼로그 → File.copySync |
| 2026-05-13 | txt2img/img2img: 진행률 폴링 (500ms, /generate/progress), step/total 표시, ETA |
| 2026-05-13 | txt2img/img2img: 프롬프트 히스토리 (최근 20개, 히스토리 다이얼로그, 전체 삭제) |
| 2026-05-13 | main.py: _generation_progress 전역 딕셔너리 + GET /generate/progress 엔드포인트, txt2img/img2img에 progress_callback 연결 |
| 2026-05-13 | api_service.dart: getProgress() 추가 |
| 2026-05-13 | 코드 리뷰 4건 버그 수정: regenNotifier 타이밍(txt2img/img2img initState addPostFrameCallback), img2img 취소버튼 _progressTimer 누락, debug_screen 로그 동기읽기→비동기, gallery crossAxisCount 상세패널 폭 보정 |
| 2026-05-13 | 인페인팅 기능 구현: sd_engine.py (StableDiffusionInpaintPipeline, switch_to_inpaint, inpaint 메서드), main.py (POST /inpaint, /health에 pipeline_mode 추가), api_service.dart (inpaint()) |
| 2026-05-13 | inpaint_screen.dart 신규: 마스크 캔버스(CustomPainter + saveLayer), 브러시/지우개(BlendMode.clear)/크기/되돌리기/전체지우기, 파이프라인 전환 확인 다이얼로그, 편집↔결과 토글, 탭 전환 상태 보존 |
| 2026-05-13 | home_screen.dart: 인페인트 탭(index 2) 삽입, maxIndex 5→6 |
| 2026-05-13 | 추가작업 배치: pubspec.yaml에 file_picker ^8.1.6, local_notifier ^0.1.4 추가 |
| 2026-05-13 | main.dart: WidgetsFlutterBinding.ensureInitialized() + localNotifier.setup() 초기화 |
| 2026-05-13 | widgets/compare_slider.dart 신규: 드래그 가능한 좌우 비교 슬라이더 위젯 |
| 2026-05-13 | txt2img: seed 재사용 버튼(Icons.replay) + 생성 완료 토스트 알림 |
| 2026-05-13 | img2img: _pickImage → FilePicker로 교체, 비교 슬라이더(결과/비교 토글), seed 재사용 버튼, 토스트 알림 |
| 2026-05-13 | inpaint: FilePicker, 비교 슬라이더(편집/비교/결과 3모드), 마스크 반전(inverted 플래그 + 내보내기/페인터 로직), seed 재사용 버튼, 토스트, regenNotifier 'inpaint' 연동 |
| 2026-05-13 | gallery: 'inpaint' 필터 추가, 인페인트로 열기 버튼(_openInInpaint), 프리셋으로 저장 버튼(_saveAsPreset), 내보내기 → FilePicker |
| 2026-05-13 | settings: config 내보내기/가져오기 버튼 (FilePicker + JSON 직렬화) |
| 2026-05-13 | 코드 리뷰: async gap 후 mounted 체크, 미사용 import/메서드 정리 |
| 2026-05-13 | services/generation_service.dart 신규: GenStatus enum, GenState 불변 클래스, GenerationService 싱글턴 (genService) |
| 2026-05-13 | GenerationService.run(): 경과 타이머(100ms) + 진행률 폴링(500ms) 내장, done/error 상태 전환, 토스트 알림 |
| 2026-05-13 | GenerationService.cancel(): 타이머 중지 + API cancelGeneration() 호출, reset()으로 idle 복귀 |
| 2026-05-13 | home_screen: 우측 200px 사이드바 (_GenSidebar) 추가 — 대기중/생성중/완료/오류 4가지 상태 표시 |
| 2026-05-13 | 사이드바 생성중 상태: 진행률 바, step/total, 경과 시간, ETA, 취소 버튼 |
| 2026-05-13 | 사이드바 완료 상태: 첫 번째 이미지 썸네일, seed, 생성 시간, 모드 표시 |
| 2026-05-13 | txt2img: 로컬 생성 상태(_isGenerating/타이머) 제거, genService.run() 위임, ValueListenableBuilder 생성 버튼 |
| 2026-05-13 | img2img: 동일한 genService 패턴 적용, _onServiceChanged()로 결과 픽업 |
| 2026-05-13 | inpaint: 마스크 내보내기 후 genService.run() 위임, _onServiceChanged()로 _outputImage/_pipelineMode/_viewMode 업데이트 |
| 2026-05-13 | 각 화면: initState에 genService.notifier.addListener + addPostFrameCallback으로 마운트 시점 결과 픽업 |
| 2026-05-13 | 버그수정: generation_service cancel() 경쟁 조건 — cancel() 즉시 idle 전환 후 cancelGeneration() await, run() try/catch에 !state.isActive 가드 추가 (취소 후 오류 화면 표시 방지) |
| 2026-05-13 | 버그수정: generation_service generation_time null 안전성 — result['generation_time'] null 시 "null초" 방지, 빈 문자열로 처리 |
| 2026-05-14 | 앱 제목 SD Local → ImageGenerator 변경 (main.dart, main.cpp, local_notifier) |
| 2026-05-14 | transformers 5.8.0 → 4.57.6 다운그레이드 — CLIPTextModel 호환성 오류 수정 |
| 2026-05-14 | splash_screen: 돌아가기 버튼 pop() → pushReplacement(StartupScreen) 수정 (검은 화면 버그) |
| 2026-05-14 | process_manager: WidgetsBindingObserver + AppLifecycleState.detached로 앱 종료 시 Python 프로세스 확실히 종료 |
| 2026-05-14 | process_manager: stop()에서 SIGKILL 사용으로 프로세스 종료 강화 |
| 2026-05-14 | gallery: 상세 패널 Column → SingleChildScrollView로 오버플로우 수정 |
| 2026-05-14 | gallery: 재생성 시 시드 -1(랜덤)으로 변경, 인페인트 열기도 동일 |
| 2026-05-14 | home_screen: onDestinationSelected에서 homeTabNotifier.value 동기화 — 재생성 탭 이동 안 되던 버그 수정 |
| 2026-05-14 | txt2img/img2img: 결과 영역 우상단 X 버튼 추가 (이미지 + 사이드바 동시 초기화) |
| 2026-05-14 | home_screen 사이드바: 완료 상태에 닫기 버튼 추가 |
| 2026-05-14 | services/session_storage.dart 신규: preferences.json / last_session.json 로컬 파일 읽기·쓰기 |
| 2026-05-14 | settings: "일반" 섹션 추가 — "마지막 프롬프트 불러오기" 토글 (preferences.json에 즉시 저장) |
| 2026-05-14 | txt2img/img2img: 생성 시 SessionStorage.saveSession() 호출, 앱 재시작 후 설정 켜져있으면 자동 복원 |
| 2026-05-14 | backend/mcp_server.py 신규: MCP stdio 서버 — get_health/list_models/list_loras/load_model/txt2img/get_progress/cancel_generation/get_gallery/get_presets 9개 도구 |
| 2026-05-14 | ~/.claude.json mcpServers에 imagegenerator 등록 — Claude Code에서 자연어로 이미지 생성 제어 가능 |
| 2026-05-14 | ~/.gemini/settings.json mcpServers에 imagegenerator 등록 — Gemini CLI에서도 MCP 서버 제어 가능 |
| 2026-05-14 | CLAUDE.md / GEMINI.md 신규: AI 도구가 MCP 서버를 즉시 이해·사용할 수 있도록 가이드 문서 작성 |
| 2026-05-14 | sd_engine: diffusers 포맷 캐시 구현 — 최초 로딩 후 models/cache/{모델명}_{precision}/ 저장, 재실행 시 from_pretrained()로 빠른 로딩 |
| 2026-05-14 | main.py: GET /debug/logs 엔드포인트 추가 — 오늘 로그 또는 error.log 최근 N줄 반환 |
| 2026-05-14 | mcp_server: get_logs / get_config / set_config 디버그 도구 3개 추가 |
| 2026-05-14 | mcp_server get_logs: HTTP 404 시 명확한 에러 메시지 반환 (구버전 백엔드 감지) |
| 2026-05-14 | diffusers 캐시 첫 실행 검증 — chilloutmix fp16 캐시 생성 11.0s, 이후 로딩 2~3s 예상 |
| 2026-05-14 | backend/safety.json 신규: 프롬프트 블록리스트 + AI 메타데이터 설정 분리 관리 |
| 2026-05-14 | main.py: check_prompt() 추가 — txt2img/img2img/inpaint 3개 엔드포인트 프롬프트 필터 적용 |
| 2026-05-14 | main.py: save_image_with_metadata에 PNG 메타데이터(AI-Generated, Software) 자동 삽입 |
| 2026-05-14 | safety.json: safety_checker 섹션 추가 (enabled, checkpoint, feature_extractor) |
| 2026-05-14 | sd_engine: apply_safety_checker() / remove_safety_checker() 추가 — 파이프라인 캐시와 분리해 토글 가능 |
| 2026-05-14 | main.py /model/load: 모델 로딩 후 safety.json 읽어 safety checker 자동 주입/해제 |
| 2026-05-14 | run.bat / run_server.bat 신규: 더블클릭으로 앱/백엔드 실행 |
| 2026-05-14 | backend.spec 개선: collect_all()로 torch/diffusers/transformers 바이너리 전체 수집, safety.json datas 포함, UPX 비활성화 |
| 2026-05-14 | build.ps1 개선: 앱 이름 ImageGenerator, safety.json 복사, models/cache 폴더 생성, utf8NoBOM 인코딩 |
| 2026-05-14 | splash_screen: sd_backend.exe 존재 여부로 배포/개발 자동 분기 (start vs startDev) |
| 2026-05-14 | port_check: get_port_process(port) 추가 — psutil.net_connections()로 해당 포트 점유 프로세스 조회 (pid/name/exe/cmdline) |
| 2026-05-14 | main.py: GET /debug/port/{port_number} 엔드포인트 추가 — 포트 점유 프로세스 정보 반환 |
| 2026-05-14 | main.py: 시작 시 포트 충돌 감지 시 점유 프로세스 정보 콘솔 출력 |
| 2026-05-14 | txt2img/img2img: Batch Size 슬라이더(1~16) + 직접 입력 필드 결합 — _intInputRow() 위젯, TextEditingController 동기화 |
| 2026-05-14 | EULA.txt 신규: 11개 조항 한국어 EULA (라이선스 부여, 금지 행위, AI 모델 라이선스 준수, 프라이버시, 면책, 준거법 등) |
| 2026-05-14 | eula_screen.dart 신규: 스크롤 끝 도달 게이트 + 체크박스 + 동의 버튼 활성화, eula.json 기록 후 StartupScreen으로 이동 |
| 2026-05-14 | main.dart: _isEulaAccepted() 추가 — eula.json 존재 시 StartupScreen, 미동의 시 EulaScreen으로 분기 |
| 2026-05-14 | build.py 신규: build.ps1을 Python으로 대체 — argparse (--skip-backend/frontend/package, --flutter-only), 크로스플랫폼, find_flutter() 자동 탐색 |
| 2026-05-14 | build.py: LNK1168 방지를 위해 빌드 전 sd_local_app.exe taskkill 추가 |
| 2026-05-14 | .gitignore: eula.json, preferences.json, last_session.json, .claude/, *_bak.json 추가 |
| 2026-05-14 | requirements.txt: psutil==7.2.2, httpx==0.28.1, mcp==1.9.0 추가 |
| 2026-05-14 | safety.json: 배포용 프롬프트 블록리스트 키워드 완성 (CSAM 관련 23개 키워드) |
| 2026-05-15 | EULA: 제2조에 만 18세 미만 사용 금지 조항 추가 |
| 2026-05-15 | EULA: 제4조에 비동의 성적 딥페이크 금지 조항 추가 (성폭력처벌법 14조의2 명시) |
| 2026-05-15 | EULA: 제4조에 불법 음란물 금지 조항 추가 (정보통신망법 명시), 초상권 침해 금지 추가 |
| 2026-05-15 | EULA: 제5조 모델 라이선스 조항 강화 — CivitAI/Hugging Face 확인 안내, 면책 명시 |
| 2026-05-15 | EULA: 핵심 요약 업데이트 (18세 제한, 딥페이크, 음란물, 초상권 항목 추가) |
| 2026-05-15 | safety.json: 비동의 성적 콘텐츠 키워드 추가 (rape, sexual assault, non-consensual, revenge porn, deepfake nude/sex/porn 등) |
| 2026-05-15 | lora_screen: 학습 시작 전 저작권·초상권 확인 경고 다이얼로그 추가 |
| 2026-05-15 | startup_screen: 모델 선택 드롭다운 아래 라이선스 확인 안내 문구 추가 |
| 2026-05-15 | THIRD_PARTY_NOTICES.txt 신규: 15개 오픈소스 라이브러리 저작권 고지 (PyTorch/diffusers/transformers/FastAPI/Flutter 등) |
| 2026-05-15 | build.py: 패키징 시 THIRD_PARTY_NOTICES.txt 자동 복사 추가 |
| 2026-05-17 | run.bat: 절대경로 → %~dp0 상대경로로 수정 (이식성 개선) |
| 2026-05-17 | build.py: flutter pub get 누락 추가 (패키지 캐시 없는 환경에서 빌드 실패 수정) |
| 2026-05-17 | settings_screen: 런타임 모델 교체 UI 추가 — 현재 모델 표시, 드롭다운 선택, 정밀도/VRAM/CPU 옵션, 교체 버튼 |
| 2026-05-17 | flutter analyze: 전체 프로젝트 0 issues 달성 (deprecated API 교체, 미사용 import/필드 정리 등 43건) |

---

## 전체 Phase 요약

| Phase | 내용 | 상태 |
|---|---|---|
| Phase 1 | Python FastAPI + diffusers 백엔드 | ✅ 완료 |
| Phase 2 | Flutter Windows 앱 기초 | ✅ 완료 |
| Phase 3 | txt2img / img2img UI | ✅ 완료 |
| Phase 4 | 프리셋 저장/불러오기 | ✅ 완료 |
| Phase 5 | 갤러리 (이미지 관리) | ✅ 완료 |
| Phase 6 | LoRA 파인튜닝 UI | ✅ 완료 |
| Phase 7 | 로그 시스템 | ✅ 완료 |
| Phase 8 | PyInstaller + Flutter build → 배포 | ✅ 완료 |

---

## Phase 1 — Python FastAPI + diffusers 백엔드 ✅

**완료일**: 2026-05-13

### 작업 내역
- [x] 프로젝트 디렉토리 구조 생성
- [x] Python 3.10 가상환경 (`venv/`) 생성
- [x] PyTorch 2.6.0 (CUDA 12.4 빌드) 설치
- [x] diffusers, transformers, accelerate, peft, fastapi, uvicorn, safetensors 설치
- [x] `backend/port_check.py` — 포트 가용 여부 확인 및 자동 탐색
- [x] `backend/sd_engine.py` — diffusers 래퍼 (txt2img / img2img / LoRA 적용)
- [x] `backend/lora_train.py` — LoRA 파인튜닝 (비동기 스레드)
- [x] `backend/main.py` — FastAPI 엔드포인트 전체
- [x] `config.json` 초기 설정 파일
- [x] `presets.json` 초기 프리셋 파일
- [x] `requirements.txt`
- [x] `.gitignore`

### API 엔드포인트 (구현 완료)
| Method | Endpoint | 기능 |
|---|---|---|
| GET | /health | 서버 상태 + VRAM 정보 |
| POST | /model/load | 모델 로딩 |
| POST | /txt2img | 텍스트 → 이미지 생성 |
| POST | /img2img | 이미지 변환 |
| POST | /generate/cancel | 생성 취소 |
| POST | /lora/train | LoRA 학습 시작 |
| GET | /lora/status/{id} | 학습 진행률 |
| GET | /lora/list | LoRA 목록 |
| GET | /presets | 프리셋 전체 조회 |
| POST | /presets | 프리셋 저장 |
| DELETE | /presets/{id} | 프리셋 삭제 |
| GET | /config | 설정 조회 |
| PUT | /config | 설정 저장 |
| GET | /models/base | 베이스 모델 목록 |

### 미해결 사항
- SD 모델 파일 없음 — `models/base/`에 `.safetensors` 파일 필요 (실행 테스트 불가)
- LoRA 학습 저장 경로 로직 추후 정밀 검토 필요

---

## Phase 2~6 — Flutter 앱 전체 UI ✅

**완료일**: 2026-05-13

### 작업 내역
- [x] Flutter SDK 3.41.9 설치 (D:\flutter\flutter)
- [x] Flutter Windows 프로젝트 생성 (`frontend/`)
- [x] `process_manager.dart` — Python 프로세스 자동 실행/종료
- [x] `api_service.dart` — HTTP 통신 서비스 (전 엔드포인트)
- [x] `startup_screen.dart` — 초기 설정 화면 (10초 카운트다운, 설정 변경 감지)
- [x] `splash_screen.dart` — 로딩 화면 (단계별 진행 상태)
- [x] `home_screen.dart` — 사이드 네비게이션 (NavigationRail)
- [x] `txt2img_screen.dart` — 기본/고급/LoRA 탭, 생성 진행률, 취소
- [x] `img2img_screen.dart` — 이미지 입력, denoising strength
- [x] `gallery_screen.dart` — 그리드, 필터/검색/정렬, 상세보기, 다중선택 삭제
- [x] `lora_screen.dart` — 학습 파라미터, 진행률 폴링
- [x] `settings_screen.dart` — 서버/모델/출력/로그 설정

### 미해결 사항
- Flutter 개발자 모드 (Windows Developer Mode) 미활성화 상태
  → 빌드 전 사용자가 수동으로 활성화 필요
  → Windows 설정 → 업데이트 및 보안 → 개발자용 → 개발자 모드 ON
- 파일 선택 UI가 경로 직접 입력 방식 (file_picker 패키지 미사용)
  → 추후 file_picker 패키지 추가로 개선 가능

---

## Phase 7 — 로그 시스템 ✅

**완료일**: 2026-05-13

### 작업 내역
- [x] `backend/logger.py` — SDLogger 클래스
  - 날짜별 로그 파일 (`logs/YYYY-MM-DD.log`)
  - 파일 크기 초과 시 순번 분리 (`_2`, `_3` ...)
  - `error.log` 별도 누적
  - 보관 기간 자동 삭제
  - 콘솔 동시 출력
- [x] `main.py`에 로그 연동
  - 앱 시작/종료
  - 모델 로딩 시작/완료/실패
  - txt2img / img2img 생성 완료 (시간 + seed)
  - LoRA 학습 시작
  - API 에러

---

## Phase 8 — 배포 ✅

**완료일**: 2026-05-13

### 작업 내역
- [x] `backend.spec` — PyInstaller 스펙 파일
- [x] `build.ps1` — 전체 빌드 자동화 스크립트
  - Python 백엔드 → PyInstaller 번들
  - Flutter → Windows Release 빌드
  - 두 결과물 + 폴더 구조 → `dist/sd_local_app/` 조립

### 빌드 실행 방법
```powershell
.\build.ps1              # 전체 빌드
.\build.ps1 -SkipBackend # Flutter만
.\build.ps1 -SkipFrontend # Python만
```

### 미해결 사항
- PyInstaller 빌드는 모델 파일 없이 테스트 불가
- torch/diffusers 포함 시 dist 크기 수 GB 예상 → 모델은 별도 배포
- Flutter에서 `window_manager` 미사용 (Developer Mode 없이 빌드)
  → 창 크기/제목 고정 기능 제한됨 (추후 Developer Mode 활성화 후 추가 가능)

---

## 계획된 기능 (미구현)

| 기능 | 세부 내용 | 우선순위 |
|---|---|---|
| 다크모드 / 테마 커스텀 | `ThemeService` 싱글턴, `ThemeConfig` (isDark, accentColor, bgImagePath, bgOverlay), settings 테마 섹션 | 높음 |
| 배경 이미지 | 커스텀 PNG/JPG 배경 + 오버레이 불투명도 슬라이더 | 높음 |
| 강조색 커스텀 | 색상 팔레트 그리드 (7~10가지 사전정의 색) | 중간 |
| Android 지원 | Flutter 코드 재사용 (UI 레이아웃 조정 필요) | 낮음 |
| Upscaling | Real-ESRGAN 연동 | 낮음 |
| ControlNet | sd_engine에 ControlNet 파이프라인 추가 | 낮음 |
