import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_paths.dart';
import 'startup_screen.dart';

class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  final _scrollCtrl = ScrollController();
  bool _scrolledToBottom = false;
  bool _agreed = false;
  String _eulaText = '';

  @override
  void initState() {
    super.initState();
    _loadEula();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEula() async {
    // 배포 환경: exe 옆 EULA.txt
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final distFile = File('$exeDir${Platform.pathSeparator}EULA.txt');
    // 개발 환경: 프로젝트 루트 EULA.txt
    final devFile = File('${findProjectRoot()}${Platform.pathSeparator}EULA.txt');

    String text = '';
    if (distFile.existsSync()) {
      text = distFile.readAsStringSync(encoding: utf8);
    } else if (devFile.existsSync()) {
      text = devFile.readAsStringSync(encoding: utf8);
    } else {
      text = '(EULA.txt 파일을 찾을 수 없습니다. 소프트웨어 폴더를 확인하세요.)';
    }
    if (mounted) setState(() => _eulaText = text);
  }

  void _onScroll() {
    if (_scrolledToBottom) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 40) {
      setState(() => _scrolledToBottom = true);
    }
  }

  void _saveAcceptance() {
    final root = findProjectRoot();
    final eulaFile = File('$root${Platform.pathSeparator}eula.json');
    eulaFile.writeAsStringSync(
      jsonEncode({
        'accepted': true,
        'accepted_at': DateTime.now().toIso8601String(),
        'version': '1.0',
      }),
    );
  }

  void _decline() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('사용 불가', style: TextStyle(color: Colors.white)),
        content: const Text(
          'EULA에 동의하지 않으면 소프트웨어를 사용할 수 없습니다.\n앱을 종료합니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => exit(0),
            child: const Text('종료', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _accept() {
    _saveAcceptance();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StartupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          // 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF16213E),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('최종 사용자 라이선스 계약',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('End User License Agreement (EULA)',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                SizedBox(height: 8),
                Text(
                  '소프트웨어를 사용하기 전에 아래 약관을 끝까지 읽어주세요.\n'
                  '끝까지 스크롤한 후 동의 버튼이 활성화됩니다.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

          // 약관 본문
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Scrollbar(
                controller: _scrollCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _eulaText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 스크롤 안내
          if (!_scrolledToBottom)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 16),
                  SizedBox(width: 4),
                  Text('끝까지 스크롤하면 동의 버튼이 활성화됩니다',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),

          // 동의 체크박스
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: _scrolledToBottom
                  ? () => setState(() => _agreed = !_agreed)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: _scrolledToBottom
                        ? (v) => setState(() => _agreed = v ?? false)
                        : null,
                    activeColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '위 최종 사용자 라이선스 계약의 모든 조항을 읽었으며, 이에 동의합니다.',
                      style: TextStyle(
                        color:
                            _scrolledToBottom ? Colors.white70 : Colors.white24,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white38,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('동의 안 함'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_agreed && _scrolledToBottom) ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '동의하고 시작',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
