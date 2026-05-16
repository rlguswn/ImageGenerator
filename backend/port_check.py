import socket
import psutil


def get_port_process(port: int) -> dict | None:
    """해당 포트를 점유 중인 프로세스 정보 반환. 없으면 None."""
    for conn in psutil.net_connections(kind="inet"):
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
