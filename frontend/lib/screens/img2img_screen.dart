import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/generation_service.dart';
import '../services/regen_request.dart';
import '../services/session_storage.dart';
import '../widgets/compare_slider.dart';

class Img2ImgScreen extends StatefulWidget {
  const Img2ImgScreen({super.key});

  @override
  State<Img2ImgScreen> createState() => _Img2ImgScreenState();
}

class _Img2ImgScreenState extends State<Img2ImgScreen>
    with SingleTickerProviderStateMixin {
  static Map<String, dynamic>? _savedState;
  static final List<String> _promptHistory = [];

  late TabController _tabController;

  final _promptCtrl = TextEditingController();
  final _negativeCtrl = TextEditingController();
  final _seedCtrl = TextEditingController(text: '-1');
  final _batchSizeCtrl = TextEditingController(text: '1');

  String _resolution = '512x512';
  double _steps = 20;
  double _cfgScale = 7.0;
  String _sampler = 'DPM++ 2M Karras';
  double _clipSkip = 1;
  double _denoisingStrength = 0.75;

  bool _modelLoaded = false;

  Uint8List? _inputImage;
  List<Uint8List> _outputImages = [];
  String _generationTime = '';
  int _lastSeed = -1;

  List<String> _loraList = [];
  Map<String, double> _selectedLoras = {};
  String _viewMode = 'result';

  static const _resolutions = [
    '512x512', '512x768', '768x512', '768x768', '512x1024', '1024x512',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _restoreState();
    _loadLoras();
    _checkModelLoaded();
    genService.notifier.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = regenNotifier.value;
      if (pending != null && pending.mode == 'img2img') {
        _applyRegenState(pending.state);
        regenNotifier.value = null;
      }
      final s = genService.state;
      if (s.isDone && s.mode == 'img2img') _applyServiceResult(s);
    });
    regenNotifier.addListener(_onRegenRequest);
  }

  void _onServiceChanged() {
    final s = genService.state;
    if (s.mode != 'img2img') return;
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
      _outputImages = List<Uint8List>.from(s.images);
      _lastSeed = s.lastSeed;
      _generationTime = s.generationTime;
      _viewMode = 'result';
    });
  }

  void _onRegenRequest() {
    final payload = regenNotifier.value;
    if (payload == null || payload.mode != 'img2img') return;
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
      _batchSizeCtrl.text = s['batchSize'] as String? ?? '1';
      _denoisingStrength =
          (s['denoisingStrength'] as num?)?.toDouble() ?? 0.75;
    });
  }

  void _restoreState() {
    final s = _savedState;
    if (s == null) {
      final prefs = SessionStorage.loadPrefs();
      if (prefs['restore_last_prompt'] == true) {
        final session = SessionStorage.loadSession();
        final last = session['img2img'] as Map?;
        if (last != null) {
          _promptCtrl.text = last['prompt'] as String? ?? '';
          _negativeCtrl.text = last['negative'] as String? ?? '';
        }
      }
      return;
    }
    _promptCtrl.text = s['prompt'] as String? ?? '';
    _negativeCtrl.text = s['negative'] as String? ?? '';
    _seedCtrl.text = s['seed'] as String? ?? '-1';
    _resolution = s['resolution'] as String? ?? '512x512';
    _steps = (s['steps'] as num?)?.toDouble() ?? 20;
    _cfgScale = (s['cfgScale'] as num?)?.toDouble() ?? 7.0;
    _sampler = s['sampler'] as String? ?? 'DPM++ 2M Karras';
    _clipSkip = (s['clipSkip'] as num?)?.toDouble() ?? 1;
    _denoisingStrength =
        (s['denoisingStrength'] as num?)?.toDouble() ?? 0.75;
    _loraList = List<String>.from(s['loraList'] as List? ?? []);
    _selectedLoras =
        Map<String, double>.from(s['selectedLoras'] as Map? ?? {});
    _inputImage = s['inputImage'] as Uint8List?;
    _outputImages =
        List<Uint8List>.from(s['outputImages'] as List? ?? []);
    _generationTime = s['generationTime'] as String? ?? '';
    _lastSeed = s['lastSeed'] as int? ?? -1;
    _viewMode = s['viewMode'] as String? ?? 'result';
  }

  @override
  void dispose() {
    genService.notifier.removeListener(_onServiceChanged);
    regenNotifier.removeListener(_onRegenRequest);
    _savedState = {
      'prompt': _promptCtrl.text,
      'negative': _negativeCtrl.text,
      'seed': _seedCtrl.text,
      'resolution': _resolution,
      'steps': _steps,
      'cfgScale': _cfgScale,
      'sampler': _sampler,
      'clipSkip': _clipSkip,
      'denoisingStrength': _denoisingStrength,
      'batchSize': _batchSizeCtrl.text,
      'loraList': _loraList,
      'selectedLoras': Map<String, double>.from(_selectedLoras),
      'inputImage': _inputImage,
      'outputImages': List<Uint8List>.from(_outputImages),
      'generationTime': _generationTime,
      'lastSeed': _lastSeed,
      'viewMode': _viewMode,
    };
    _tabController.dispose();
    _promptCtrl.dispose();
    _negativeCtrl.dispose();
    _seedCtrl.dispose();
    _batchSizeCtrl.dispose();
    super.dispose();
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
              title: Text(_promptHistory[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
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

  Future<void> _loadLoras() async {
    try {
      final list = await api.getLoraList();
      if (!mounted) return;
      setState(() {
        _loraList = list;
        _selectedLoras.removeWhere((k, _) => !list.contains(k));
      });
    } catch (_) {}
  }

  Future<void> _checkModelLoaded() async {
    try {
      final h = await api.health();
      if (mounted) setState(() => _modelLoaded = h['model_loaded'] as bool? ?? false);
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: '이미지 선택',
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      if (mounted) {
        setState(() {
          _inputImage = bytes;
          _viewMode = 'result';
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일 읽기 실패: $e')));
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
    SessionStorage.saveSession('img2img', _promptCtrl.text, _negativeCtrl.text);
    if (_inputImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('입력 이미지를 선택하세요')));
      return;
    }

    final prompt = _promptCtrl.text;
    if (prompt.isNotEmpty) {
      _promptHistory.remove(prompt);
      _promptHistory.insert(0, prompt);
      if (_promptHistory.length > 20) _promptHistory.removeLast();
    }

    final wh = _resolution.split('x');
    final loras = _selectedLoras.entries
        .map((e) => {'name': e.key, 'weight': e.value})
        .toList();

    await genService.run(
      mode: 'img2img',
      apiCall: () => api.img2img({
        'prompt': prompt,
        'negative_prompt': _negativeCtrl.text,
        'image_base64': base64Encode(_inputImage!),
        'denoising_strength': _denoisingStrength,
        'width': int.parse(wh[0]),
        'height': int.parse(wh[1]),
        'steps': _steps.toInt(),
        'cfg_scale': _cfgScale,
        'seed': int.tryParse(_seedCtrl.text) ?? -1,
        'batch_size': int.tryParse(_batchSizeCtrl.text) ?? 1,
        'clip_skip': _clipSkip.toInt(),
        'sampler': _sampler,
        'resize_mode': 'Just resize',
        'loras': loras,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('img2img', style: TextStyle(color: Colors.white)),
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
        _label('입력 이미지'),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: _inputImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        Image.memory(_inputImage!, fit: BoxFit.contain))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file,
                          color: Colors.white38, size: 32),
                      SizedBox(height: 8),
                      Text('클릭하여 이미지 선택',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _sliderRow('Denoising Strength', _denoisingStrength, 0, 1,
            (v) => setState(() => _denoisingStrength = v),
            divisions: 20),
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
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 12),
        _label('Negative Prompt'),
        TextField(
          controller: _negativeCtrl,
          maxLines: 2,
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
        _sliderRow(
            'Steps', _steps, 1, 150, (v) => setState(() => _steps = v)),
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
                      ? () => setState(
                          () => _seedCtrl.text = _lastSeed.toString())
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
          items: ['DPM++ 2M Karras', 'DPM++ 2M']
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('LoRA 없음',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54),
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
              final enabled = _selectedLoras.containsKey(name);
              final weight = _selectedLoras[name] ?? 1.0;
              return Column(
                children: [
                  SwitchListTile(
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    value: enabled,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          _selectedLoras[name] = 1.0;
                        } else {
                          _selectedLoras.remove(name);
                        }
                      });
                    },
                  ),
                  if (enabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const Text('Weight',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor:
                                    const Color(0xFF0F3460),
                                thumbColor: Colors.blueAccent,
                                inactiveTrackColor: Colors.white12,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: weight,
                                min: 0.0,
                                max: 2.0,
                                divisions: 40,
                                onChanged: (v) => setState(
                                    () => _selectedLoras[name] = v),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(weight.toStringAsFixed(2),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Text(
                '${_selectedLoras.length}개 선택됨',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('새로고침'),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white54),
                onPressed: _loadLoras,
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear_all, size: 14),
                label: const Text('전체 해제'),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white38),
                onPressed: () =>
                    setState(() => _selectedLoras.clear()),
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
    if (_outputImages.isEmpty) {
      return const Center(
        child: Text('생성된 이미지가 없습니다',
            style: TextStyle(color: Colors.white24, fontSize: 14)),
      );
    }
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: const Color(0xFF16213E),
          child: Row(
            children: [
              if (_generationTime.isNotEmpty)
                Text(
                  '생성 완료 · $_generationTime · seed: $_lastSeed',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
              const Spacer(),
              _viewModeBtn('결과', Icons.image_outlined, 'result'),
              const SizedBox(width: 4),
              if (_inputImage != null)
                _viewModeBtn('비교', Icons.compare_arrows, 'compare'),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                tooltip: '결과 지우기',
                onPressed: () {
                  setState(() {
                    _outputImages = [];
                    _lastSeed = -1;
                    _generationTime = '';
                    _viewMode = 'result';
                  });
                  genService.reset();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _viewMode == 'compare' && _inputImage != null
              ? CompareSlider(
                  before: _inputImage!, after: _outputImages.first)
              : Center(
                  child: Image.memory(_outputImages.first,
                      fit: BoxFit.contain)),
        ),
      ],
    );
  }

  Widget _viewModeBtn(String label, IconData icon, String mode) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? Colors.white : Colors.white54),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                const TextStyle(color: Colors.white70, fontSize: 13)),
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
                    if (n != null && n < min) ctrl.text = min.toString();
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

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {bool isInt = false, int? divisions}) {
    final display =
        isInt ? value.toInt().toString() : value.toStringAsFixed(2);
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
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
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
}
