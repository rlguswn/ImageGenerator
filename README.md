# ImageGenerator

Stable Diffusion 기반 Windows 로컬 이미지 생성 앱.  
인터넷 연결 없이 PC에서 직접 AI 이미지를 생성할 수 있습니다.

---

## 목차

1. [시스템 요구사항](#시스템-요구사항)
2. [설치 및 실행](#설치-및-실행)
3. [기능 상세](#기능-상세)
   - [텍스트 → 이미지 (txt2img)](#텍스트--이미지-txt2img)
   - [이미지 → 이미지 (img2img)](#이미지--이미지-img2img)
   - [인페인팅 (Inpaint)](#인페인팅-inpaint)
   - [LoRA 학습](#lora-학습)
   - [갤러리](#갤러리)
   - [설정](#설정)
4. [MCP 서버 (Claude Code 연동)](#mcp-서버-claude-code-연동)
5. [디렉토리 구조](#디렉토리-구조)
6. [기술 스택](#기술-스택)
7. [라이선스](#라이선스)

---

## 시스템 요구사항

| 항목 | 최소 사양 |
|---|---|
| OS | Windows 10 64-bit 이상 |
| GPU | NVIDIA GPU (CUDA 지원, VRAM 4GB 이상 권장) |
| RAM | 16GB 이상 권장 |
| 저장공간 | 모델 파일 포함 약 10GB 이상 |
| Python | 3.10 이상 |
| Flutter | 3.x (개발 모드 실행 시) |

> CPU 전용 실행도 가능하지만 이미지 1장 생성에 수 분 이상 소요될 수 있습니다.

---

## 설치 및 실행

### 1. 저장소 클론

```bash
git clone https://github.com/rlguswn/ImageGenerator.git
cd ImageGenerator
```

### 2. 모델 파일 준비

[CivitAI](https://civitai.com) 또는 [Hugging Face](https://huggingface.co)에서 Stable Diffusion `.safetensors` 모델 파일을 다운로드한 후 `models/base/` 폴더에 넣습니다.

```
models/
└── base/
    └── yourmodel.safetensors   ← 여기에 배치
```

> ⚠️ 모델 사용 전 해당 모델의 라이선스를 반드시 확인하세요.

### 3. 빌드 및 실행

```bash
# Flutter 앱 빌드 (venv 자동 생성 + requirements 설치 포함)
python build.py --flutter-only

# 앱 실행
run.bat
```

> 첫 실행 시 `venv/`가 없으면 자동으로 가상환경을 생성하고 필요한 패키지를 설치합니다.

### 개발 모드 실행 (빌드 없이)

```bash
run_dev.bat
```

Flutter가 PATH에 없어도 `D:\flutter` 또는 `C:\flutter`에 설치되어 있으면 자동으로 찾습니다.

### 빌드 옵션

```bash
python build.py                  # 전체 빌드 (백엔드 exe + Flutter + 패키징)
python build.py --flutter-only   # Flutter 앱만 빌드 (가장 자주 사용)
python build.py --skip-backend   # Flutter + 패키징만
python build.py --skip-package   # 빌드만 (배포 패키지 생략)
```

---

## 기능 상세

### 텍스트 → 이미지 (txt2img)

프롬프트(텍스트)만으로 이미지를 생성합니다.

#### 프롬프트 작성 요령

- **영어 태그**를 쉼표로 구분해서 입력합니다.
- **긍정 프롬프트**: 원하는 요소를 나열합니다.
  ```
  masterpiece, best quality, 1girl, smile, blue eyes, long hair
  ```
- **부정 프롬프트**: 제외하고 싶은 요소를 나열합니다.
  ```
  lowres, bad anatomy, bad hands, text, watermark, worst quality
  ```

#### 주요 설정값

| 설정 | 설명 | 권장값 |
|---|---|---|
| **해상도** | 이미지 크기 (64의 배수로 입력) | `512x512` ~ `1024x1024` |
| **Steps** | 디노이징 반복 횟수. 높을수록 품질↑, 속도↓ | `20` ~ `30` |
| **CFG Scale** | 프롬프트 충실도. 높을수록 프롬프트를 강하게 반영 | `7` ~ `12` |
| **Sampler** | 이미지 생성 알고리즘 | `DPM++ 2M Karras` |
| **Seed** | 재현성 제어. `-1`이면 매번 다른 이미지 | `-1` (랜덤) |
| **Batch Size** | 한 번에 생성할 이미지 수 | `1` ~ `4` |
| **Clip Skip** | CLIP 레이어 스킵 수. 일부 모델은 `2`가 적합 | `1` ~ `2` |

#### 기타 기능

- **프리셋**: 자주 쓰는 설정을 이름 붙여 저장하고 한 번에 불러올 수 있습니다.
- **히스토리**: 최근 입력한 프롬프트 20개를 기억해 재사용할 수 있습니다.
- **Seed 재사용**: 생성 완료 후 해당 이미지의 Seed를 바로 입력창에 복사합니다.
- **LoRA 적용**: LoRA 탭에서 원하는 LoRA를 선택하고 가중치(0.0 ~ 1.0)를 조절합니다.

---

### 이미지 → 이미지 (img2img)

업로드한 이미지를 기반으로 새로운 이미지를 생성합니다. 이미지의 구도나 색감을 유지하면서 스타일을 바꾸고 싶을 때 유용합니다.

#### 사용 방법

1. **이미지 선택** 버튼으로 입력 이미지를 불러옵니다.
2. 프롬프트로 원하는 변환 방향을 지정합니다.
3. **Denoising Strength**를 조절합니다.

#### Denoising Strength

원본 이미지를 얼마나 많이 바꿀지 결정하는 핵심 값입니다.

| 값 | 효과 |
|---|---|
| `0.2` ~ `0.4` | 원본과 거의 유사, 색감·분위기만 변경 |
| `0.5` ~ `0.7` | 구도는 유지하되 내용이 많이 바뀜 (권장 범위) |
| `0.8` ~ `1.0` | 원본과 거의 무관한 새 이미지 생성 |

#### 결과 비교

생성 완료 후 **비교** 버튼을 누르면 원본과 결과를 슬라이더로 나란히 비교할 수 있습니다.

---

### 인페인팅 (Inpaint)

이미지의 특정 영역만 선택적으로 재생성합니다. 배경은 그대로 두고 인물만 바꾸거나, 이미지의 일부 결함을 수정할 때 활용합니다.

#### 사용 방법

1. **이미지 선택**으로 원본 이미지를 불러옵니다.
2. **마스크 그리기**: 브러시로 재생성하고 싶은 영역을 빨간색으로 칠합니다.
3. 프롬프트를 입력하고 **생성**을 누릅니다.

#### 마스크 도구

| 도구 | 설명 |
|---|---|
| **브러시** | 재생성할 영역을 칠합니다 |
| **지우개** | 마스크를 지웁니다 |
| **브러시 크기** | 슬라이더로 브러시 굵기를 조절합니다 |
| **되돌리기** | 마지막 브러시 획을 취소합니다 |
| **전체 지우기** | 마스크를 전부 초기화합니다 |
| **반전** | 마스크 영역을 반전합니다 (칠한 부분 보존, 나머지 재생성) |

#### 보기 모드

- **편집**: 마스크를 그리는 화면
- **비교**: 원본과 결과를 슬라이더로 비교
- **결과**: 생성된 이미지만 표시

> 인페인팅은 별도 파이프라인(`inpaint`)을 사용하므로 처음 전환 시 모델 재로딩이 필요합니다.

---

### LoRA 학습

커스텀 이미지 데이터셋으로 LoRA(Low-Rank Adaptation) 모델을 학습시킵니다.  
특정 캐릭터, 화풍, 오브젝트를 모델에 학습시켜 프롬프트로 쉽게 재현할 수 있습니다.

#### 준비

1. 학습할 이미지를 한 폴더에 모읍니다 (10장 이상 권장).
2. 이미지는 다양한 각도·구도를 포함할수록 좋습니다.

#### 설정값

| 설정 | 설명 | 권장값 |
|---|---|---|
| **모델 이름** | 저장될 LoRA 파일명 | 영문, 숫자, 언더스코어만 사용 |
| **이미지 폴더** | 학습 이미지가 들어있는 폴더 경로 | |
| **Steps** | 학습 반복 횟수. 이미지 수 × 100 정도가 적절 | `500` ~ `2000` |
| **Learning Rate** | 학습률. 너무 높으면 과적합 | `1e-4` |
| **Network Rank** | LoRA 표현력. 높을수록 용량↑, 표현력↑ | `16` ~ `32` |

#### 사용 시 주의

- 학습에 사용하는 이미지의 저작권자이거나 사용 허가를 받은 경우에만 학습하세요.
- 타인의 얼굴, 초상권이 포함된 이미지 학습은 법적 문제가 발생할 수 있습니다.

학습 완료 후 생성된 LoRA 파일은 `models/lora/` 폴더에 저장되며, txt2img/img2img의 LoRA 탭에서 바로 사용할 수 있습니다.

---

### 갤러리

생성된 모든 이미지를 한 곳에서 관리합니다.

#### 기능

- **필터**: 전체 / txt2img / img2img / inpaint 모드별 분류
- **정렬**: 최신순 / 오래된순
- **검색**: 프롬프트 내용으로 검색
- **썸네일 크기**: 슬라이더로 그리드 크기 조절

#### 이미지 상세 보기

이미지를 클릭하면 우측 패널에 다음 정보가 표시됩니다:

- 생성 프롬프트 / 부정 프롬프트
- 해상도, Steps, CFG Scale, Sampler, Seed
- 생성 소요 시간

#### 이미지 작업

| 버튼 | 기능 |
|---|---|
| **재생성** | 해당 이미지의 설정을 불러와 txt2img/img2img 탭으로 이동 |
| **인페인트로 열기** | 해당 이미지를 인페인팅 입력으로 사용 |
| **프리셋으로 저장** | 현재 이미지의 설정을 프리셋에 저장 |
| **내보내기** | 원하는 경로에 이미지를 복사 |
| **삭제** | 선택한 이미지를 삭제 |

> 다중 선택: 우측 상단 **다중 선택** 버튼 → 이미지 클릭으로 여러 장 선택 → 일괄 삭제

---

### 설정

앱의 동작 방식과 생성 기본값을 설정합니다.

#### 서버 설정

| 항목 | 설명 |
|---|---|
| **포트** | 백엔드 서버 포트 (기본값: `8000`) |
| **자동 포트 탐색** | 포트 충돌 시 다른 포트를 자동으로 사용 |

#### 모델 교체 (런타임)

앱을 재시작하지 않고 다른 모델로 전환할 수 있습니다.

1. **교체할 모델** 드롭다운에서 `models/base/` 폴더의 모델을 선택합니다.
2. 정밀도 (`fp16` / `fp32`) 및 VRAM 최적화 옵션을 설정합니다.
3. **모델 교체** 버튼을 누르면 교체가 시작됩니다 (수십 초 소요).

| 옵션 | 설명 |
|---|---|
| **fp16** | 절반 정밀도. VRAM 절약, 속도 빠름 (권장) |
| **fp32** | 전체 정밀도. VRAM 많이 사용, 일부 모델에서 품질↑ |
| **VRAM 최적화** | VRAM이 부족할 때 활성화. 속도가 다소 느려짐 |
| **CPU 오프로드** | VRAM이 매우 부족할 때 일부 연산을 CPU로 위임 |

#### 경로 설정

| 항목 | 기본값 |
|---|---|
| **베이스 모델 경로** | `models/base/` |
| **LoRA 경로** | `models/lora/` |
| **출력 경로** | `output/` |

#### 로그 설정

| 항목 | 설명 |
|---|---|
| **보관 기간** | 로그 파일 자동 삭제까지의 일수 (기본값: 60일) |

#### 일반

- **마지막 프롬프트 불러오기**: 앱 재시작 후 이전에 입력한 프롬프트를 자동으로 복원합니다.

---

## MCP 서버 (Claude Code 연동)

앱 실행 중 Claude Code 또는 다른 MCP 클라이언트에서 자연어로 이미지 생성을 직접 제어할 수 있습니다.

### 설정

`~/.claude.json`의 `mcpServers` 섹션에 추가합니다:

```json
{
  "mcpServers": {
    "imagegenerator": {
      "command": "python",
      "args": ["D:/project/ImageGenerator/backend/mcp_server.py"]
    }
  }
}
```

### 사용 예시

```
"고양이가 우주복 입은 이미지 만들어줘"
→ txt2img(prompt="masterpiece, best quality, cat wearing spacesuit, space background")

"512x768 세로 비율로 일본 풍경 생성해줘"
→ txt2img(prompt="...", width=512, height=768)

"지금 생성 얼마나 됐어?"
→ get_progress()

"어떤 모델 있어?"
→ list_models()

"steps를 30으로 바꿔줘"
→ set_config(key="generation.steps", value=30)

"최근 오류 로그 보여줘"
→ get_logs(lines=50, level="error")
```

### 사용 가능한 도구

| 도구 | 설명 |
|---|---|
| `get_health` | 서버 상태, 모델 로딩 여부, VRAM 정보 |
| `list_models` | `models/base/`의 사용 가능한 모델 목록 |
| `list_loras` | `models/lora/`의 LoRA 목록 |
| `load_model` | 모델 교체 |
| `txt2img` | 텍스트로 이미지 생성 |
| `get_progress` | 현재 생성 진행률 (step/total/eta) |
| `cancel_generation` | 생성 취소 |
| `get_gallery` | 최근 생성 이미지 목록 |
| `get_presets` | 저장된 프리셋 목록 |
| `get_logs` | 서버 로그 조회 |
| `get_config` | 현재 설정값 조회 |
| `set_config` | 설정값 변경 |

---

## 디렉토리 구조

```
ImageGenerator/
├── backend/
│   ├── main.py           # FastAPI 엔드포인트
│   ├── sd_engine.py      # diffusers 래퍼 (txt2img / img2img / inpaint)
│   ├── lora_train.py     # LoRA 학습 파이프라인
│   ├── mcp_server.py     # MCP stdio 서버
│   ├── logger.py         # 날짜별 로그 파일 관리
│   └── safety.json       # 프롬프트 필터 / AI 메타데이터 설정
├── frontend/
│   └── lib/
│       ├── screens/      # 각 화면 UI
│       └── services/     # API, 생성 상태, 세션 저장
├── models/
│   ├── base/             # 베이스 모델 (.safetensors)
│   ├── lora/             # LoRA 파일
│   └── cache/            # diffusers 포맷 캐시 (빠른 재로딩용)
├── output/               # 생성된 이미지
├── logs/                 # 서버 로그
├── build.py              # 빌드 자동화
├── run.bat               # 앱 실행 (빌드 완료 후)
├── run_dev.bat           # 개발 모드 실행
└── requirements.txt      # Python 의존성
```

---

## 기술 스택

| 구분 | 기술 |
|---|---|
| 백엔드 | Python 3.10, FastAPI, Uvicorn |
| AI 엔진 | PyTorch (CUDA), diffusers, transformers, PEFT |
| 프론트엔드 | Flutter 3.x (Windows Desktop) |
| 패키징 | PyInstaller (백엔드), Flutter build windows (프론트엔드) |

---

## 라이선스

이 소프트웨어는 [EULA.txt](EULA.txt) 조건 하에 제공됩니다.  
사용 전 반드시 내용을 확인하세요.

사용된 오픈소스 라이브러리 고지는 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)를 참조하세요.
