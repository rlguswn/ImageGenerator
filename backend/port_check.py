import socket
import psutil


def get_port_process(port: int) -> dict | None:
    """해당 포트를 점유 중인 프로세스 정보 반환. 없으면(또는 조회 권한이 없으면) None."""
    try:
        connections = psutil.net_connections(kind="inet")
    except (psutil.AccessDenied, PermissionError):
        # macOS는 다른 프로세스의 연결 목록 조회 자체를 막는 경우가 있음 —
        # 이 경우 "누가 쓰는지 모름"으로 취급하고 넘어간다
        return None
    for conn in connections:
        if conn.laddr.port == port and conn.status == "LISTEN":
            try:
                proc = psutil.Process(conn.pid)
                return {
                    "pid": conn.pid,
                    "name": proc.name(),
                    "exe": proc.exe(),
                    "cmdline": " ".join(proc.cmdline()),
                }
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                return {"pid": conn.pid, "name": "알 수 없음", "exe": "", "cmdline": ""}
    return None


def is_port_available(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind(("127.0.0.1", port))
            return True
        except OSError:
            return False


def find_available_port(start_port: int = 8000, max_tries: int = 20) -> int:
    for port in range(start_port, start_port + max_tries):
        if is_port_available(port):
            return port
    raise RuntimeError(f"포트 {start_port}~{start_port + max_tries - 1} 모두 사용 중")
