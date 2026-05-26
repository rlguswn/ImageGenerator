import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/generation_service.dart';
import '../services/regen_request.dart';
import '../widgets/compare_slider.dart';

class InpaintScreen extends StatefulWidget {
  const InpaintScreen({super.key});

  @override
  State<InpaintScreen> createState() => _InpaintScreenState();
}

class _InpaintScreenState extends State<InpaintScreen> {
  static Map<String, dynamic>? _savedState;

  // Image
  Uint8List? _inputImage;
  Size _imageActualSize = Size.zero;
  Uint8List? _outputImage;

  // Mask drawing
  final List<_DrawStroke> _strokes = [];
  _DrawStroke? _currentStroke;
  bool _isEraser = false;
  double _brushSize = 30.0;
  bool _showMask = true;
  bool _maskInverted = false;
  // Updated inside LayoutBuilder without setState — only read in async methods
  Rect _imageDisplayRect = Rect.zero;

  // View mode: 'edit' | 'result' | 'compare'
  String _viewMode = 'edit';

  // Generation params
  final _promptCtrl = TextEditingController();
  final _negativeCtrl = TextEditingController();
  final _seedCtrl = TextEditingController(text: '-1');
  double _steps = 15;
  double _cfgScale = 7.0;
  double _denoisingStrength = 0.75;
  String _sampler = 'DPM++ 2M Karras';

  // Generation result
  String _generationTime = '';
  int _lastSeed = -1;

