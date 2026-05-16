import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/dev_mode.dart';
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

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _restoreLastPrompt =
        SessionStorage.loadPrefs()['restore_last_prompt'] as bool? ?? false;
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
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
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
          const SizedBox(height: 24),

          _section('모델'),
          _textField('베이스 모델 경로', _baseModelPathCtrl,
              hint: 'models/base/'),
          _textField('LoRA 경로', _loraPathCtrl, hint: 'models/lora/'),
          _textField('VAE 경로', _vaePathCtrl,
              hint: '(비워두면 자동)'),
          const SizedBox(height: 24),

          _section('출력'),
          _textField('이미지 저장 경로', _outputPathCtrl, hint: 'output/'),
          const SizedBox(height: 24),

          _section('개발자'),
          ValueListenableBuilder<bool>(
            valueListenable: devModeNotifier,
            builder: (_, value, __) => _toggleRow(
              '개발자 모드',
              value,
              (v) => devModeNotifier.value = v,
            ),
          ),
          const SizedBox(height: 24),

          _section('로그'),
          _label('보관 기간'),
          DropdownButtonFormField<int>(
            value: _retentionDays,
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
            value: _maxFileSizeMb,
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
              activeColor: Colors.blueAccent,
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
