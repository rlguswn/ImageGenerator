import 'package:flutter/foundation.dart';

class RegenPayload {
  final String mode; // 'txt2img' | 'img2img'
  final Map<String, dynamic> state;
  const RegenPayload(this.mode, this.state);
}

final regenNotifier = ValueNotifier<RegenPayload?>(null);
