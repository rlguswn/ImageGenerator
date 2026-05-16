import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/process_manager.dart';
import 'home_screen.dart';
import 'startup_screen.dart';

class SplashScreen extends StatefulWidget {
  final String modelPath;
  final int port;
  final String precision;
  final bool vramOptimization;
  final bool cpuOffload;

  const SplashScreen({
    super.key,
    required this.modelPath,
    required this.port,
    required this.precision,
    required this.vramOptimization,
    required this.cpuOffload,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<_Step> _steps = [
    _Step('Python 엔진 시작 중...'),
    _Step('서버 응답 대기 중...'),
    _Step('SD 모델 로딩 중...'),
  ];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      // Step 0: Python 프로세스 시작
      _setStepRunning(0);
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final backendExe = '$exeDir${Platform.pathSeparator}sd_backend${Platform.pathSeparator}sd_backend.exe';
      final isRelease = File(backendExe).existsSync();
      if (isRelease) {
        await processManager.start(onLog: (line) {
          if (line.contains('모델 로딩') && mounted) _setStepRunning(2);
        });
      } else {
        await processManager.startDev(onLog: (line) {
          if (line.contains('모델 로딩') && mounted) _setStepRunning(2);
        });
      }
      _setStepDone(0);

      // Step 1: 서버 응답 대기
      _setStepRunning(1);
      processManager.port = widget.port;
      final ready = await processManager.waitUntilReady(
        timeoutSeconds: 60,
        onStatus: (s) { if (mounted) setState(() {}); },
      );
      if (!ready) throw Exception('서버 시작 실패 (60초 초과)');
      _setStepDone(1);

      // Step 2: 모델 로딩 (모델 경로가 있을 때만)
      _setStepRunning(2);
      if (widget.modelPath.isNotEmpty) {
        await api.loadModel(
          modelPath: widget.modelPath,
          precision: widget.precision,
          vramOptimization: widget.vramOptimization,
          cpuOffload: widget.cpuOffload,
        );
      }
      _setStepDone(2);

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  void _setStepRunning(int i) => setState(() {
        _steps[i].state = _StepState.running;
      });

  void _setStepDone(int i) => setState(() => _steps[i].state = _StepState.done);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SD Local 시작 중',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ..._steps.asMap().entries.map((e) => _buildStep(e.value)),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const StartupScreen()),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                  child: const Text('돌아가기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(_Step step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: switch (step.state) {
              _StepState.pending => const Icon(Icons.circle_outlined,
                  color: Colors.white24, size: 18),
              _StepState.running => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.blueAccent)),
              _StepState.done => const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 18),
            },
          ),
          const SizedBox(width: 12),
          Text(
            step.label,
            style: TextStyle(
              color: step.state == _StepState.pending
                  ? Colors.white38
                  : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { pending, running, done }

class _Step {
  final String label;
  _StepState state = _StepState.pending;
  _Step(this.label);
}
