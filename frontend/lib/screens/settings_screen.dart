import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/app_paths.dart';
import '../services/dev_mode.dart';
import '../services/process_manager.dart';
import '../services/session_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _config = {};
  bool _loaded = false;

  final _portCtrl = TextEditingController();
  final _baseModelPathCtrl = TextEditingController();
  final _loraPathCtrl = TextEditingController();
  final _vaePathCtrl = TextEditingController();
  final _outputPathCtrl = TextEditingController();
  bool _autoPortSearch = true;

  int _retentionDays = 60;
  int _maxFileSizeMb = 10;
  bool _restoreLastPrompt = false;

  // 모델 교체
  List<String> _availableModels = [];
  String _currentModelPath = '';
  String _selectedModel = '';
  String _swapPrecision = 'fp16';
  bool _swapVram = false;
  bool _swapCpu = false;
  bool _swapping = false;
  bool _restarting = false;
  String _restartStatus = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _restoreLastPrompt =
        SessionStorage.loadPrefs()['restore_last_prompt'] as bool? ?? false;
    _loadModelInfo();
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _baseModelPathCtrl.dispose();
    _loraPathCtrl.dispose();
    _vaePathCtrl.dispose();
    _outputPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await api.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _portCtrl.text = (config['server']?['port'] ?? 8000).toString();
        _autoPortSearch = config['server']?['auto_port_search'] ?? true;
        _baseModelPathCtrl.text = config['model']?['base_model_path'] ?? 'models/base/';
        _loraPathCtrl.text = config['model']?['lora_path'] ?? 'models/lora/';
        _vaePathCtrl.text = config['model']?['vae_path'] ?? '';
        _outputPathCtrl.text = config['output']?['output_path'] ?? 'output/';
        _retentionDays = config['log']?['retention_days'] ?? 60;
        _maxFileSizeMb = config['log']?['max_file_size_mb'] ?? 10;
        _loaded = true;
      });
      _scanModels(config['model']?['base_model_path'] ?? 'models/base/');
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _loadModelInfo() async {
    try {
      final h = await api.health();
      if (!mounted) return;
      final path = h['model_path'] as String? ?? '';
      setState(() {
        _currentModelPath = path;
        if (_selectedModel.isEmpty && path.isNotEmpty) {
          _selectedModel = path.split(Platform.pathSeparator).last;
        }
      });
    } catch (_) {}
  }

  void _scanModels(String basePath) {
    try {
      final root = findProjectRoot();
      final sep = Platform.pathSeparator;
      final resolved = basePath.startsWith('/') || basePath.contains(':')
          ? basePath
          : '$root$sep$basePath';
      final dir = Directory(resolved);
      if (!dir.existsSync()) return;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.safetensors') || f.path.endsWith('.ckpt'))
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _availableModels = files;
        if (_selectedModel.isEmpty && files.isNotEmpty) {
          _selectedModel = files.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _restartBackend() async {
    if (_restarting) return;
    setState(() {
      _restarting = true;
      _restartStatus = '백엔드 종료 중...';
    });

    try {
      processManager.stop();
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() => _restartStatus = '백엔드 시작 중...');

      if (devModeNotifier.value) {
        await processManager.startDev(
          onLog: (line) {
            if (mounted) setState(() => _restartStatus = line);
          },
        );
      } else {
        await processManager.start(
          onLog: (line) {
            if (mounted) setState(() => _restartStatus = line);
          },
        );
      }

      setState(() => _restartStatus = '서버 응답 대기 중...');
      final ok = await processManager.waitUntilReady(
        timeoutSeconds: 60,
        onStatus: (s) {
          if (mounted) setState(() => _restartStatus = s);
        },
      );

      if (!mounted) return;
      if (ok) {
        setState(() => _restartStatus = '재시작 완료');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('백엔드가 재시작됐습니다')),
        );
      } else {
        setState(() => _restartStatus = '시작 실패 (타임아웃)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('백엔드 응답 없음 — 로그를 확인하세요')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _restartStatus = '오류: $e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('재시작 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  Future<void> _swapModel() async {
    if (_selectedModel.isEmpty || _swapping) return;

    final root = findProjectRoot();
    final sep = Platform.pathSeparator;
    final base = _baseModelPathCtrl.text;
    final resolved = base.startsWith('/') || base.contains(':')
        ? base
        : '$root$sep$base';
    final modelPath = '$resolved$_selectedModel';

    // 이미 로드된 모델이면 스킵
    if (_currentModelPath == modelPath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 로드된 모델입니다')),
      );
      return;
    }

    setState(() => _swapping = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.loadModel(
        modelPath: modelPath,
        precision: _swapPrecision,
        vramOptimization: _swapVram,
        cpuOffload: _swapCpu,
      );
      if (!mounted) return;
      setState(() => _currentModelPath = modelPath);
      messenger.showSnackBar(
        SnackBar(content: Text('모델 교체 완료: $_selectedModel')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('교체 실패: $e')));
    } finally {
      if (mounted) setState(() => _swapping = false);
    }
  }

  Future<void> _save() async {
    final config = {
      'server': {
        'port': int.tryParse(_portCtrl.text) ?? 8000,
        'auto_port_search': _autoPortSearch,
      },
      'model': {
        'base_model_path': _baseModelPathCtrl.text,
        'lora_path': _loraPathCtrl.text,
        'vae_path': _vaePathCtrl.text,
      },
      'output': {
        'output_path': _outputPathCtrl.text,
      },
      'log': {
        'retention_days': _retentionDays,
        'max_file_size_mb': _maxFileSizeMb,
      },
    };
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.saveConfig(config);
      messenger.showSnackBar(
          const SnackBar(content: Text('설정이 저장되었습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  Future<void> _exportConfig() async {
    final dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'config 저장 위치 선택');
    if (dir == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = '$dir${Platform.pathSeparator}config_export.json';
      File(path).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(_config));
      messenger.showSnackBar(SnackBar(content: Text('내보내기 완료: $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }

  Future<void> _importConfig() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'config 파일 선택',
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final content =
          File(result.files.single.path!).readAsStringSync();
      final config = jsonDecode(content) as Map<String, dynamic>;
      await api.saveConfig(config);
      await _loadConfig();
      messenger.showSnackBar(const SnackBar(content: Text('가져오기 완료')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('설정', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white54, size: 20),
            tooltip: 'config 가져오기',
            onPressed: _importConfig,
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white54, size: 20),
            tooltip: 'config 내보내기',
            onPressed: _exportConfig,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('저장', style: TextStyle(color: Colors.blueAccent)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section('일반'),
          _toggleRow(
            '마지막 프롬프트 불러오기',
            _restoreLastPrompt,
            (v) {
              setState(() => _restoreLastPrompt = v);
              SessionStorage.savePrefs({'restore_last_prompt': v});
            },
          ),
          const SizedBox(height: 24),

          _section('서버'),
          _textField('포트 번호', _portCtrl, hint: '8000'),
          _toggleRow('자동 포트 탐색', _autoPortSearch,
              (v) => setState(() => _autoPortSearch = v)),
          const SizedBox(height: 12),
          _buildRestartSection(),
          const SizedBox(height: 24),

          // ── 모델 교체 ──────────────────────────────────────────────
          _section('모델 교체'),
          _buildModelSwapSection(),
          const SizedBox(height: 24),

          _section('모델 경로'),
          _textField('베이스 모델 경로', _baseModelPathCtrl, hint: 'models/base/'),
          _textField('LoRA 경로', _loraPathCtrl, hint: 'models/lora/'),
          _textField('VAE 경로', _vaePathCtrl, hint: '(비워두면 자동)'),
          const SizedBox(height: 24),

          _section('출력'),
          _textField('이미지 저장 경로', _outputPathCtrl, hint: 'output/'),
          const SizedBox(height: 24),

          _section('개발자'),
          ValueListenableBuilder<bool>(
            valueListenable: devModeNotifier,
            builder: (context, value, child) => _toggleRow(
              '개발자 모드',
              value,
              (v) => devModeNotifier.value = v,
            ),
          ),
          const SizedBox(height: 24),

          _section('로그'),
          _label('보관 기간'),
          DropdownButtonFormField<int>(
            initialValue: _retentionDays,
            dropdownColor: const Color(0xFF0F3460),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco(),
            items: [30, 60, 90, 180, -1]
                .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d == -1 ? '무제한' : '$d일')))
                .toList(),
            onChanged: (v) => setState(() => _retentionDays = v!),
          ),
          const SizedBox(height: 12),
          _label('파일 최대 크기 (MB)'),
          DropdownButtonFormField<int>(
            initialValue: _maxFileSizeMb,
            dropdownColor: const Color(0xFF0F3460),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco(),
            items: [5, 10, 20, 50, 100]
                .map((s) => DropdownMenuItem(
                    value: s, child: Text('${s}MB')))
                .toList(),
            onChanged: (v) => setState(() => _maxFileSizeMb = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSwapSection() {
    final currentName = _currentModelPath.isNotEmpty
        ? _currentModelPath.split(Platform.pathSeparator).last
        : '없음';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재 모델
          Row(
            children: [
              const Icon(Icons.memory, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              const Text('현재 로드됨:',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentName,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 모델 선택 드롭다운
          _label('교체할 모델'),
          _availableModels.isEmpty
              ? const Text(
                  'models/base/ 폴더에 모델 파일이 없습니다',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _availableModels.contains(_selectedModel)
                      ? _selectedModel
                      : null,
                  dropdownColor: const Color(0xFF0F3460),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco(hint: '모델 선택'),
                  items: _availableModels
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: _swapping
                      ? null
                      : (v) => setState(() => _selectedModel = v ?? ''),
                ),
          const SizedBox(height: 12),

          // 정밀도 + 옵션
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('정밀도'),
                    DropdownButtonFormField<String>(
                      initialValue: _swapPrecision,
                      dropdownColor: const Color(0xFF0F3460),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(),
                      items: ['fp16', 'fp32', 'bf16']
                          .map((p) =>
                              DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: _swapping
                          ? null
                          : (v) => setState(() => _swapPrecision = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _miniToggle('VRAM 최적화', _swapVram,
                      (v) => setState(() => _swapVram = v)),
                  const SizedBox(height: 4),
                  _miniToggle('CPU 오프로드', _swapCpu,
                      (v) => setState(() => _swapCpu = v)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 교체 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_swapping || _availableModels.isEmpty)
                  ? null
                  : _swapModel,
              icon: _swapping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.swap_horiz, size: 18),
              label: Text(_swapping ? '로딩 중...' : '모델 교체'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blueAccent.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestartSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('백엔드 재시작',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                if (_restarting && _restartStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _restartStatus,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _restarting ? null : _restartBackend,
            icon: _restarting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.restart_alt, size: 16),
            label: Text(_restarting ? '재시작 중...' : '재시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFF0F3460).withValues(alpha: 0.4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniToggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.blueAccent,
            ),
          ),
        ],
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  Widget _textField(String label, TextEditingController ctrl, {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco(hint: hint),
            ),
          ],
        ),
      );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.blueAccent,
            ),
          ],
        ),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF0F3460),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
