import 'package:flutter/material.dart';
import 'txt2img_screen.dart';
import 'img2img_screen.dart';
import 'inpaint_screen.dart';
import 'gallery_screen.dart';
import 'lora_screen.dart';
import 'settings_screen.dart';
import 'debug_screen.dart';
import '../services/dev_mode.dart';
import '../services/home_nav.dart';
import '../services/generation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _baseScreens = <Widget>[
    Txt2ImgScreen(),
    Img2ImgScreen(),
    InpaintScreen(),
    GalleryScreen(),
    LoraScreen(),
    SettingsScreen(),
  ];

  static const _baseNavItems = [
    NavigationRailDestination(
      icon: Icon(Icons.text_fields_outlined),
      selectedIcon: Icon(Icons.text_fields),
      label: Text('txt2img'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.image_outlined),
      selectedIcon: Icon(Icons.image),
      label: Text('img2img'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.brush_outlined),
      selectedIcon: Icon(Icons.brush),
      label: Text('인페인트'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.photo_library_outlined),
      selectedIcon: Icon(Icons.photo_library),
      label: Text('갤러리'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.model_training_outlined),
      selectedIcon: Icon(Icons.model_training),
      label: Text('LoRA'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('설정'),
    ),
  ];

  static const _debugNavItem = NavigationRailDestination(
    icon: Icon(Icons.bug_report_outlined),
    selectedIcon: Icon(Icons.bug_report),
    label: Text('디버그'),
  );

  @override
  void initState() {
    super.initState();
    devModeNotifier.addListener(_onDevModeChanged);
    homeTabNotifier.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    devModeNotifier.removeListener(_onDevModeChanged);
    homeTabNotifier.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final i = homeTabNotifier.value;
    final maxIndex = devModeNotifier.value ? 6 : 5;
    if (i >= 0 && i <= maxIndex) setState(() => _selectedIndex = i);
  }

  void _onDevModeChanged() {
    final maxIndex = devModeNotifier.value ? 6 : 5;
    if (_selectedIndex > maxIndex) {
      setState(() => _selectedIndex = 0);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final devMode = devModeNotifier.value;
    final screens = devMode
        ? [..._baseScreens, const DebugScreen()]
        : _baseScreens;
    final navItems = devMode
        ? [..._baseNavItems, _debugNavItem]
        : _baseNavItems;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF16213E),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) {
              setState(() => _selectedIndex = i);
              homeTabNotifier.value = i;
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
            unselectedIconTheme: const IconThemeData(color: Colors.white38),
            selectedLabelTextStyle:
                const TextStyle(color: Colors.blueAccent, fontSize: 11),
            unselectedLabelTextStyle:
                const TextStyle(color: Colors.white38, fontSize: 11),
            destinations: navItems,
          ),
          const VerticalDivider(color: Colors.white12, width: 1),
          Expanded(child: screens[_selectedIndex]),
          const VerticalDivider(color: Colors.white12, width: 1),
          const _GenSidebar(),
        ],
      ),
    );
  }
}

class _GenSidebar extends StatelessWidget {
  const _GenSidebar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GenState>(
      valueListenable: genService.notifier,
      builder: (context, s, _) {
        return SizedBox(
          width: 200,
          child: Container(
            color: const Color(0xFF16213E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: const Text(
                    '생성 현황',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                ),
                Expanded(child: _buildContent(context, s)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, GenState s) {
    switch (s.status) {
      case GenStatus.idle:
        return const Center(
          child: Text('대기 중',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        );
      case GenStatus.generating:
        return _buildGenerating(s);
      case GenStatus.done:
        return _buildDone(s);
      case GenStatus.error:
        return _buildError(s);
    }
  }

  Widget _buildGenerating(GenState s) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blueAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.mode.isEmpty ? '생성 중...' : '${s.mode} 생성 중',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: s.total > 0 ? s.step / s.total : null,
              backgroundColor: Colors.white12,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          if (s.total > 0)
            Text('${s.step} / ${s.total} steps',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
          Text('경과 ${s.elapsed.toStringAsFixed(1)}초',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          if (s.eta > 0)
            Text('약 ${s.eta.toStringAsFixed(0)}초 후 완료',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => genService.cancel(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('취소'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(GenState s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(s.images.first,
                  fit: BoxFit.cover, width: double.infinity),
            ),
          const SizedBox(height: 8),
          Text('seed: ${s.lastSeed}',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
          if (s.generationTime.isNotEmpty)
            Text(s.generationTime,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
          if (s.mode.isNotEmpty)
            Text(s.mode,
                style:
                    const TextStyle(color: Colors.white24, fontSize: 10)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => genService.reset(),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white38,
                  textStyle: const TextStyle(fontSize: 12)),
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(GenState s) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
              SizedBox(width: 6),
              Text('오류 발생',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.errorMessage,
            style:
                const TextStyle(color: Colors.redAccent, fontSize: 11),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => genService.reset(),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  textStyle: const TextStyle(fontSize: 12)),
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }
}
