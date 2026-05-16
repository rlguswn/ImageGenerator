import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/generation_service.dart';
import '../services/regen_request.dart';
import '../services/session_storage.dart';

class Txt2ImgScreen extends StatefulWidget {
  const Txt2ImgScreen({super.key});

  @override
  State<Txt2ImgScreen> createState() => _Txt2ImgScreenState();
}

class _Txt2ImgScreenState extends State<Txt2ImgScreen>
    with SingleTickerProviderStateMixin {
  static Map<String, dynamic>? _savedState;
  static final List<String> _promptHistory = [];

  late TabController _tabController;

  final _promptCtrl = TextEditingController();
  final _negativeCtrl = TextEditingController();

  String _resolution = '512x512';
  double _steps = 20;
  double _cfgScale = 7.0;
  final _seedCtrl = TextEditingController(text: '-1');

  String _sampler = 'DPM++ 2M Karras';
  final _batchSizeCtrl = TextEditingController(text: '1');
  double _clipSkip = 1;

  List<String> _loraList = [];
  Map<String, double> _selectedLoras = {};

  List<Map<String, dynamic>> _presets = [];
  String? _selectedPresetId;

  bool _modelLoaded = false;

  List<Uint8List> _images = [];
  String _generationTime = '';
  int _lastSeed = -1;

  static const _resolutions = [
    '512x512', '512x768', '768x512', '768x768',
    '512x1024', '1024x512', '1024x1024',
  ];

  static const _samplers = ['DPM++ 2M Karras', 'DPM++ 2M'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _restoreState();
    _loadPresets();
    _loadLoras();
    _checkModelLoaded();
    genService.notifier.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = regenNotifier.value;
      if (pending != null && pending.mode == 'txt2img') {
        _applyRegenState(pending.state);
        regenNotifier.value = null;
      }
      final s = genService.state;
      if (s.isDone && s.mode == 'txt2img') _applyServiceResult(s);
    });
    regenNotifier.addListener(_onRegenRequest);
  }

  void _restoreState() {
    final s = _savedState;
    if (s == null) {
      final prefs = SessionStorage.loadPrefs();
      if (prefs['restore_last_prompt'] == true) {
        final session = SessionStorage.loadSession();
        final last = session['txt2img'] as Map?;
        if (last != null) {
          _promptCtrl.text = last['prompt'] as String? ?? '';
          _negativeCtrl.text = last['negative'] as String? ?? '';
        }
      }
      return;
    }
    _promptCtrl.text = s['prompt'] ?? '';
    _negativeCtrl.text = s['negative'] ?? '';
    _resolution = s['resolution'] ?? '512x512';
    _steps = (s['steps'] ?? 20.0) as double;
    _cfgScale = (s['cfg'] ?? 7.0) as double;
    _seedCtrl.text = s['seed'] ?? '-1';
    _sampler = s['sampler'] ?? 'DPM++ 2M Karras';
    _batchSizeCtrl.text = s['batchSize']?.toString() ?? '1';
    _clipSkip = (s['clipSkip'] ?? 1.0) as double;
    _selectedLoras = Map<String, double>.from(s['selectedLoras'] ?? {});
    _loraList = List<String>.from(s['loraList'] ?? []);
    _images = List<Uint8List>.from(s['images'] ?? []);
    _generationTime = s['generationTime'] ?? '';
    _lastSeed = s['lastSeed'] ?? -1;
  }

  void _onServiceChanged() {
    final s = genService.state;
    if (s.mode != 'txt2img') return;
    if (s.isDone) {
      if (mounted) _applyServiceResult(s);
    } else if (s.isError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: ${s.errorMessage}')),
        );
      }
    }
  }

  void _applyServiceResult(GenState s) {
    setState(() {
      _images = List<Uint8List>.from(s.images);
      _lastSeed = s.lastSeed;
      _generationTime = s.generationTime;
    });
  }

  void _onRegenRequest() {
    final payload = regenNotifier.value;
    if (payload == null || payload.mode != 'txt2img') return;
    _applyRegenState(payload.state);
    regenNotifier.value = null;
  }

  void _applyRegenState(Map<String, dynamic> s) {
    setState(() {
      _promptCtrl.text = s['prompt'] as String? ?? '';
      _negativeCtrl.text = s['negative'] as String? ?? '';
      _resolution = s['resolution'] as String? ?? '512x512';
      _steps = (s['steps'] as num?)?.toDouble() ?? 20;
      _cfgScale = (s['cfgScale'] as num?)?.toDouble() ?? 7.0;
      _seedCtrl.text = s['seed'] as String? ?? '-1';
      _sampler = s['sampler'] as String? ?? 'DPM++ 2M Karras';
      _clipSkip = (s['clipSkip'] as num?)?.toDouble() ?? 1;
    });
  }

  @override
  void dispose() {
    genService.notifier.removeListener(_onServiceChanged);
    regenNotifier.removeListener(_onRegenRequest);
    _savedState = {
      'prompt': _promptCtrl.text,
      'negative': _negativeCtrl.text,
      'resolution': _resolution,
      'steps': _steps,
      'cfg': _cfgScale,
      'seed': _seedCtrl.text,
      'sampler': _sampler,
      'batchSize': _batchSizeCtrl.text,
      'clipSkip': _clipSkip,
      'selectedLoras': Map<String, double>.from(_selectedLoras),
      'loraList': List<String>.from(_loraList),
      'images': List<Uint8List>.from(_images),
      'generationTime': _generationTime,
      'lastSeed': _lastSeed,
    };
    _tabController.dispose();
    _promptCtrl.dispose();
    _negativeCtrl.dispose();
    _seedCtrl.dispose();
    _batchSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await api.getPresets();
      if (mounted) setState(() => _presets = presets);
    } catch (_) {}
  }

  Future<void> _loadLoras() async {
    try {
      final loras = await api.getLoraList();
      if (mounted) {
        setState(() {
          _loraList = loras;
          _selectedLoras.removeWhere((k, _) => !loras.contains(k));
        });
      }
    } catch (_) {}
  }

  Future<void> _checkModelLoaded() async {
    try {
      final h = await api.health();
      if (mounted) setState(() => _modelLoaded = h['model_loaded'] as bool? ?? false);
    } catch (_) {}
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _promptCtrl.text = preset['prompt'] ?? '';
      _negativeCtrl.text = preset['negative_prompt'] ?? '';
      final s = preset['settings'] ?? {};
      final w = s['width'] ?? 512;
      final h = s['height'] ?? 512;
      _resolution = '${w}x$h';
      _steps = (s['steps'] ?? 20).toDouble();
      _cfgScale = (s['cfg_scale'] ?? 7.0).toDouble();
      _seedCtrl.text = (s['seed'] ?? -1).toString();
      _sampler = s['sampler'] ?? 'DPM++ 2M Karras';
      _clipSkip = (s['clip_skip'] ?? 1).toDouble();
    });
  }

  Future<void> _savePreset() async {
    final name = await _showTextDialog('프리셋 이름');
    if (name == null || name.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final wh = _resolution.split('x');
    try {
      await api.savePreset({
        'name': name,
        'mode': 'txt2img',
        'prompt': _promptCtrl.text,
        'negative_prompt': _negativeCtrl.text,
        'settings': {
          'width': int.parse(wh[0]),
          'height': int.parse(wh[1]),
          'steps': _steps.toInt(),
          'cfg_scale': _cfgScale,
          'sampler': _sampler,
          'seed': int.tryParse(_seedCtrl.text) ?? -1,
          'clip_skip': _clipSkip.toInt(),
        },
        'lora': _selectedLoras.entries
            .map((e) => {'name': e.key, 'weight': e.value})
            .toList(),
      });
      await _loadPresets();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('프리셋 저장 실패: $e')));
    }
  }

  Future<void> _generate() async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('로드된 모델이 없습니다. 설정 탭에서 모델을 선택해 주세요.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    SessionStorage.saveSession('txt2img', _promptCtrl.text, _negativeCtrl.text);
    final wh = _resolution.split('x');
    final loras = _selectedLoras.entries
        .map((e) => {'name': e.key, 'weight': e.value})
        .toList();

    final prompt = _promptCtrl.text;
    if (prompt.isNotEmpty) {
      _promptHistory.remove(prompt);
      _promptHistory.insert(0, prompt);
      if (_promptHistory.length > 20) _promptHistory.removeLast();
    }

    await genService.run(
      mode: 'txt2img',
      apiCall: () => api.txt2img({
        'prompt': prompt,
        'negative_prompt': _negativeCtrl.text,
        'width': int.parse(wh[0]),
        'height': int.parse(wh[1]),
        'steps': _steps.toInt(),
        'cfg_scale': _cfgScale,
        'seed': int.tryParse(_seedCtrl.text) ?? -1,
        'batch_size': int.tryParse(_batchSizeCtrl.text) ?? 1,
        'clip_skip': _clipSkip.toInt(),
        'sampler': _sampler,
        'loras': loras,
      }),
    );
  }

  Future<void> _showHistoryDialog() async {
    if (_promptHistory.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('프롬프트 히스토리',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 480,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _promptHistory.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Colors.white12, height: 1),
            itemBuilder: (_, i) => ListTile(
              dense: true,
              title: Text(
                _promptHistory[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, _promptHistory[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _promptHistory.clear();
              Navigator.pop(ctx);
            },
            child: const Text('전체 삭제',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기')),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _promptCtrl.text = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('txt2img', style: TextStyle(color: Colors.white)),
        actions: [
          if (_presets.isNotEmpty)
            DropdownButton<String>(
              value: _selectedPresetId,
              dropdownColor: const Color(0xFF0F3460),
              style: const TextStyle(color: Colors.white),
              hint: const Text('프리셋 선택',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              underline: const SizedBox(),
              items: _presets
                  .map((p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] ?? '')))
                  .toList(),
              onChanged: (id) {
                setState(() => _selectedPresetId = id);
                final preset = _presets.firstWhere((p) => p['id'] == id);
                _applyPreset(preset);
              },
            ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.white70),
            tooltip: '프리셋 저장',
            onPressed: _savePreset,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 380,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF16213E),
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blueAccent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    tabs: const [
                      Tab(text: '기본'),
                      Tab(text: '고급'),
                      Tab(text: 'LoRA'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBasicTab(),
                        _buildAdvancedTab(),
                        _buildLoraTab(),
                      ],
                    ),
                  ),
                  _buildGenerateButton(),
                ],
              ),
            ),
          ),
          Expanded(child: _buildOutputArea()),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Prompt',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            if (_promptHistory.isNotEmpty)
              GestureDetector(
                onTap: _showHistoryDialog,
                child: const Row(
                  children: [
                    Icon(Icons.history, size: 14, color: Colors.white38),
                    SizedBox(width: 4),
                    Text('히스토리',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _promptCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 12),
        _label('Negative Prompt'),
        TextField(
          controller: _negativeCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 12),
        _label('해상도'),
        DropdownButtonFormField<String>(
          initialValue: _resolution,
          dropdownColor: const Color(0xFF0F3460),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco(),
          items: _resolutions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) => setState(() => _resolution = v!),
        ),
        const SizedBox(height: 12),
        _sliderRow('Steps', _steps, 1, 150, (v) => setState(() => _steps = v)),
        _sliderRow('CFG Scale', _cfgScale, 1, 30,
            (v) => setState(() => _cfgScale = v), divisions: 58),
        _label('Seed'),
        TextField(
          controller: _seedCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco(
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.replay,
                      color: _lastSeed != -1
                          ? Colors.blueAccent
                          : Colors.white12,
                      size: 18),
                  tooltip: _lastSeed != -1
                      ? 'seed 재사용: $_lastSeed'
                      : '이전 seed 없음',
                  onPressed: _lastSeed != -1
                      ? () =>
                          setState(() => _seedCtrl.text = _lastSeed.toString())
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.shuffle,
                      color: Colors.white54, size: 18),
                  onPressed: () => setState(() => _seedCtrl.text = '-1'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Sampler'),
        DropdownButtonFormField<String>(
          initialValue: _sampler,
          dropdownColor: const Color(0xFF0F3460),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco(),
          items: _samplers
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _sampler = v!),
        ),
        const SizedBox(height: 12),
        _intInputRow('Batch Size', _batchSizeCtrl, min: 1),
        _sliderRow('Clip Skip', _clipSkip, 1, 4,
            (v) => setState(() => _clipSkip = v), isInt: true),
      ],
    );
  }

  Widget _buildLoraTab() {
    if (_loraList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_outlined,
                color: Colors.white24, size: 40),
            const SizedBox(height: 12),
            const Text('LoRA 없음',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('models/lora/ 에 .safetensors 파일 추가 후',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
              ),
              onPressed: _loadLoras,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _loraList.length,
            itemBuilder: (_, i) {
              final name = _loraList[i];
              final weight = _selectedLoras[name];
              final isOn = weight != null;
              return Column(
                children: [
                  SwitchListTile(
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    value: isOn,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (v) => setState(() {
                      if (v) {
                        _selectedLoras[name] = 0.8;
                      } else {
                        _selectedLoras.remove(name);
                      }
                    }),
                  ),
                  if (isOn)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Text('가중치',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blueAccent,
                                thumbColor: Colors.blueAccent,
                                inactiveTrackColor: Colors.white12,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: weight,
                                min: 0,
                                max: 1,
                                divisions: 20,
                                onChanged: (v) => setState(
                                    () => _selectedLoras[name] = v),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              weight.toStringAsFixed(2),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(color: Colors.white12, height: 1),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${_selectedLoras.length}개 선택됨',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('새로고침',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white38),
                onPressed: _loadLoras,
              ),
              if (_selectedLoras.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedLoras.clear()),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent),
                  child: const Text('전체 해제',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<GenState>(
        valueListenable: genService.notifier,
        builder: (context, s, _) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: s.isActive ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    s.isActive ? Colors.white12 : const Color(0xFF0F3460),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.isActive ? '생성 중...' : '생성',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutputArea() {
    if (_images.isEmpty) {
      return const Center(
        child: Text('생성된 이미지가 없습니다',
            style: TextStyle(color: Colors.white24, fontSize: 14)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _generationTime.isNotEmpty
                      ? '생성 완료 · $_generationTime · seed: $_lastSeed'
                        '${_images.length > 1 ? ' · ${_images.length}장' : ''}'
                      : '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                tooltip: '결과 지우기',
                onPressed: () {
                  setState(() {
                    _images = [];
                    _lastSeed = -1;
                    _generationTime = '';
                  });
                  genService.reset();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _images.length == 1
              ? Center(
                  child: Image.memory(_images.first, fit: BoxFit.contain))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _images.length,
                  itemBuilder: (_, i) =>
                      Image.memory(_images[i], fit: BoxFit.cover),
                ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  InputDecoration _inputDeco({Widget? suffix}) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF0F3460),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {bool isInt = false, int? divisions}) {
    final display =
        isInt ? value.toInt().toString() : value.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              Text(display,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0F3460),
              thumbColor: Colors.blueAccent,
              inactiveTrackColor: Colors.white12,
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _intInputRow(String label, TextEditingController ctrl,
      {int min = 1, int sliderMax = 16}) {
    final current = (int.tryParse(ctrl.text) ?? min).clamp(min, 9999);
    final sliderVal = current.clamp(min, sliderMax).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(
                width: 64,
                height: 32,
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n < min) {
                      ctrl.text = min.toString();
                    }
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0F3460),
              thumbColor: Colors.blueAccent,
              inactiveTrackColor: Colors.white12,
              trackHeight: 3,
            ),
            child: Slider(
              value: sliderVal,
              min: min.toDouble(),
              max: sliderMax.toDouble(),
              divisions: sliderMax - min,
              onChanged: (v) {
                ctrl.text = v.toInt().toString();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTextDialog(String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(hint, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('확인')),
        ],
      ),
    );
  }
}
