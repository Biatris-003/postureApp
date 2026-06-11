import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Prediction {
  const Prediction({
    required this.timestamp,
    required this.posture,
    required this.confidence,
    required this.source,
  });

  final String timestamp;
  final int posture;
  final double confidence;
  final String source;

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      timestamp: json['Time']?.toString() ?? '',
      posture: _parsePosture(json['Predicted posture']),
      confidence: _parseConfidence(json['Confidence']),
      source: json['Source']?.toString() ?? '',
    );
  }

  static int _parsePosture(dynamic rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt();
    }
    if (rawValue is String) {
      return int.tryParse(rawValue) ?? -1;
    }
    return -1;
  }

  static double _parseConfidence(dynamic rawValue) {
    if (rawValue is double) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    if (rawValue is String) {
      return double.tryParse(rawValue) ?? 0.0;
    }
    return 0.0;
  }

  @override
  String toString() {
    return 'Prediction(timestamp: $timestamp, posture: $posture, confidence: $confidence, source: $source)';
  }
}

class PredictionSocketService {
  PredictionSocketService({
    this.url = 'ws://10.0.2.2:9302',
    Duration reconnectDelay = const Duration(seconds: 2),
  }) : _reconnectDelay = reconnectDelay;

  final String url;
  final Duration _reconnectDelay;

  final StreamController<Prediction> _predictionController = StreamController<Prediction>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _isConnecting = false;
  int _reconnectAttempt = 0;

  Stream<Prediction> get predictions => _predictionController.stream;

  Future<void> connect() async {
    if (_isDisposed || _isConnecting) {
      return;
    }

    _isConnecting = true;
    _reconnectTimer?.cancel();

    try {
      developer.log('Connecting to prediction WebSocket at $url', name: 'PredictionSocketService');
      final channel = WebSocketChannel.connect(Uri.parse(url));
      if (_isDisposed) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      _reconnectAttempt = 0;
      developer.log('Connected', name: 'PredictionSocketService');

      _channelSubscription = channel.stream.listen(
        _handleMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: true,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Error connecting to prediction WebSocket at $url: $error',
        name: 'PredictionSocketService',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleMessage(dynamic message) {
    if (_isDisposed) {
      return;
    }

    try {
      final text = message is String ? message : message.toString();
      developer.log('Message received', name: 'PredictionSocketService');

      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        developer.log('Ignored non-map payload: $text', name: 'PredictionSocketService');
        return;
      }

      if (decoded['type']?.toString() != 'prediction') {
        developer.log('Ignored non-prediction payload: $decoded', name: 'PredictionSocketService');
        return;
      }

      final prediction = Prediction.fromJson(decoded);
      developer.log('Incoming prediction message: $prediction', name: 'PredictionSocketService');
      _predictionController.add(prediction);
    } catch (error, stackTrace) {
      developer.log(
        'Error parsing prediction payload: $message',
        name: 'PredictionSocketService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    developer.log(
      'Error: $error',
      name: 'PredictionSocketService',
      error: error,
      stackTrace: stackTrace,
    );
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _handleSocketDone() {
    developer.log('Disconnected', name: 'PredictionSocketService');
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) {
      return;
    }

    _reconnectAttempt += 1;
    developer.log(
      'Reconnecting attempt #$_reconnectAttempt in ${_reconnectDelay.inSeconds}s',
      name: 'PredictionSocketService',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      unawaited(connect());
    });
  }

  void _cleanupSocket() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    unawaited(_channel?.sink.close());
    _channel = null;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSocket();
    await _predictionController.close();
  }
}

final predictionSocketServiceProvider = Provider<PredictionSocketService>((ref) {
  final service = PredictionSocketService();
  unawaited(service.connect());
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final predictionStreamProvider = StreamProvider<Prediction>((ref) {
  final service = ref.watch(predictionSocketServiceProvider);
  return service.predictions;
});