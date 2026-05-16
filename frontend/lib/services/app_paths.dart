import 'dart:io';

String findProjectRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    if (Directory('${dir.path}${Platform.pathSeparator}venv').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

String get outputDirPath =>
    '${findProjectRoot()}${Platform.pathSeparator}output';
