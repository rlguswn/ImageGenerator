import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'app_paths.dart';

class ProcessManager {
  Process? _process;
  int port;

  ProcessManager({this.port = 8000});

  // 배포된 앱에서 번들된 Python 백엔드 실행
  Future<void> start({void Function(String)? onLog}) async {
    await _killExisting();

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final backendExe = '$exeDir${sep}sd_backend${sep}sd_backend.exe';

    _process = await Process.start(
      backendExe,
      [],
      workingDirectory: exeDir,
    );
    _attachListeners(onLog);
  }

  Future<void> _killExisting() async {
    try {
      await Process.run(
        'taskkill',
        ['/F', '/IM', 'sd_backend.exe'],
        runInShell: true,
      );
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  // 개발 환경에서 venv Python으로 실행 (없으면 시스템 python 폴백)
  Future<void> startDev({void Function(String)? onLog}) async {
    final root = findProjectRoot();
    final sep = Platform.pathSeparator;
    final venvPython = '$root${sep}venv${sep}Scripts${sep}python.exe';
    final python = File(venvPython).existsSync() ? venvPython : 'python';
    final script = '$root${sep}backend${sep}main.py';

    _process = await Process.start(
      python,
      [script],
      workingDirectory: root,
    );
    _attachListeners(onLog);
  }

  void _attachListeners(void Function(String)? onLog) {
    _process!.stdout.transform(SystemEncoding().decoder).listen((line) {
      onLog?.call(line.trim());
    });
    _process!.stderr.transform(SystemEncoding().decoder).listen((line) {
      onLog?.call('[ERR] ${line.trim()}');
    });
  }

  Future<bool> waitUntilReady({
    int timeoutSeconds = 60,
    void Function(String)? onStatus,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await http
            .get(Uri.parse('http://127.0.0.1:$port/health'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
      onStatus?.call('서버 응답 대기 중...');
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  void stop() {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigkill);
      _process = null;
    }
  }

  bool get isRunning => _process != null;
}

final processManager = ProcessManager();
