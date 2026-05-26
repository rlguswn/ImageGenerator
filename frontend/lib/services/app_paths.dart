import 'dart:io';

String findProjectRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    final p = dir.path;
    final sep = Platform.pathSeparator;
    // 배포판: sd_backend 폴더 존재, 개발환경: venv 폴더 존재
    if (Directory('$p${sep}sd_backend').existsSync() ||
        Directory('$p${sep}venv').existsSync()) {
      return p;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

String get outputDirPath =>
    '${findProjectRoot()}${Platform.pathSeparator}output';
