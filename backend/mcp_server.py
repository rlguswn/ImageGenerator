"""
ImageGenerator MCP Server

Claude Code에서 연결하여 자연어로 이미지 생성을 제어합니다.
앱(FastAPI)이 먼저 실행된 상태에서 사용하세요.
"""
import asyncio
import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
import mcp.types as types

BASE_URL = "http://127.0.0.1:8000"

server = Server("imagegenerator")


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="get_health",
            description="서버 상태, 모델 로딩 여부, VRAM 정보를 확인합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="list_models",
            description="models/base/ 폴더에 있는 베이스 모델 목록을 반환합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="list_loras",
            description="models/lora/ 폴더에 있는 LoRA 목록을 반환합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="load_model",
            description="지정한 모델을 로딩합니다. 생성 전에 모델이 로딩되어 있어야 합니다.",
            inputSchema={
                "type": "object",
                "properties": {
                    "model_path": {
                        "type": "string",
                        "description": "모델 파일 전체 경로 (list_models로 확인)",
                    },
                    "precision": {
                        "type": "string",
                        "enum": ["fp16", "fp32"],
                        "default": "fp16",
                    },
                },
                "required": ["model_path"],
            },
        ),
        types.Tool(
            name="txt2img",
            description=(
                "텍스트 프롬프트로 이미지를 생성합니다. "
                "프롬프트는 Stable Diffusion에 최적화된 영어 태그 형식을 사용하세요. "
                "예: 'masterpiece, best quality, 1girl, solo, long hair, smile'"
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "생성 프롬프트 (영어 태그, 쉼표 구분)",
                    },
                    "negative_prompt": {
                        "type": "string",
                        "description": "네거티브 프롬프트 (기본값: 일반적인 품질 저하 태그)",
                        "default": "lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality",
                    },
                    "width": {"type": "integer", "default": 512},
                    "height": {"type": "integer", "default": 512},
                    "steps": {"type": "integer", "default": 20},
                    "cfg_scale": {"type": "number", "default": 7.0},
                    "seed": {
                        "type": "integer",
                        "default": -1,
                        "description": "-1이면 랜덤",
                    },
                    "sampler": {
                        "type": "string",
                        "default": "DPM++ 2M Karras",
                        "enum": ["DPM++ 2M Karras", "DPM++ 2M"],
                    },
                    "batch_size": {"type": "integer", "default": 1},
                    "loras": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "weight": {"type": "number"},
                            },
                        },
                        "default": [],
                        "description": "적용할 LoRA 목록",
                    },
                },
                "required": ["prompt"],
            },
        ),
        types.Tool(
            name="get_progress",
            description="현재 이미지 생성 진행 상황(step/total/elapsed/eta)을 반환합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="cancel_generation",
            description="현재 진행 중인 이미지 생성을 취소합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_gallery",
            description="최근 생성된 이미지 목록과 메타데이터를 반환합니다.",
            inputSchema={
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "default": 10,
                        "description": "가져올 이미지 수",
                    }
                },
            },
        ),
        types.Tool(
            name="get_presets",
            description="저장된 프롬프트 프리셋 목록을 반환합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_logs",
            description="최근 로그를 반환합니다. 오류 진단에 사용하세요.",
            inputSchema={
                "type": "object",
                "properties": {
                    "lines": {
                        "type": "integer",
                        "default": 50,
                        "description": "가져올 로그 줄 수",
                    },
                    "level": {
                        "type": "string",
                        "enum": ["all", "error"],
                        "default": "all",
                        "description": "all: 전체 로그, error: error.log만",
                    },
                },
            },
        ),
        types.Tool(
            name="get_config",
            description="현재 서버 설정(config.json) 전체를 반환합니다.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="set_config",
            description=(
                "서버 설정 값을 변경합니다. key는 점(.) 구분 경로입니다. "
                "예: 'generation.steps' = 30, 'model.precision' = 'fp16'"
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "key": {
                        "type": "string",
                        "description": "설정 키 (점 구분, 예: generation.steps)",
                    },
                    "value": {
                        "description": "설정 값 (문자열, 숫자, 불리언)",
                    },
                },
                "required": ["key", "value"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    async with httpx.AsyncClient(timeout=3600.0) as client:
        try:
            if name == "get_health":
                r = await client.get(f"{BASE_URL}/health")
                d = r.json()
                lines = [
                    f"상태: {d.get('status')}",
                    f"모델 로딩: {'✅' if d.get('model_loaded') else '❌'}",
                    f"CUDA: {'✅' if d.get('cuda_available') else '❌'}",
                    f"VRAM 전체: {d.get('vram_total', 0)}MB",
                    f"VRAM 사용: {d.get('vram_used', 0)}MB",
                    f"파이프라인: {d.get('pipeline_mode', '-')}",
                ]
                return [types.TextContent(type="text", text="\n".join(lines))]

            elif name == "list_models":
                r = await client.get(f"{BASE_URL}/models/base")
                models = r.json().get("models", [])
                if not models:
                    return [types.TextContent(type="text", text="models/base/에 모델 파일 없음")]
                return [types.TextContent(type="text", text="\n".join(models))]

            elif name == "list_loras":
                r = await client.get(f"{BASE_URL}/lora/list")
                loras = r.json().get("loras", [])
                if not loras:
                    return [types.TextContent(type="text", text="LoRA 없음")]
                return [types.TextContent(type="text", text="\n".join(
                    f"{l['name']} ({l.get('size_mb', '?')}MB)" for l in loras
                ))]

            elif name == "load_model":
                r = await client.post(f"{BASE_URL}/model/load", json={
                    "model_path": arguments["model_path"],
                    "precision": arguments.get("precision", "fp16"),
                    "vram_optimization": False,
                    "cpu_offload": False,
                })
                d = r.json()
                msgs = "\n".join(d.get("messages", []))
                return [types.TextContent(type="text", text=f"모델 로딩 완료\n{msgs}")]

            elif name == "txt2img":
                r = await client.post(f"{BASE_URL}/txt2img", json={
                    "prompt": arguments.get("prompt", ""),
                    "negative_prompt": arguments.get(
                        "negative_prompt",
                        "lowres, bad anatomy, bad hands, text, error, worst quality, low quality",
                    ),
                    "width": arguments.get("width", 512),
                    "height": arguments.get("height", 512),
                    "steps": arguments.get("steps", 20),
                    "cfg_scale": arguments.get("cfg_scale", 7.0),
                    "seed": arguments.get("seed", -1),
                    "sampler": arguments.get("sampler", "DPM++ 2M Karras"),
                    "batch_size": arguments.get("batch_size", 1),
                    "clip_skip": 1,
                    "loras": arguments.get("loras", []),
                })
                d = r.json()
                seed = d.get("seed", -1)
                gen_time = d.get("generation_time", "?")
                count = len(d.get("images", []))
                saved = d.get("saved_paths", [])
                path_info = f"\n저장 경로:\n" + "\n".join(saved) if saved else ""
                return [types.TextContent(
                    type="text",
                    text=f"✅ 생성 완료! {count}장 | seed: {seed} | {gen_time}초{path_info}",
                )]

            elif name == "get_progress":
                r = await client.get(f"{BASE_URL}/generate/progress")
                d = r.json()
                step = d.get("step", 0)
                total = d.get("total", 0)
                elapsed = d.get("elapsed", 0)
                eta = d.get("eta", 0)
                if total > 0:
                    pct = int(step / total * 100)
                    return [types.TextContent(
                        type="text",
                        text=f"진행률: {step}/{total} ({pct}%) | 경과: {elapsed:.1f}초 | ETA: {eta:.1f}초",
                    )]
                return [types.TextContent(type="text", text="생성 중이 아닙니다")]

            elif name == "cancel_generation":
                await client.post(f"{BASE_URL}/generate/cancel")
                return [types.TextContent(type="text", text="생성 취소됨")]

            elif name == "get_gallery":
                limit = arguments.get("limit", 10)
                r = await client.get(f"{BASE_URL}/gallery?limit={limit}")
                items = r.json().get("items", [])
                if not items:
                    return [types.TextContent(type="text", text="갤러리가 비어있습니다")]
                lines = []
                for item in items[:limit]:
                    lines.append(
                        f"[{item.get('date', '')}] {item.get('mode', '')} | "
                        f"seed:{item.get('seed', '')} | {item.get('prompt', '')[:60]}"
                    )
                return [types.TextContent(type="text", text="\n".join(lines))]

            elif name == "get_presets":
                r = await client.get(f"{BASE_URL}/presets")
                presets = r.json().get("presets", [])
                if not presets:
                    return [types.TextContent(type="text", text="프리셋 없음")]
                lines = [
                    f"[{p['id']}] {p['name']} ({p.get('mode', 'txt2img')})"
                    for p in presets
                ]
                return [types.TextContent(type="text", text="\n".join(lines))]

            elif name == "get_logs":
                r = await client.get(
                    f"{BASE_URL}/debug/logs",
                    params={
                        "lines": arguments.get("lines", 50),
                        "level": arguments.get("level", "all"),
                    },
                )
                if r.status_code != 200:
                    return [types.TextContent(type="text", text=f"❌ /debug/logs 응답 {r.status_code} — 백엔드를 재시작하세요")]
                d = r.json()
                log_lines = d.get("logs", [])
                file_name = d.get("file", "")
                if not log_lines:
                    return [types.TextContent(type="text", text="로그 없음")]
                header = f"[{file_name}] 최근 {len(log_lines)}줄:\n"
                return [types.TextContent(type="text", text=header + "\n".join(log_lines))]

            elif name == "get_config":
                r = await client.get(f"{BASE_URL}/config")
                import json
                return [types.TextContent(
                    type="text",
                    text=json.dumps(r.json(), ensure_ascii=False, indent=2),
                )]

            elif name == "set_config":
                key: str = arguments["key"]
                value = arguments["value"]
                r = await client.get(f"{BASE_URL}/config")
                config = r.json()
                parts = key.split(".")
                node = config
                for part in parts[:-1]:
                    node = node.setdefault(part, {})
                node[parts[-1]] = value
                await client.put(f"{BASE_URL}/config", json=config)
                return [types.TextContent(
                    type="text",
                    text=f"✅ {key} = {value} 로 변경됨 (앱 재시작 시 일부 설정 반영)",
                )]

            else:
                return [types.TextContent(type="text", text=f"알 수 없는 도구: {name}")]

        except httpx.ConnectError:
            return [types.TextContent(
                type="text",
                text="❌ 서버에 연결할 수 없습니다. ImageGenerator 앱을 먼저 실행하세요.",
            )]
        except Exception as e:
            return [types.TextContent(type="text", text=f"❌ 오류: {e}")]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(),
        )


if __name__ == "__main__":
    asyncio.run(main())
