import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoraScreen extends StatefulWidget {
  const LoraScreen({super.key});

  @override
  State<LoraScreen> createState() => _LoraScreenState();
}

class _LoraScreenState extends State<LoraScreen> {
  static Map<String, dynamic>? _savedState;

  final _nameCtrl = TextEditingController();
  final _imageDirCtrl = TextEditingController();
  double _steps = 1000;
  double _learningRate = 1e-4;
  double _networkRank = 32;

  String? _jobId;
  Map<String, dynamic>? _status;
  Timer? _pollTimer;
  bool _isTraining = false;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  void _restoreState() {
    final s = _savedState;
    if (s == null) return;
    _nameCtrl.text = s['name'] as String? ?? '';
    _imageDirCtrl.text = s['imageDir'] as String? ?? '';
    _steps = (s['steps'] as num?)?.toDouble() ?? 1000;
    _learningRate = (s['learningRate'] as num?)?.toDouble() ?? 1e-4;
    _networkRank = (s['networkRank'] as num?)?.toDouble() ?? 32;
    _jobId = s['jobId'] as String?;
    _isTraining = s['isTraining'] as bool? ?? false;
    if (s['status'] != null) {
      _status = Map<String, dynamic>.from(s['status'] as Map);
    }
    if (_isTraining && _jobId != null) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _savedState = {
      'name': _nameCtrl.text,
      'imageDir': _imageDirCtrl.text,
      'steps': _steps,
      'learningRate': _learningRate,
      'networkRank': _networkRank,
      'jobId': _jobId,
      'isTraining': _isTraining,
      'status': _status,
    };
    _nameCtrl.dispose();
    _imageDirCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTraining() async {
    if (_nameCtrl.text.isEmpty || _imageDirCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모델 이름과 이미지 폴더를 입력하세요')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('학습 전 확인 사항',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          '학습 이미지에 대한 다음 사항을 확인해 주세요:\n\n'
          '• 이미지의 저작권자이거나 사용 허가를 받으셨나요?\n'
          '• 이미지 속 인물(들)의 동의를 받으셨나요?\n'
          '• 타인의 초상권 또는 저작권을 침해하지 않나요?\n\n'
          '위 조건을 충족하지 않는 이미지로 학습하는 것은 법적 문제가 될 수 있습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('확인하고 시작'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final jobId = await api.startLoraTrain({
        'image_dir': _imageDirCtrl.text,
        'output_name': _nameCtrl.text,
        'steps': _steps.toInt(),
        'learning_rate': _learningRate,
        'network_rank': _networkRank.toInt(),
      });
      if (!mounted) return;
      setState(() {
        _jobId = jobId;
        _isTraining = true;
      });
      _startPolling();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_jobId == null) return;
      try {
        final status = await api.getLoraStatus(_jobId!);
        if (!mounted) return;
        setState(() => _status = status);
        if (status['status'] == 'completed' || status['status'] == 'failed') {
          _pollTimer?.cancel();
          setState(() => _isTraining = false);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('LoRA 파인튜닝', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Container(
          width: 520,
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
              _label('모델 이름'),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco(hint: 'my_lora_v1'),
              ),
              const SizedBox(height: 16),
              _label('학습 이미지 폴더'),
              TextField(
                controller: _imageDirCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco(hint: 'D:\\images\\my_subject'),
              ),
              const SizedBox(height: 4),
              const Text('20~30장 권장',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 16),
              _sliderRow('학습 스텝', _steps, 100, 5000,
                  (v) => setState(() => _steps = v), isInt: true),
              _sliderRow('Network Rank', _networkRank, 4, 128,
                  (v) => setState(() => _networkRank = v), isInt: true),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Learning Rate',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  DropdownButton<double>(
                    value: _learningRate,
                    dropdownColor: const Color(0xFF0F3460),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    items: [1e-3, 5e-4, 1e-4, 5e-5, 1e-5]
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r.toStringAsExponential(0))))
                        .toList(),
                    onChanged: (v) => setState(() => _learningRate = v!),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 진행 상태
              if (_status != null) ...[
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                _buildProgress(),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isTraining ? null : _startTraining,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isTraining ? '학습 중...' : '학습 시작',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final status = _status!;
    final step = status['step'] as int? ?? 0;
    final total = status['total'] as int? ?? 1;
    final elapsed = (status['elapsed'] as num?)?.toDouble() ?? 0;
    final statusStr = status['status'] as String? ?? '';
    final error = status['error'] as String?;

    final progress = step / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$step / $total steps',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(
              statusStr == 'completed'
                  ? '완료 (${elapsed.toStringAsFixed(0)}초)'
                  : statusStr == 'failed'
                      ? '실패'
                      : '경과 ${elapsed.toStringAsFixed(0)}초',
              style: TextStyle(
                color: statusStr == 'completed'
                    ? Colors.greenAccent
                    : statusStr == 'failed'
                        ? Colors.redAccent
                        : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              statusStr == 'completed' ? Colors.greenAccent : Colors.blueAccent,
            ),
            minHeight: 8,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {bool isInt = false}) {
    final display = isInt ? value.toInt().toString() : value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(display,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
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
              divisions: (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
