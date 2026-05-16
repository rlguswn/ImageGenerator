import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'api_service.dart';

enum GenStatus { idle, generating, done, error }

class GenState {
  final GenStatus status;
  final String mode;
  final int step;
  final int total;
  final double elapsed;
  final double eta;
  final List<Uint8List> images;
  final int lastSeed;
  final String generationTime;
  final String errorMessage;

  const GenState({
    this.status = GenStatus.idle,
    this.mode = '',
    this.step = 0,
    this.total = 0,
    this.elapsed = 0.0,
    this.eta = 0.0,
    this.images = const [],
    this.lastSeed = -1,
    this.generationTime = '',
    this.errorMessage = '',
  });

  bool get isActive => status == GenStatus.generating;
  bool get isDone => status == GenStatus.done;
  bool get isError => status == GenStatus.error;

  GenState copyWith({
    GenStatus? status,
    String? mode,
    int? step,
    int? total,
    double? elapsed,
    double? eta,
    List<Uint8List>? images,
    int? lastSeed,
    String? generationTime,
    String? errorMessage,
  }) =>
      GenState(
        status: status ?? this.status,
        mode: mode ?? this.mode,
        step: step ?? this.step,
        total: total ?? this.total,
        elapsed: elapsed ?? this.elapsed,
        eta: eta ?? this.eta,
        images: images ?? this.images,
        lastSeed: lastSeed ?? this.lastSeed,
        generationTime: generationTime ?? this.generationTime,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class GenerationService {
  static final instance = GenerationService._();
  GenerationService._();

  final notifier = ValueNotifier<GenState>(const GenState());

  Timer? _elapsedTimer;
  Timer? _progressTimer;

  GenState get state => notifier.value;

  Future<void> run({
    required String mode,
    required Future<Map<String, dynamic>> Function() apiCall,
  }) async {
    if (state.isActive) return;

    notifier.value = GenState(status: GenStatus.generating, mode: mode);

    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!state.isActive) return;
      notifier.value = state.copyWith(elapsed: state.elapsed + 0.1);
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!state.isActive) return;
      try {
        final p = await api.getProgress();
        if (!state.isActive) return;
        notifier.value = state.copyWith(
          step: p['step'] as int? ?? state.step,
          total: p['total'] as int? ?? state.total,
          eta: (p['eta'] as num?)?.toDouble() ?? state.eta,
        );
      } catch (_) {}
    });

    try {
      final result = await apiCall();
      _stopTimers();
      if (!state.isActive) return; // cancel() was called while waiting

      final images = _parseImages(result);
      final seed = result['seed'] as int? ?? -1;
      final gt = result['generation_time'];
      final genTime = gt != null ? '$gt초' : '';

      notifier.value = state.copyWith(
        status: GenStatus.done,
        images: images,
        lastSeed: seed,
        generationTime: genTime,
      );

      final label = const {
        'txt2img': 'txt2img',
        'img2img': 'img2img',
        'inpaint': '인페인트',
      }[mode] ?? mode;
      LocalNotification(
        title: 'ImageGenerator',
        body: '$label 생성 완료 (${images.length}장, seed: $seed)',
      ).show();
    } catch (e) {
      _stopTimers();
      if (!state.isActive) return; // cancel() was called, discard error
      notifier.value = state.copyWith(
        status: GenStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> cancel() async {
    _stopTimers();
    notifier.value = const GenState(); // reset to idle immediately before await
    try {
      await api.cancelGeneration();
    } catch (_) {}
  }

  void reset() {
    notifier.value = const GenState();
  }

  void _stopTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  List<Uint8List> _parseImages(Map<String, dynamic> result) {
    if (result['images'] is List) {
      return (result['images'] as List)
          .whereType<String>()
          .map((b64) {
            try {
              return base64Decode(b64);
            } catch (_) {
              return Uint8List(0);
            }
          })
          .where((b) => b.isNotEmpty)
          .toList();
    }
    return [];
  }
}

final genService = GenerationService.instance;
