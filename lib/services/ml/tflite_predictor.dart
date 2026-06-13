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

  static Future<TflitePredictor> instance() async {
    if (_instance != null) return _instance!;
    final p = TflitePredictor._();
    await p._load();
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
    // Load TFLite model
    final options = InterpreterOptions()..threads = 2;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/loso_model.tflite',
      options: options,
    );

    smokeTest();

    // Load normalisation stats
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
    // Shape: [1, 200, 24]
    final input = [window.map((row) => row.map((v) => v.toDouble()).toList()).toList()];
    final output = [List<double>.filled(numClasses, 0.0)];
    _interpreter.run(input, output);
    // ignore: avoid_print
    print('[TFL] probs: ${output[0].map((v) => v.toStringAsFixed(4)).toList()} sum=${output[0].fold(0.0, (a, b) => a + b).toStringAsFixed(4)}');
    return output[0];
  }

  /// Smoke-test: runs two contrasting inputs and prints results.
  void smokeTest() {
    // Test A: all zeros
    final zeroWindow = List.generate(winLen, (_) => List<double>.filled(numFeatures, 0.0));
    final outA = [List<double>.filled(numClasses, 0.0)];
    _interpreter.run([zeroWindow], outA);
    // ignore: avoid_print
    print('[TFL-SMOKE] zeros  → ${outA[0].map((v) => v.toStringAsFixed(4)).toList()}');

    // Test B: all ones
    final oneWindow = List.generate(winLen, (_) => List<double>.filled(numFeatures, 1.0));
    final outB = [List<double>.filled(numClasses, 0.0)];
    _interpreter.run([oneWindow], outB);
    // ignore: avoid_print
    print('[TFL-SMOKE] ones   → ${outB[0].map((v) => v.toStringAsFixed(4)).toList()}');

    // Test C: all negative-one
    final negWindow = List.generate(winLen, (_) => List<double>.filled(numFeatures, -1.0));
    final outC = [List<double>.filled(numClasses, 0.0)];
    _interpreter.run([negWindow], outC);
    // ignore: avoid_print
    print('[TFL-SMOKE] neg-1  → ${outC[0].map((v) => v.toStringAsFixed(4)).toList()}');
  }

  void dispose() {
    _interpreter.close();
    _instance = null;
  }
}
