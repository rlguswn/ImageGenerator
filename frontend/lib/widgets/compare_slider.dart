import 'dart:typed_data';
import 'package:flutter/material.dart';

class CompareSlider extends StatefulWidget {
  final Uint8List before;
  final Uint8List after;
  const CompareSlider({super.key, required this.before, required this.after});

  @override
  State<CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<CompareSlider> {
  double _fraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final divX = w * _fraction;

      return GestureDetector(
        onHorizontalDragUpdate: (d) {
          setState(() {
            _fraction = ((_fraction * w + d.delta.dx) / w).clamp(0.0, 1.0);
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black87),
            Image.memory(widget.after, fit: BoxFit.contain),
            ClipRect(
              clipper: _SplitClipper(divX),
              child: Image.memory(widget.before, fit: BoxFit.contain),
            ),
            Positioned(
              left: divX - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.white),
            ),
            Positioned(
              left: divX - 16,
              top: h / 2 - 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.compare_arrows,
                    size: 18, color: Colors.black54),
              ),
            ),
            Positioned(left: 8, bottom: 8, child: _label('원본')),
            Positioned(right: 8, bottom: 8, child: _label('결과')),
          ],
        ),
      );
    });
  }

  Widget _label(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child:
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}

class _SplitClipper extends CustomClipper<Rect> {
  final double splitX;
  _SplitClipper(this.splitX);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, splitX, size.height);

  @override
  bool shouldReclip(_SplitClipper old) => old.splitX != splitX;
}
