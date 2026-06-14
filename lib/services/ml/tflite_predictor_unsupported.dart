import 'dart:convert';

import 'package:flutter/services.dart';

/// Web/unsupported fallback stub for the TflitePredictor.
/// Avoids importing 'tflite_flutter' which depends on 'dart:ffi'.
class TflitePredictor {
  TflitePredictor._();

  static TflitePredictor? _instance;

  static Future<TflitePredictor> instance() async {
    if (_instance != null) return _instance!;
    final p = TflitePredictor._();
    await p._load();
    _instance = p;
    return p;
  }

  late List<List<double>> _means; // 4 × 6
  late List<List<double>> _stds;  // 4 × 6

  List<List<double>> get means => _means;
  List<List<double>> get stds => _stds;

  static const int winLen = 200;
  static const int numFeatures = 24;
  static const int numClasses = 6;

  Future<void> _load() async {
    // Load normalisation stats (web-compatible asset loading)
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/loso_norm_stats.json');
      final stats = jsonDecode(jsonStr) as Map<String, dynamic>;
      _means = (stats['means'] as List)
          .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
          .toList();
      _stds = (stats['stds'] as List)
          .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
          .toList();
    } catch (e) {
      // Fallback in case asset is not available
      _means = List.generate(4, (_) => List.filled(6, 0.0));
      _stds = List.generate(4, (_) => List.filled(6, 1.0));
    }
  }

  /// Runs mock inference.
  /// Returns a list of 6 class probabilities (sum ≈ 1) representing optimal posture.
  List<double> predict(List<List<double>> window) {
    // Return mock prediction where index 0 is 1.0 (Optimal Posture)
    final output = List<double>.filled(numClasses, 0.0);
    output[0] = 1.0; 
    return output;
  }

  void dispose() {
    _instance = null;
  }
}
