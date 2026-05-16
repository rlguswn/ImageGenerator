import 'dart:convert';
import 'dart:io';
import 'app_paths.dart';

class SessionStorage {
  static String get _sessionPath =>
      '${findProjectRoot()}${Platform.pathSeparator}last_session.json';

  static String get _prefsPath =>
      '${findProjectRoot()}${Platform.pathSeparator}preferences.json';

  static Map<String, dynamic> loadPrefs() {
    try {
      final f = File(_prefsPath);
      if (!f.existsSync()) return {};
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static void savePrefs(Map<String, dynamic> data) {
    try {
      final existing = loadPrefs();
      existing.addAll(data);
      File(_prefsPath).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(existing));
    } catch (_) {}
  }

  static Map<String, dynamic> loadSession() {
    try {
      final f = File(_sessionPath);
      if (!f.existsSync()) return {};
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static void saveSession(String mode, String prompt, String negative) {
    try {
      final existing = loadSession();
      existing[mode] = {'prompt': prompt, 'negative': negative};
      File(_sessionPath).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(existing));
    } catch (_) {}
  }
}
