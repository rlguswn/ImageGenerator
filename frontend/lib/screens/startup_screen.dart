import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_paths.dart';
import 'splash_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _portController = TextEditingController(text: '8000');
  String _selectedModel = '';
  String _precision = 'fp16';
  bool _vramOptimization = false;
  bool _cpuOffload = false;
  List<String> _models = [];

  int _countdown = 10;
  bool _autoStart = true;
  Timer? _timer;
  bool _portAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
    _checkPort(int.tryParse(_portController.text) ?? 8000); // 초기 포트 상태 확인
    _startCountdown();
    _portController.addListener(_onPortChanged);
  }

  Future<void> _loadModels() async {
    try {
      final root = findProjectRoot();
      final sep = Platform.pathSeparator;
      final dir = Directory('$root${sep}models${sep}base');
      if (await dir.exists()) {
        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.safetensors') || f.path.endsWith('.ckpt'))
            .map((f) => f.uri.pathSegments.last)
            .toList();
        if (mounted) {
          setState(() {
            _models = files;
            if (files.isNotEmpty) _selectedModel = files.first;
          });
        }
      }
    } catch (_) {}
  }

  void _onPortChanged() {
    _stopCountdown();
    final port = int.tryParse(_portController.text) ?? 8000;
    _checkPort(port);
  }

  Future<void> _checkPort(int port) async {
    try {
      final socket = await ServerSocket.bind('127.0.0.1', port);
      await socket.close();
      if (mounted) setState(() => _portAvailable = true);
    } catch (_) {
      if (mounted) setState(() => _portAvailable = false);
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _launch();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _stopCountdown() {
    if (_autoStart) {
      _timer?.cancel();
      setState(() => _autoStart = false);
    }
  }

  void _launch() {
    final port = int.tryParse(_portController.text) ?? 8000;
    api.setPort(port);
    final sep = Platform.pathSeparator;
    final modelPath = _selectedModel.isEmpty
        ? ''
        : '${findProjectRoot()}${sep}models${sep}base$sep$_selectedModel';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SplashScreen(
          modelPath: modelPath,
          port: port,
          precision: _precision,
          vramOptimization: _vramOptimization,
          cpuOffload: _cpuOffload,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Container(
          width: 480,
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
                'SD Local',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Stable Diffusion 로컬 이미지 생성',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // 포트
              _label('포트 번호'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _stopCountdown,
                      child: TextField(
                        controller: _portController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          suffix: _portAvailable
                              ? const Text('✓ 사용가능',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 12))
                              : const Text('✗ 사용중',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 베이스 모델
              _label('베이스 모델'),
              GestureDetector(
                onTap: _stopCountdown,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedModel.isEmpty ? null : _selectedModel,
                  dropdownColor: const Color(0xFF0F3460),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(),
                  hint: const Text('모델 없음 (models/base/ 에 추가)',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  items: _models
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    _stopCountdown();
                    setState(() => _selectedModel = v ?? '');
                  },
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '※ 사용 전 모델의 라이선스를 확인하세요 (CivitAI · Hugging Face 모델 페이지)',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
              const SizedBox(height: 12),

              // 정밀도
              _label('정밀도'),
              GestureDetector(
                onTap: _stopCountdown,
                child: DropdownButtonFormField<String>(
                  initialValue: _precision,
                  dropdownColor: const Color(0xFF0F3460),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(),
                  items: ['fp16', 'fp32']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    _stopCountdown();
                    setState(() => _precision = v!);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 토글
              _toggleRow('VRAM 최적화', _vramOptimization, (v) {
                _stopCountdown();
                setState(() => _vramOptimization = v);
              }),
              _toggleRow('CPU 오프로드', _cpuOffload, (v) {
                _stopCountdown();
                setState(() => _cpuOffload = v);
              }),

              const SizedBox(height: 28),

              if (_autoStart) ...[
                Text(
                  '$_countdown초 후 자동 시작...',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (10 - _countdown) / 10,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF0F3460)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _launch,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('지금 시작'),
                  ),
                ),
              ] else ...[
                const Text(
                  '설정을 변경했습니다.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _launch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3460),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('시작', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  InputDecoration _inputDecoration({Widget? suffix}) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF0F3460),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix) : null,
        suffixIconConstraints: const BoxConstraints(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF0F3460),
          ),
        ],
      ),
    );
  }
}
