import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'screens/eula_screen.dart';
import 'screens/startup_screen.dart';
import 'services/app_paths.dart';
import 'services/process_manager.dart';

bool _isEulaAccepted() {
  final path = '${findProjectRoot()}${Platform.pathSeparator}eula.json';
  final file = File(path);
  if (!file.existsSync()) return false;
  try {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return data['accepted'] == true;
  } catch (_) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await localNotifier.setup(appName: 'ImageGenerator');
  runApp(SdLocalApp(eulaAccepted: _isEulaAccepted()));
}

class SdLocalApp extends StatefulWidget {
  final bool eulaAccepted;
  const SdLocalApp({super.key, required this.eulaAccepted});

  @override
  State<SdLocalApp> createState() => _SdLocalAppState();
}

class _SdLocalAppState extends State<SdLocalApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      processManager.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 동기적으로 taskkill 호출 (dispose는 async 불가)
    Process.runSync('taskkill', ['/F', '/IM', 'sd_backend.exe'],
        runInShell: true);
    processManager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImageGenerator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3460),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: widget.eulaAccepted ? const StartupScreen() : const EulaScreen(),
    );
  }
}
