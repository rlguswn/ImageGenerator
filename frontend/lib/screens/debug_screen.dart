import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/app_paths.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 헬스 탭
  Map<String, dynamic>? _health;
  String _healthError = '';
  bool _healthAutoRefresh = true;
  Timer? _healthTimer;

  // 로그 탭
  List<String> _logLines = [];
  String _logError = '';
  bool _logAutoRefresh = true;
  Timer? _logTimer;
  String _logLevel = '전체';
  final _logScrollCtrl = ScrollController();

  // 설정 탭
  Map<String, dynamic>? _configData;
  String _configError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchHealth();
    _fetchLog();
    _fetchConfig();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _healthTimer?.cancel();
    _logTimer?.cancel();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_healthAutoRefresh && mounted) _fetchHealth();
    });
    _logTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_logAutoRefresh && mounted) _fetchLog();
    });
  }

  Future<void> _fetchHealth() async {
    try {
      final data = await api.health();
      if (!mounted) return;
      setState(() {
        _health = data;
        _healthError = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _healthError = e.toString());
    }
  }

  Future<void> _fetchLog() async {
    try {
      final now = DateTime.now();
      final name =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.log';
      final path = '${findProjectRoot()}${Platform.pathSeparator}logs${Platform.pathSeparator}$name';
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) setState(() => _logError = '로그 파일 없음: $path');
        return;
      }
      final lines = await file.readAsLines();
      if (!mounted) return;
      setState(() {
        _logLines = lines;
        _logError = '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollCtrl.hasClients) {
          _logScrollCtrl.jumpTo(_logScrollCtrl.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _logError = e.toString());
    }
  }

  Future<void> _fetchConfig() async {
    try {
      final data = await api.getConfig();
      if (!mounted) return;
      setState(() {
        _configData = data;
        _configError = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _configError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('개발자 도구', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: '헬스체크'),
            Tab(text: '로그'),
            Tab(text: '설정 JSON'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHealthTab(),
          _buildLogTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  // ── 헬스체크 탭 ──────────────────────────────────────────────
  Widget _buildHealthTab() {
    return Column(
      children: [
        _toolBar(
          autoRefresh: _healthAutoRefresh,
          onToggle: (v) => setState(() => _healthAutoRefresh = v),
          onRefresh: _fetchHealth,
          label: '3초마다 자동 새로고침',
        ),
        Expanded(
          child: _healthError.isNotEmpty
              ? _errorBox(_healthError)
              : _health == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : _buildHealthBody(_health!),
        ),
      ],
    );
  }

  Widget _buildHealthBody(Map<String, dynamic> h) {
    final vramTotal = h['vram_total'] as int? ?? 0;
    final vramFree = h['vram_free'] as int? ?? 0;
    final vramUsed = vramTotal - vramFree;
    final rows = <_KV>[
      _KV('상태', h['status']?.toString() ?? '-'),
      _KV('CUDA', (h['cuda_available'] as bool? ?? false) ? '사용 가능' : '없음'),
      _KV('모델 로딩', (h['model_loaded'] as bool? ?? false) ? '예' : '아니오'),
      _KV('모델 경로', (h['model_path'] ?? '-').toString().split('/').last),
      _KV('VRAM 전체', '$vramTotal MB'),
      _KV('VRAM 사용', '$vramUsed MB'),
      _KV('VRAM 여유', '$vramFree MB'),
      _KV('사용률', vramTotal > 0
          ? '${(vramUsed / vramTotal * 100).toStringAsFixed(1)}%'
          : '-'),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...rows.map(_buildKvRow),
        const SizedBox(height: 24),
        if (vramTotal > 0) _buildVramBar(vramUsed, vramTotal),
        const SizedBox(height: 24),
        const Text('Raw JSON',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 8),
        _jsonBox(const JsonEncoder.withIndent('  ').convert(h)),
      ],
    );
  }

  Widget _buildVramBar(int used, int total) {
    final ratio = (used / total).clamp(0.0, 1.0);
    final color = ratio > 0.85
        ? Colors.redAccent
        : ratio > 0.6
            ? Colors.orangeAccent
            : Colors.blueAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('VRAM 사용률',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('${(ratio * 100).toStringAsFixed(1)}%  ($used / $total MB)',
                style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildKvRow(_KV kv) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(kv.key,
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            Text(kv.value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      );

  // ── 로그 탭 ──────────────────────────────────────────────────
  Widget _buildLogTab() {
    final filtered = _filteredLines();
    return Column(
      children: [
        _toolBar(
          autoRefresh: _logAutoRefresh,
          onToggle: (v) => setState(() => _logAutoRefresh = v),
          onRefresh: _fetchLog,
          label: '2초마다 자동 새로고침',
          extra: Row(
            children: [
              const SizedBox(width: 12),
              _levelChip('전체'),
              _levelChip('INFO'),
              _levelChip('WARNING'),
              _levelChip('ERROR'),
            ],
          ),
        ),
        if (_logError.isNotEmpty) _errorBox(_logError),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('로그 없음',
                      style: TextStyle(color: Colors.white24, fontSize: 14)),
                )
              : ListView.builder(
                  controller: _logScrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildLogLine(filtered[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text('${filtered.length}줄',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.arrow_downward, size: 14),
                label: const Text('맨 아래로'),
                style: TextButton.styleFrom(foregroundColor: Colors.white38),
                onPressed: () {
                  if (_logScrollCtrl.hasClients) {
                    _logScrollCtrl.animateTo(
                      _logScrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _filteredLines() {
    if (_logLevel == '전체') return _logLines;
    return _logLines.where((l) => l.contains(_logLevel)).toList();
  }

  Widget _buildLogLine(String line) {
    Color color = Colors.white70;
    if (line.contains('ERROR')) {
      color = Colors.redAccent;
    } else if (line.contains('WARNING')) {
      color = Colors.orangeAccent;
    } else if (line.contains('INFO')) {
      color = const Color(0xFF90CAF9);
    } else if (line.contains('DEBUG')) {
      color = Colors.white38;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        line,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _levelChip(String level) {
    final selected = _logLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _logLevel = level),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(level,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11)),
      ),
    );
  }

  // ── 설정 JSON 탭 ─────────────────────────────────────────────
  Widget _buildConfigTab() {
    return Column(
      children: [
        _toolBar(
          autoRefresh: false,
          onToggle: null,
          onRefresh: _fetchConfig,
          label: '',
        ),
        Expanded(
          child: _configError.isNotEmpty
              ? _errorBox(_configError)
              : _configData == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _jsonBox(
                            const JsonEncoder.withIndent('  ').convert(_configData)),
                      ],
                    ),
        ),
      ],
    );
  }

  // ── 공통 위젯 ────────────────────────────────────────────────
  Widget _toolBar({
    required bool autoRefresh,
    required ValueChanged<bool>? onToggle,
    required VoidCallback onRefresh,
    required String label,
    Widget? extra,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          if (onToggle != null) ...[
            Switch(
              value: autoRefresh,
              onChanged: onToggle,
              activeThumbColor: Colors.blueAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          ?extra,
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
            onPressed: onRefresh,
            tooltip: '새로고침',
          ),
        ],
      ),
    );
  }

  Widget _jsonBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Colors.white38),
            tooltip: '복사',
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: text)),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) => Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(message,
              style:
                  const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ),
      );

}

class _KV {
  final String key;
  final String value;
  const _KV(this.key, this.value);
}
