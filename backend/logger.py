import logging
import os
from datetime import datetime, timedelta
from pathlib import Path


class SDLogger:
    def __init__(self, log_dir: str = "logs", retention_days: int = 60, max_file_size_mb: int = 10):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        self.retention_days = retention_days
        self.max_file_size_mb = max_file_size_mb
        self._logger = None
        self._error_handler = None
        self._setup()

    def _get_log_path(self) -> Path:
        base = self.log_dir / f"{datetime.now().strftime('%Y-%m-%d')}.log"
        if not base.exists():
            return base
        if base.stat().st_size < self.max_file_size_mb * 1024 * 1024:
            return base
        # 크기 초과 시 순번 붙이기
        i = 2
        while True:
            rotated = self.log_dir / f"{datetime.now().strftime('%Y-%m-%d')}_{i}.log"
            if not rotated.exists() or rotated.stat().st_size < self.max_file_size_mb * 1024 * 1024:
                return rotated
            i += 1

    def _setup(self):
        self._logger = logging.getLogger("sd_local")
        self._logger.setLevel(logging.DEBUG)
        self._logger.handlers.clear()

        formatter = logging.Formatter(
            "[%(asctime)s] [%(levelname)-5s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )

        # 날짜별 파일 핸들러
        log_path = self._get_log_path()
        file_handler = logging.FileHandler(log_path, encoding="utf-8")
        file_handler.setFormatter(formatter)
        self._logger.addHandler(file_handler)

        # error.log 별도 누적
        error_path = self.log_dir / "error.log"
        error_handler = logging.FileHandler(error_path, encoding="utf-8")
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(formatter)
        self._logger.addHandler(error_handler)

        # 콘솔 출력
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        self._logger.addHandler(console_handler)

        self._cleanup_old_logs()

    def _cleanup_old_logs(self):
        if self.retention_days < 0:
            return
        cutoff = datetime.now() - timedelta(days=self.retention_days)
        for f in self.log_dir.glob("*.log"):
            if f.name == "error.log":
                continue
            try:
                mtime = datetime.fromtimestamp(f.stat().st_mtime)
                if mtime < cutoff:
                    f.unlink()
            except OSError:
                pass

    def _refresh_handler(self):
        # 날짜가 바뀌거나 파일이 커지면 핸들러 갱신
        new_path = self._get_log_path()
        current_path = Path(self._logger.handlers[0].baseFilename) if self._logger.handlers else None
        if current_path != new_path:
            self._setup()

    def info(self, msg: str):
        self._refresh_handler()
        self._logger.info(msg)

    def warn(self, msg: str):
        self._refresh_handler()
        self._logger.warning(msg)

    def error(self, msg: str):
        self._refresh_handler()
        self._logger.error(msg)

    def debug(self, msg: str):
        self._refresh_handler()
        self._logger.debug(msg)


_instance: SDLogger | None = None


def get_logger(retention_days: int = 60, max_file_size_mb: int = 10) -> SDLogger:
    global _instance
    if _instance is None or _instance.retention_days != retention_days or _instance.max_file_size_mb != max_file_size_mb:
        _instance = SDLogger(retention_days=retention_days, max_file_size_mb=max_file_size_mb)
    return _instance
