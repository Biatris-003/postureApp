import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Loads the LOSO TFLite model and norm stats from Flutter assets and runs
/// single-window inference.
///
/// Call [init] once before using [predict].
class TflitePredictor {
  TflitePredictor._();

  static TflitePredictor? _instance;
  bool _disposed = false;

  static Future<TflitePredictor> instance() async {
    if (_instance != null && !_instance!._disposed) return _instance!;
    final p = _instance ?? TflitePredictor._();
    await p._load();
    p._disposed = false;
    _instance = p;
    return p;
  }

  late Interpreter _interpreter;
  late List<List<double>> _means; // 4 × 6
  late List<List<double>> _stds;  // 4 × 6

  List<List<double>> get means => _means;
  List<List<double>> get stds => _stds;

  static const int winLen = 200;
  static const int numFeatures = 24;
  static const int numClasses = 6;

  Future<void> _load() async {
    final options = InterpreterOptions()..threads = 2;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/loso_model.tflite',
      options: options,
    );

    final jsonStr =
        await rootBundle.loadString('assets/models/loso_norm_stats.json');
    final stats = jsonDecode(jsonStr) as Map<String, dynamic>;
    _means = (stats['means'] as List)
        .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    _stds = (stats['stds'] as List)
        .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  /// Runs inference on one (winLen, 24) window.
  /// Returns a list of 6 class probabilities (sum ≈ 1).
  List<double> predict(List<List<double>> window) {
    final input = [window.map((row) => row.map((v) => v.toDouble()).toList()).toList()];
    final output = [List<double>.filled(numClasses, 0.0)];
    _interpreter.run(input, output);
    return output[0];
  }

  void dispose() {
    _interpreter.close();
    _disposed = true;
  }
}
