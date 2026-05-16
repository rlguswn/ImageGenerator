# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all, collect_data_files

# 대형 패키지는 collect_all로 바이너리/데이터/히든임포트 전체 수집
torch_datas,        torch_binaries,        torch_hiddenimports        = collect_all('torch')
diffusers_datas,    diffusers_binaries,    diffusers_hiddenimports    = collect_all('diffusers')
transformers_datas, transformers_binaries, transformers_hiddenimports = collect_all('transformers')
accelerate_datas,   accelerate_binaries,   accelerate_hiddenimports   = collect_all('accelerate')
peft_datas,         peft_binaries,         peft_hiddenimports         = collect_all('peft')

a = Analysis(
    ['backend/main.py'],
    pathex=['.'],
    binaries=(
        torch_binaries +
        diffusers_binaries +
        transformers_binaries +
        accelerate_binaries +
        peft_binaries
    ),
    datas=(
        # 설정 파일
        [('backend/safety.json', 'backend')]  +
        # 패키지 데이터
        torch_datas +
        diffusers_datas +
        transformers_datas +
        accelerate_datas +
        peft_datas +
        collect_data_files('safetensors') +
        collect_data_files('PIL')
    ),
    hiddenimports=(
        torch_hiddenimports +
        diffusers_hiddenimports +
        transformers_hiddenimports +
        accelerate_hiddenimports +
        peft_hiddenimports +
        [
            'uvicorn.logging',
            'uvicorn.loops',
            'uvicorn.loops.auto',
            'uvicorn.protocols',
            'uvicorn.protocols.http',
            'uvicorn.protocols.http.auto',
            'uvicorn.protocols.websockets',
            'uvicorn.protocols.websockets.auto',
            'uvicorn.lifespan',
            'uvicorn.lifespan.on',
            'fastapi',
            'pydantic',
            'pydantic.deprecated.class_validators',
            'safetensors',
            'safetensors.torch',
            'PIL',
            'PIL.PngImagePlugin',
        ]
    ),
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'matplotlib', 'notebook', 'ipython', 'IPython',
        'scipy', 'sklearn', 'pandas', 'pytest',
    ],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='sd_backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,   # torch DLL에 UPX 적용 시 충돌 가능
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='sd_backend',
)
