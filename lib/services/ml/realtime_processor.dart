import 'dart:async';

import '../ble/ble_receiver.dart';
import '../ble/sensor_frame.dart';
import 'preprocessing.dart';
import 'tflite_predictor.dart';

/// Result of a single inference window.
class PredictionResult {
  const PredictionResult({
    required this.posture,
    required this.confidence,
    required this.probabilities,
    required this.timestamp,
  });

  /// 1-based posture class (1..6).
  final int posture;

  /// Confidence of the top class (0..1).
  final double confidence;

  /// Full softmax output for all 6 classes.
  final List<double> probabilities;

  final DateTime timestamp;
}

/// Port of separate_realtime_predict.py — syncs raw [SensorRow] events across
/// all 4 sensors into wide-format rows, accumulates a rolling buffer, and runs
/// windowed TFLite inference every [triggerEvery] synced rows.
///
/// Call [start] after creating. Subscribe to [predictions] for results.
/// Call [stop] to clean up.
class RealtimeProcessor {
  RealtimeProcessor({
    int triggerEvery = 25,
    int winLen = TflitePredictor.winLen,
  })  : _triggerEvery = triggerEvery,
        _winLen = winLen;

  final int _triggerEvery;
  final int _winLen;

  final _predController = StreamController<PredictionResult>.broadcast();
  Stream<PredictionResult> get predictions => _predController.stream;

  // Emits per-sensor raw quaternions [q0,q1,q2,q3] on every 4-sensor sync.
  // Used by SpineViewTab for live spine visualization without going through
  // the full ML preprocessing pipeline.
  final _quatController = StreamController<Map<String, List<double>>>.broadcast();
  Stream<Map<String, List<double>>> get latestQuats => _quatController.stream;

  // Sensor label → latest row for that sensor in this "sync round"
  final Map<String, Map<String, double>> _latest = {};
  // All 4-sensor synced wide rows
  final List<Map<String, double>> _buffer = [];

  int _syncedSinceLastInfer = 0;

  BleReceiver? _bleReceiver;
  StreamSubscription<SensorRow>? _rowSub;
  TflitePredictor? _predictor;

  bool _running = false;
  bool _inferring = false;

  static const List<String> _sensorOrder = Preprocessing.sensors; // L5, T4, C7, T12

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _predictor = await TflitePredictor.instance();

    _bleReceiver = BleReceiver();
    _rowSub = _bleReceiver!.rows.listen(_onRow);
    await _bleReceiver!.start();
  }

  Future<void> stop() async {
    _running = false;
    await _rowSub?.cancel();
    await _bleReceiver?.stop();
    _latest.clear();
    _buffer.clear();
    _syncedSinceLastInfer = 0;
    _inferring = false;
  }


  void dispose() {
    stop();
    _predController.close();
    _quatController.close();
    _bleReceiver?.dispose();
    _predictor?.dispose();
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  void _onRow(SensorRow row) {
    _latest[row.sensorId] = row.toWideColumns();

    // Only proceed when we have a fresh reading from all 4 sensors
    if (_latest.length < _sensorOrder.length) return;
    if (!_sensorOrder.every(_latest.containsKey)) return;

    // Build one merged wide-format row
    final merged = <String, double>{};
    for (final s in _sensorOrder) {
      merged.addAll(_latest[s]!);
    }
    _buffer.add(merged);
    _latest.clear(); // reset for next sync round

    // Emit raw quaternions for spine visualization on every sync.
    if (!_quatController.isClosed) {
      final quats = <String, List<double>>{};
      for (final s in _sensorOrder) {
        quats[s] = [
          merged['${s}_Quaternions 0()'] ?? 1.0,
          merged['${s}_Quaternions 1()'] ?? 0.0,
          merged['${s}_Quaternions 2()'] ?? 0.0,
          merged['${s}_Quaternions 3()'] ?? 0.0,
        ];
      }
      _quatController.add(quats);
    }

    _syncedSinceLastInfer++;

    if (_syncedSinceLastInfer >= _triggerEvery && !_inferring) {
      _syncedSinceLastInfer = 0;
      _maybeInfer();
    }
  }

  Future<void> _maybeInfer() async {
    if (_inferring || _predictor == null) return;
    if (_buffer.length < _winLen) return; // not enough data yet

    _inferring = true;

    // Take a snapshot — enough context for the filter (winLen + 50)
    final snapshot = _buffer.length > _winLen + 50
        ? List<Map<String, double>>.from(_buffer.sublist(_buffer.length - (_winLen + 50)))
        : List<Map<String, double>>.from(_buffer);

    // Trim buffer to avoid unbounded growth
    if (_buffer.length > _winLen + 200) {
      _buffer.removeRange(0, _buffer.length - (_winLen + 200));
    }

    try {
      var window = Preprocessing.preprocessWindow(snapshot, _winLen);

      window = Preprocessing.applySensorNorm(
        window,
        _predictor!.means,
        _predictor!.stds,
      );

      final probs = _predictor!.predict(window);

      double maxP = 0;
      int maxIdx = 0;
      for (int i = 0; i < probs.length; i++) {
        if (probs[i] > maxP) {
          maxP = probs[i];
          maxIdx = i;
        }
      }

      if (!_predController.isClosed) {
        _predController.add(PredictionResult(
          posture: maxIdx + 1, // 1-based
          confidence: maxP,
          probabilities: probs,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      // log but don't crash the pipeline
      // ignore: avoid_print
      print('[RealtimeProcessor] inference error: $e');
    } finally {
      _inferring = false;
    }
  }
}
