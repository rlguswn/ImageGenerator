# ImageGenerator

Stable Diffusion 기반 Windows 로컬 이미지 생성 앱.  
인터넷 연결 없이 PC에서 직접 AI 이미지를 생성할 수 있습니다.

## 주요 기능

- **텍스트 → 이미지 (txt2img)** — 프롬프트로 이미지 생성, 배치 생성, 프롬프트 히스토리
- **이미지 → 이미지 (img2img)** — 입력 이미지 기반 변형, 비교 슬라이더
- **인페인팅 (Inpaint)** — 마스크 영역 부분 재생성, 브러시/지우개/되돌리기
- **LoRA 학습** — 커스텀 이미지로 LoRA 모델 학습
- **갤러리** — 생성 이미지 관리, 필터/정렬/검색, 메타데이터 조회, 재생성
- **런타임 모델 교체** — 앱 재시작 없이 설정 탭에서 모델 변경
- **프리셋** — 자주 쓰는 설정 저장·불러오기
- **MCP 서버** — Claude Code 등 AI 도구로 자연어 이미지 생성 제어

## 스크린샷

> 앱 실행 후 `output/` 폴더에서 생성 결과를 확인할 수 있습니다.

## 시스템 요구사항

| 항목 | 최소 사양 |
|---|---|
| OS | Windows 10 64-bit 이상 |
| GPU | NVIDIA GPU (CUDA 지원, VRAM 4GB 이상 권장) |
| RAM | 8GB 이상 |
| 저장공간 | 모델 파일 포함 약 10GB 이상 |
| Python | 3.10 이상 |
| Flutter | 3.x (개발 모드 실행 시) |

> CPU 전용 실행도 가능하지만 생성 속도가 매우 느립니다.

## 빠른 시작

### 1. 저장소 클론

```bash
git clone https://github.com/rlguswn/ImageGenerator.git
cd ImageGenerator
```

### 2. 모델 파일 준비

[CivitAI](https://civitai.com) 또는 [Hugging Face](https://huggingface.co)에서 `.safetensors` 모델 파일을 다운로드한 후 `models/base/` 폴더에 넣습니다.

> ⚠️ 모델 사용 전 해당 모델의 라이선스를 반드시 확인하세요.

### 3. 빌드 및 실행

```bash
# Flutter 앱 빌드 (venv 자동 생성 포함)
python build.py --flutter-only

# 앱 실행
run.bat
```

### 개발 모드 실행 (빌드 없이)

```bash
# venv 자동 생성 + flutter run
run_dev.bat
```

## 빌드 옵션

```bash
python build.py                  # 전체 빌드 (백엔드 + Flutter + 패키징)
python build.py --flutter-only   # Flutter 앱만 빌드 (가장 자주 사용)
python build.py --skip-backend   # Flutter + 패키징만
python build.py --skip-package   # 빌드만 (패키징 생략)
```

> 첫 실행 시 `venv/`가 없으면 자동으로 생성하고 `requirements.txt`를 설치합니다.

## 디렉토리 구조

```
ImageGenerator/
├── backend/            # FastAPI + Stable Diffusion 엔진
│   ├── main.py         # API 엔드포인트
│   ├── sd_engine.py    # diffusers 래퍼 (txt2img / img2img / inpaint)
│   ├── lora_train.py   # LoRA 학습
│   ├── mcp_server.py   # MCP stdio 서버
│   ├── logger.py       # 날짜별 로그 관리
│   └── safety.json     # 프롬프트 필터 설정
├── frontend/           # Flutter Windows 앱
│   └── lib/
│       ├── screens/    # 각 화면 (txt2img, img2img, inpaint, gallery 등)
│       └── services/   # API, 생성 상태, 세션 저장 등
├── models/
│   ├── base/           # .safetensors 모델 파일 위치
│   └── lora/           # LoRA 파일 위치
├── output/             # 생성된 이미지 저장
├── logs/               # 서버 로그
├── build.py            # 빌드 자동화
├── run.bat             # 앱 실행 (빌드 완료 후)
└── run_dev.bat         # 개발 모드 실행
```

## 설정

앱 첫 실행 시 `config.json`이 자동 생성됩니다. 주요 설정:

| 항목 | 기본값 | 설명 |
|---|---|---|
| `server.port` | `8000` | 백엔드 서버 포트 |
| `generation.width/height` | `512` | 기본 이미지 해상도 |
| `generation.steps` | `20` | 디노이징 스텝 수 |
| `generation.precision` | `fp16` | 연산 정밀도 (`fp16` / `fp32`) |
| `generation.vram_optimization` | `false` | VRAM 절약 모드 |
| `generation.cpu_offload` | `false` | CPU 오프로드 |

## MCP 서버 (Claude Code 연동)

앱 실행 중 Claude Code에서 자연어로 이미지 생성을 제어할 수 있습니다.

```json
// ~/.claude.json mcpServers 섹션에 추가
{
  "mcpServers": {
    "imagegenerator": {
      "command": "python",
      "args": ["D:/project/ImageGenerator/backend/mcp_server.py"]
    }
  }
}
```

사용 예:
```
"고양이가 우주복 입은 이미지 만들어줘"
"512x768 세로 비율로 일본 풍경 생성해줘"
"현재 생성 진행률 보여줘"
```

## 기술 스택

| 구분 | 기술 |
|---|---|
| 백엔드 | Python 3.10, FastAPI, diffusers, PyTorch (CUDA) |
| 프론트엔드 | Flutter 3.x (Windows) |
| 이미지 생성 | Stable Diffusion (safetensors 포맷) |
| LoRA | PEFT, 커스텀 학습 파이프라인 |
| 패키징 | PyInstaller (백엔드), Flutter build (프론트엔드) |

## 라이선스

이 소프트웨어는 [EULA.txt](EULA.txt) 조건 하에 제공됩니다.  
사용 전 반드시 내용을 확인하세요.

사용된 오픈소스 라이브러리 고지는 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)를 참조하세요.
