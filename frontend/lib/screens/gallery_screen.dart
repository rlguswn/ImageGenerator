import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/app_paths.dart';
import '../services/regen_request.dart';
import '../services/home_nav.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static Map<String, dynamic>? _savedState;

  List<_GalleryItem> _items = [];
  List<_GalleryItem> _filtered = [];
  _GalleryItem? _selected;
  double _thumbSize = 160;

  String _filterMode = '전체';
  String _filterSort = '최신순';
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _multiSelect = false;

  @override
  void initState() {
    super.initState();
    _restoreState();
    _loadItems();
    _searchCtrl.addListener(_applyFilter);
  }

  void _restoreState() {
    final s = _savedState;
    if (s == null) return;
    _filterMode = s['filterMode'] as String? ?? '전체';
    _filterSort = s['filterSort'] as String? ?? '최신순';
    _thumbSize = (s['thumbSize'] as num?)?.toDouble() ?? 160;
    _searchCtrl.text = s['searchText'] as String? ?? '';
  }

  @override
  void dispose() {
    _savedState = {
      'filterMode': _filterMode,
      'filterSort': _filterSort,
      'thumbSize': _thumbSize,
      'searchText': _searchCtrl.text,
    };
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadItems() {
    final dir = Directory(outputDirPath);
    if (!dir.existsSync()) return;

    final items = <_GalleryItem>[];
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.png')) continue;
      final jsonPath = file.path.replaceAll('.png', '.json');
      Map<String, dynamic> meta = {};
      if (File(jsonPath).existsSync()) {
        try {
          meta = jsonDecode(File(jsonPath).readAsStringSync());
        } catch (_) {}
      }
      items.add(_GalleryItem(
        imagePath: file.path,
        meta: meta,
        id: file.uri.pathSegments.last,
      ));
    }

    setState(() {
      _items = items;
      _filtered = _computeFiltered(items);
    });
  }

  List<_GalleryItem> _computeFiltered(List<_GalleryItem> source) {
    var list = [...source];

    if (_filterMode != '전체') {
      list = list.where((i) => i.meta['mode'] == _filterMode).toList();
    }

    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) {
        final prompt = (i.meta['prompt'] ?? '').toLowerCase();
        return prompt.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      final da = a.meta['date'] ?? '';
      final db = b.meta['date'] ?? '';
      return _filterSort == '최신순' ? db.compareTo(da) : da.compareTo(db);
    });

    return list;
  }

  void _applyFilter() {
    setState(() => _filtered = _computeFiltered(_items));
  }

  void _regenItem(_GalleryItem item) {
    final meta = item.meta;
    final settings = meta['settings'] as Map? ?? {};
    final w = settings['width'] ?? 512;
    final h = settings['height'] ?? 512;
    final mode = meta['mode'] as String? ?? 'txt2img';

    final state = <String, dynamic>{
      'prompt': meta['prompt'] ?? '',
      'negative': meta['negative_prompt'] ?? '',
      'resolution': '${w}x$h',
      'steps': (settings['steps'] as num?)?.toDouble() ?? 20.0,
      'cfgScale': (settings['cfg_scale'] as num?)?.toDouble() ?? 7.0,
      'seed': '-1',
      'sampler': settings['sampler'] ?? 'DPM++ 2M Karras',
      'clipSkip': (settings['clip_skip'] as num?)?.toDouble() ?? 1.0,
    };

    if (mode == 'img2img') {
      state['denoisingStrength'] =
          (settings['denoising_strength'] as num?)?.toDouble() ?? 0.75;
      regenNotifier.value = RegenPayload('img2img', state);
      homeTabNotifier.value = 1;
    } else {
      regenNotifier.value = RegenPayload('txt2img', state);
      homeTabNotifier.value = 0;
    }
  }

  Future<void> _exportItem(_GalleryItem item) async {
    final destDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '저장할 폴더 선택',
    );
    if (destDir == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fileName = item.imagePath.split(Platform.pathSeparator).last;
      final dest = '$destDir${Platform.pathSeparator}$fileName';
      File(item.imagePath).copySync(dest);
      messenger.showSnackBar(SnackBar(content: Text('저장 완료: $dest')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }

  void _openInInpaint(_GalleryItem item) {
    final meta = item.meta;
    final settings = meta['settings'] as Map? ?? {};
    regenNotifier.value = RegenPayload('inpaint', {
      'imagePath': item.imagePath,
      'prompt': meta['prompt'] ?? '',
      'negative': meta['negative_prompt'] ?? '',
      'seed': '-1',
      'steps': (settings['steps'] as num?)?.toDouble() ?? 20.0,
      'cfgScale': (settings['cfg_scale'] as num?)?.toDouble() ?? 7.0,
      'sampler': settings['sampler'] ?? 'DPM++ 2M Karras',
    });
    homeTabNotifier.value = 2;
  }

  Future<void> _saveAsPreset(_GalleryItem item) async {
    final meta = item.meta;
    final settings = meta['settings'] as Map? ?? {};
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.savePreset({
        'name': '${meta['date'] ?? '프리셋'} (${meta['mode'] ?? 'txt2img'})',
        'mode': meta['mode'] ?? 'txt2img',
        'prompt': meta['prompt'] ?? '',
        'negative_prompt': meta['negative_prompt'] ?? '',
        'settings': Map<String, dynamic>.from(settings),
      });
      messenger.showSnackBar(
          const SnackBar(content: Text('프리셋으로 저장되었습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('프리셋 저장 실패: $e')));
    }
  }

  Future<void> _deleteItem(_GalleryItem item) async {
    final confirm = await _showConfirm('이미지를 삭제하시겠습니까?');
    if (!confirm || !mounted) return;
    try {
      File(item.imagePath).deleteSync();
      final json = item.imagePath.replaceAll('.png', '.json');
      if (File(json).existsSync()) File(json).deleteSync();
    } catch (_) {}
    setState(() {
      _items.remove(item);
      if (_selected == item) _selected = null;
      _filtered = _computeFiltered(_items);
    });
  }

  Future<void> _deleteSelected() async {
    final confirm =
        await _showConfirm('선택한 ${_selectedIds.length}개를 삭제하시겠습니까?');
    if (!confirm || !mounted) return;
    final toDelete = _items.where((i) => _selectedIds.contains(i.id)).toList();
    for (final item in toDelete) {
      try {
        File(item.imagePath).deleteSync();
        final json = item.imagePath.replaceAll('.png', '.json');
        if (File(json).existsSync()) File(json).deleteSync();
      } catch (_) {}
      _items.remove(item);
    }
    setState(() {
      _selectedIds.clear();
      _multiSelect = false;
      if (_selected != null && toDelete.contains(_selected)) _selected = null;
      _filtered = _computeFiltered(_items);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('갤러리', style: TextStyle(color: Colors.white)),
        actions: [
          if (_multiSelect && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteSelected,
            ),
          IconButton(
            icon: Icon(
              _multiSelect ? Icons.check_box : Icons.check_box_outline_blank,
              color: Colors.white70,
            ),
            onPressed: () => setState(() {
              _multiSelect = !_multiSelect;
              _selectedIds.clear();
            }),
            tooltip: '다중 선택',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadItems,
            tooltip: '새로고침',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // 좌측: 필터 + 그리드
          Expanded(
            child: Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildGrid()),
              ],
            ),
          ),
          // 우측: 상세 보기
          if (_selected != null)
            SizedBox(width: 320, child: _buildDetail(_selected!)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '프롬프트 검색',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true,
                fillColor: const Color(0xFF0F3460),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _filterDrop(_filterMode, ['전체', 'txt2img', 'img2img', 'inpaint'], (v) {
            _filterMode = v!;
            _applyFilter();
          }),
          const SizedBox(width: 8),
          _filterDrop(_filterSort, ['최신순', '오래된순'], (v) {
            _filterSort = v!;
            _applyFilter();
          }),
          const Spacer(),
          const Icon(Icons.photo_size_select_large, color: Colors.white38, size: 16),
          Slider(
            value: _thumbSize,
            min: 100,
            max: 250,
            onChanged: (v) => setState(() => _thumbSize = v),
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _filterDrop(String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: const Color(0xFF0F3460),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      underline: const SizedBox(),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('이미지가 없습니다',
            style: TextStyle(color: Colors.white24, fontSize: 14)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ((MediaQuery.of(context).size.width - (_selected != null ? 320 : 0)) / _thumbSize).floor().clamp(2, 8),
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final item = _filtered[i];
        final isSelected = _selectedIds.contains(item.id);
        return GestureDetector(
          onTap: () {
            if (_multiSelect) {
              setState(() {
                if (isSelected) {
                _selectedIds.remove(item.id);
              } else {
                _selectedIds.add(item.id);
              }
              });
            } else {
              setState(() => _selected = item);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(item.imagePath), fit: BoxFit.cover),
              ),
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 32),
                ),
              if (_selected == item && !_multiSelect)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetail(_GalleryItem item) {
    final meta = item.meta;
    final settings = meta['settings'] as Map? ?? {};

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(item.imagePath), fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            _metaRow('날짜', meta['date'] ?? ''),
            _metaRow('모드', meta['mode'] ?? ''),
            _metaRow('모델', (meta['model'] ?? '').toString().split('/').last),
            _metaRow('생성시간', '${meta['generation_time'] ?? ''}초'),
            const Divider(color: Colors.white12, height: 24),
            const Text('프롬프트', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(meta['prompt'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(height: 12),
            _metaRow('Steps', settings['steps']?.toString() ?? ''),
            _metaRow('CFG', settings['cfg_scale']?.toString() ?? ''),
            _metaRow('Seed', settings['seed']?.toString() ?? ''),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('재생성'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                  ),
                  onPressed: () => _regenItem(item),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt, size: 16),
                  label: const Text('내보내기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () => _exportItem(item),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.brush_outlined, size: 16),
                  label: const Text('인페인트'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purpleAccent,
                    side: const BorderSide(color: Colors.purpleAccent),
                  ),
                  onPressed: () => _openInInpaint(item),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('프리셋'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () => _saveAsPreset(item),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: () => _deleteItem(item),
          ),
        ],
      ),
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      );

  Future<bool> _showConfirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            content: Text(message,
                style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('확인',
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ) ??
        false;
  }
}

class _GalleryItem {
  final String imagePath;
  final Map<String, dynamic> meta;
  final String id;
  _GalleryItem({required this.imagePath, required this.meta, required this.id});
}