  // Pipeline
  String _pipelineMode = '';
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _restoreState();
    _fetchPipelineMode();
    genService.notifier.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = regenNotifier.value;
      if (pending != null && pending.mode == 'inpaint') {
        _applyRegenState(pending.state);
        regenNotifier.value = null;
      }
      final s = genService.state;
      if (s.isDone && s.mode == 'inpaint') _applyServiceResult(s);
    });
    regenNotifier.addListener(_onRegenRequest);
  }

  @override
  void dispose() {
    genService.notifier.removeListener(_onServiceChanged);
    regenNotifier.removeListener(_onRegenRequest);
    _saveState();
    _promptCtrl.dispose();
    _negativeCtrl.dispose();
    _seedCtrl.dispose();
    super.dispose();
  }

  void _onRegenRequest() {
    final payload = regenNotifier.value;
    if (payload == null || payload.mode != 'inpaint') return;
    _applyRegenState(payload.state);
    regenNotifier.value = null;
  }

  void _onServiceChanged() {
    final s = genService.state;
    if (s.mode != 'inpaint') return;
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
    if (s.images.isEmpty) return;
    setState(() {
      _outputImage = s.images.first;
      _lastSeed = s.lastSeed;
      _generationTime = s.generationTime;
      _pipelineMode = 'inpaint';
      _viewMode = 'result';
    });
  }

  Future<void> _applyRegenState(Map<String, dynamic> s) async {
    final path = s['imagePath'] as String?;
    Uint8List? bytes;
    Size actualSize = Size.zero;
    if (path != null) {
      try {
        bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        actualSize = Size(img.width.toDouble(), img.height.toDouble());
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _promptCtrl.text = s['prompt'] as String? ?? '';
      _negativeCtrl.text = s['negative'] as String? ?? '';
      _seedCtrl.text = s['seed'] as String? ?? '-1';
      _steps = (s['steps'] as num?)?.toDouble() ?? 20;
      _cfgScale = (s['cfgScale'] as num?)?.toDouble() ?? 7.0;
      _sampler = s['sampler'] as String? ?? 'DPM++ 2M Karras';
      if (bytes != null) {
        _inputImage = bytes;
        _imageActualSize = actualSize;
        _strokes.clear();
        _outputImage = null;
        _viewMode = 'edit';
      }
    });
  }

  void _restoreState() {
    final s = _savedState;
    if (s == null) return;
    _promptCtrl.text = s['prompt'] as String? ?? '';
    _negativeCtrl.text = s['negative'] as String? ?? '';
    _seedCtrl.text = s['seed'] as String? ?? '-1';
    _steps = (s['steps'] as num?)?.toDouble() ?? 20;
    _cfgScale = (s['cfgScale'] as num?)?.toDouble() ?? 7.0;
    _denoisingStrength = (s['denoisingStrength'] as num?)?.toDouble() ?? 0.75;
    _sampler = s['sampler'] as String? ?? 'DPM++ 2M Karras';
    _inputImage = s['inputImage'] as Uint8List?;
    _imageActualSize = Size(
      (s['imgW'] as num?)?.toDouble() ?? 0,
      (s['imgH'] as num?)?.toDouble() ?? 0,
    );
    _outputImage = s['outputImage'] as Uint8List?;
    _generationTime = s['generationTime'] as String? ?? '';
    _lastSeed = s['lastSeed'] as int? ?? -1;
    _viewMode = s['viewMode'] as String? ?? 'edit';
    _maskInverted = s['maskInverted'] as bool? ?? false;
    for (final raw in s['strokes'] as List? ?? []) {
      final stroke = _DrawStroke(
        size: (raw['size'] as num).toDouble(),
        isEraser: raw['isEraser'] as bool,
      );
      for (final p in raw['points'] as List) {
        stroke.points
            .add(Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
      _strokes.add(stroke);
    }
  }

  void _saveState() {
    _savedState = {
      'prompt': _promptCtrl.text,
      'negative': _negativeCtrl.text,
      'seed': _seedCtrl.text,
      'steps': _steps,
      'cfgScale': _cfgScale,
      'denoisingStrength': _denoisingStrength,
      'sampler': _sampler,
      'inputImage': _inputImage,
      'imgW': _imageActualSize.width,
      'imgH': _imageActualSize.height,
      'outputImage': _outputImage,
      'generationTime': _generationTime,
      'lastSeed': _lastSeed,
      'viewMode': _viewMode,
      'maskInverted': _maskInverted,
      'strokes': _strokes
          .map((s) => {
                'size': s.size,
                'isEraser': s.isEraser,
                'points': s.points.map((p) => [p.dx, p.dy]).toList(),
              })
          .toList(),
    };
  }

  Future<void> _fetchPipelineMode() async {
    try {
      final h = await api.health();
      if (mounted) {
        setState(() {
          _pipelineMode = h['pipeline_mode'] as String? ?? '';
          _modelLoaded = h['model_loaded'] as bool? ?? false;
        });
      }
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
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (!mounted) return;
      setState(() {
        _inputImage = bytes;
        _imageActualSize = Size(img.width.toDouble(), img.height.toDouble());
        _strokes.clear();
        _outputImage = null;
        _viewMode = 'edit';
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일 읽기 실패: $e')));
    }
  }

  Rect _computeImageRect(Size containerSize) {
    if (_imageActualSize == Size.zero) return Rect.zero;
    final imgAR = _imageActualSize.width / _imageActualSize.height;
    final conAR = containerSize.width / containerSize.height;
    double w, h;
    if (imgAR > conAR) {
      w = containerSize.width;
      h = containerSize.width / imgAR;
    } else {
      h = containerSize.height;
      w = containerSize.height * imgAR;
    }
    return Rect.fromLTWH(
      (containerSize.width - w) / 2,
      (containerSize.height - h) / 2,
      w,
      h,
    );
  }

  void _onPanStart(Offset pos) {
    if (!_imageDisplayRect.contains(pos)) return;
    setState(() {
      _currentStroke = _DrawStroke(size: _brushSize, isEraser: _isEraser);
      _currentStroke!.points.add(pos - _imageDisplayRect.topLeft);
    });
  }

  void _onPanUpdate(Offset pos) {
    if (_currentStroke == null) return;
    final clamped = Offset(
      pos.dx.clamp(_imageDisplayRect.left, _imageDisplayRect.right),
      pos.dy.clamp(_imageDisplayRect.top, _imageDisplayRect.bottom),
    );
    setState(() =>
        _currentStroke!.points.add(clamped - _imageDisplayRect.topLeft));
  }

  void _onPanEnd() {
    if (_currentStroke == null) return;
    setState(() {
      if (_currentStroke!.points.isNotEmpty) _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clearMask() => setState(() {
        _strokes.clear();
        _currentStroke = null;
      });

  Future<Uint8List> _exportMask() async {
    final rect = _imageDisplayRect;
    final imgW = _imageActualSize.width.toInt();
    final imgH = _imageActualSize.height.toInt();
    final scaleX = imgW / rect.width;
    final scaleY = imgH / rect.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 배경: 비반전 = 검정(유지), 반전 = 흰색(전체 재생성)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble()),
      Paint()..color = _maskInverted ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    );
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble()),
      Paint(),
    );

    for (final stroke in _strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..strokeWidth = stroke.size * scaleX
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.isEraser) {
        // 비반전: 지우개 = 흰색 마스크 제거(검정 복원)
        // 반전: 지우개 = 흰색 복원(재생성으로 복원)
        paint.color = Colors.transparent;
        paint.blendMode = BlendMode.clear;
      } else {
        // 비반전: 브러시 = 흰색(재생성)
        // 반전: 브러시 = 검정(유지)
        paint.color =
            _maskInverted ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      }

      final pts = stroke.points
          .map((p) => Offset(p.dx * scaleX, p.dy * scaleY))
          .toList();

      if (pts.length == 1) {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(pts.first, stroke.size * scaleX / 2, paint);
      } else {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
    final picture = recorder.endRecording();
    final image = await picture.toImage(imgW, imgH);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  Future<void> _checkAndGenerate() async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('로드된 모델이 없습니다. 설정 탭에서 모델을 선택해 주세요.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    if (_inputImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('입력 이미지를 선택하세요')));
      return;
    }
    if (_strokes.isEmpty && !_maskInverted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('마스크 영역을 그려주세요')));
      return;
    }
    if (_pipelineMode != 'inpaint') {
      final confirmed = await _showPipelineSwitchDialog();
      if (confirmed != true || !mounted) return;
    }
    _generate();
  }

  Future<bool?> _showPipelineSwitchDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title:
            const Text('파이프라인 전환', style: TextStyle(color: Colors.white)),
        content: const Text(
          '인페인팅 파이프라인으로 전환합니다.\n\n'
          '동일한 모델 가중치를 공유하므로 추가 VRAM 소모는 없으나, '
          '첫 전환 시 파이프라인 구성에 수 초가 소요될 수 있습니다.\n\n'
          '이후에는 확인 없이 바로 생성됩니다.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3460)),
            child: const Text('전환 후 생성'),
          ),
        ],
      ),
    );
  }

  /// 원본 비율을 유지하면서 VRAM 안전한 생성 해상도 계산 (64의 배수)
  (int, int) _calcGenResolution() {
    final w = _imageActualSize.width;
    final h = _imageActualSize.height;
    if (w == 0 || h == 0) return (512, 512);

    const maxPixels = 768 * 768; // SDXL 8GB VRAM 안전 상한
    int genW, genH;
    if (w * h <= maxPixels) {
      genW = (w / 64).round() * 64;
      genH = (h / 64).round() * 64;
    } else {
      final ratio = w / h;
      final newH = math.sqrt(maxPixels / ratio);
      final newW = newH * ratio;
      genW = ((newW / 64).round() * 64).clamp(64, 1536);
      genH = ((newH / 64).round() * 64).clamp(64, 1536);
    }
    return (genW, genH);
  }

  Future<void> _generate() async {
    Uint8List maskBytes;
    try {
      maskBytes = await _exportMask();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('마스크 내보내기 실패: $e')));
      }
      return;
    }

    if (mounted) setState(() => _viewMode = 'edit');

    final (genW, genH) = _calcGenResolution();

    await genService.run(
      mode: 'inpaint',
      apiCall: () => api.inpaint({
        'prompt': _promptCtrl.text,
        'negative_prompt': _negativeCtrl.text,
        'image_base64': base64Encode(_inputImage!),
        'mask_base64': base64Encode(maskBytes),
        'denoising_strength': _denoisingStrength,
        'width': genW,
        'height': genH,
        'steps': _steps.toInt(),
        'cfg_scale': _cfgScale,
        'seed': int.tryParse(_seedCtrl.text) ?? -1,
        'clip_skip': 1,
        'sampler': _sampler,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('인페인트', style: TextStyle(color: Colors.white)),
        actions: [
          if (_inputImage != null)
            TextButton.icon(
              icon: const Icon(Icons.folder_open,
                  size: 16, color: Colors.white54),
              label: const Text('이미지 변경',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onPressed: _pickImage,
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
                  Expanded(child: _buildSettingsPanel()),
                  _buildGenerateButton(),
                ],
              ),
            ),
          ),
          Expanded(child: _buildCanvasArea()),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Prompt'),
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
        _sliderRow('Denoising Strength', _denoisingStrength, 0, 1,
            (v) => setState(() => _denoisingStrength = v),
            divisions: 20),
        _sliderRow(
            'Steps', _steps, 1, 150, (v) => setState(() => _steps = v)),
        _sliderRow('CFG Scale', _cfgScale, 1, 30,
            (v) => setState(() => _cfgScale = v),
            divisions: 58),
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
                      color:
                          _lastSeed != -1 ? Colors.blueAccent : Colors.white12,
                      size: 18),
                  tooltip:
                      _lastSeed != -1 ? 'seed 재사용: $_lastSeed' : '이전 seed 없음',
                  onPressed: _lastSeed != -1
                      ? () =>
                          setState(() => _seedCtrl.text = _lastSeed.toString())
                      : null,
                ),
                IconButton(
                  icon:
                      const Icon(Icons.shuffle, color: Colors.white54, size: 18),
                  onPressed: () => setState(() => _seedCtrl.text = '-1'),
                ),
              ],
            ),
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
              onPressed: s.isActive ? null : _checkAndGenerate,
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

  Widget _buildCanvasArea() {
    if (_inputImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw_outlined, color: Colors.white12, size: 64),
            const SizedBox(height: 16),
            const Text('이미지를 선택해 마스크를 그려주세요',
                style: TextStyle(color: Colors.white24, fontSize: 14)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('이미지 선택'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
              ),
              onPressed: _pickImage,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _viewMode == 'result' && _outputImage != null
              ? _buildResultView()
              : _viewMode == 'compare' &&
                      _inputImage != null &&
                      _outputImage != null
                  ? CompareSlider(
                      before: _inputImage!, after: _outputImage!)
                  : _buildMaskCanvas(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          _toolBtn(
            icon: Icons.brush,
            label: '브러시',
            active: !_isEraser,
            onTap: () => setState(() => _isEraser = false),
          ),
          const SizedBox(width: 6),
          _toolBtn(
            icon: Icons.auto_fix_normal,
            label: '지우개',
            active: _isEraser,
            onTap: () => setState(() => _isEraser = true),
          ),
          const SizedBox(width: 10),
          const Text('크기',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blueAccent,
                thumbColor: Colors.blueAccent,
                inactiveTrackColor: Colors.white12,
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _brushSize,
                min: 5,
                max: 100,
                onChanged: (v) => setState(() => _brushSize = v),
              ),
            ),
          ),
          Text('${_brushSize.toInt()}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 4),
          // 되돌리기
          IconButton(
            icon: Icon(Icons.undo,
                color: _strokes.isEmpty ? Colors.white12 : Colors.white54,
                size: 18),
            tooltip: '되돌리기',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          const SizedBox(width: 4),
          // 전체 지우기
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: _strokes.isEmpty ? Colors.white12 : Colors.white54,
                size: 18),
            tooltip: '마스크 전체 지우기',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _strokes.isEmpty ? null : _clearMask,
          ),
          const SizedBox(width: 4),
          // 마스크 표시 토글
          IconButton(
            icon: Icon(
              _showMask ? Icons.visibility : Icons.visibility_off,
              color: _showMask ? Colors.blueAccent : Colors.white38,
              size: 18,
            ),
            tooltip: '마스크 표시',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _showMask = !_showMask),
          ),
          const SizedBox(width: 4),
          // 마스크 반전
          IconButton(
            icon: Icon(Icons.invert_colors,
                color: _maskInverted ? Colors.orangeAccent : Colors.white38,
                size: 18),
            tooltip: _maskInverted ? '마스크 반전 해제' : '마스크 반전 (전체→보호)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _maskInverted = !_maskInverted),
          ),
          const Spacer(),
          // 편집 / 비교 / 결과 전환 (결과 있을 때만)
          if (_outputImage != null) ...[
            _toolBtn(
              icon: Icons.edit_outlined,
              label: '편집',
              active: _viewMode == 'edit',
              onTap: () => setState(() => _viewMode = 'edit'),
            ),
            const SizedBox(width: 4),
            _toolBtn(
              icon: Icons.compare_arrows,
              label: '비교',
              active: _viewMode == 'compare',
              onTap: () => setState(() => _viewMode = 'compare'),
            ),
            const SizedBox(width: 4),
            _toolBtn(
              icon: Icons.image_outlined,
              label: '결과',
              active: _viewMode == 'result',
              onTap: () => setState(() => _viewMode = 'result'),
            ),
          ],
          if (_generationTime.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(_generationTime,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaskCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        // 직접 할당 — setState 없이 레이아웃 정보만 저장
        _imageDisplayRect = _computeImageRect(canvasSize);

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d.localPosition),
          onPanUpdate: (d) => _onPanUpdate(d.localPosition),
          onPanEnd: (_) => _onPanEnd(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black87),
              if (_imageDisplayRect != Rect.zero)
                Positioned.fromRect(
                  rect: _imageDisplayRect,
                  child: Image.memory(_inputImage!, fit: BoxFit.fill),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _MaskPainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    imageRect: _imageDisplayRect,
                    showMask: _showMask,
                    inverted: _maskInverted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black87),
        Image.memory(_outputImage!, fit: BoxFit.contain),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'seed: $_lastSeed',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 공통 위젯 헬퍼 ────────────────────────────────────────────

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
      {int? divisions}) {
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
              Text(value.toStringAsFixed(1),
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
}

// ── 데이터 클래스 ─────────────────────────────────────────────────

class _DrawStroke {
  final List<Offset> points;
  final double size;
  final bool isEraser;
  _DrawStroke({required this.size, required this.isEraser}) : points = [];
}

// ── 마스크 CustomPainter ──────────────────────────────────────────

class _MaskPainter extends CustomPainter {
  final List<_DrawStroke> strokes;
  final _DrawStroke? currentStroke;
  final Rect imageRect;
  final bool showMask;
  final bool inverted;

  const _MaskPainter({
    required this.strokes,
    this.currentStroke,
    required this.imageRect,
    required this.showMask,
    this.inverted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showMask || imageRect == Rect.zero) return;

    canvas.save();
    canvas.clipRect(imageRect);
    canvas.translate(imageRect.left, imageRect.top);
    // saveLayer 필수 — BlendMode.clear(지우개)가 올바르게 동작하려면
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, imageRect.width, imageRect.height),
      Paint(),
    );

    // 반전 모드: 전체를 빨간 오버레이로 채움 (전부 재생성됨을 표시)
    if (inverted) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, imageRect.width, imageRect.height),
        Paint()..color = Colors.red.withValues(alpha: 0.35),
      );
    }

    for (final s in [...strokes, ?currentStroke]) {
      _drawStroke(canvas, s);
    }

    canvas.restore();
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, _DrawStroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (inverted) {
      // 반전: 브러시 = 빨간 오버레이 제거(보호 영역), 지우개 = 오버레이 추가
      if (stroke.isEraser) {
        paint.color = Colors.red.withValues(alpha: 0.35);
      } else {
        paint.color = Colors.transparent;
        paint.blendMode = BlendMode.clear;
      }
    } else {
      // 일반: 브러시 = 빨간 오버레이(재생성), 지우개 = 지움
      if (stroke.isEraser) {
        paint.color = Colors.transparent;
        paint.blendMode = BlendMode.clear;
      } else {
        paint.color = Colors.red.withValues(alpha: 0.5);
      }
    }

    if (stroke.points.length == 1) {
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(stroke.points.first, stroke.size / 2, paint);
    } else {
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MaskPainter old) => true;
}
