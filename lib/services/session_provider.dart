import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ml/realtime_processor.dart';

const Map<int, String> postureNames = {
  1: 'Backward Bending',
  2: 'Upright',
  3: 'Slouching',
  4: 'Forward Bending',
  5: 'Right Bending',
  6: 'Left Bending',
};

const Map<int, Color> postureColors = {
  1: Color(0xFF8B5CF6),
  2: Color(0xFF10B981),
  3: Color(0xFFEF4444),
  4: Color(0xFFF59E0B),
  5: Color(0xFF06B6D4),
  6: Color(0xFF3B82F6),
};

const Map<int, double> _postureWeights = {
  1: 30.0,
  2: 100.0,
  3: 0.0,
  4: 30.0,
  5: 40.0,
  6: 40.0,
};

enum SessionStatus { idle, starting, active }

class PostureEvent {
  const PostureEvent({
    required this.posture,
    required this.name,
    required this.timestamp,
    required this.confidence,
  });

  final int posture;
  final String name;
  final DateTime timestamp;
  final double confidence;
}

class SessionState {
  const SessionState({
    this.status = SessionStatus.idle,
    this.startTime,
    this.lastPosture,
    this.lastConfidence,
    this.timeline = const [],
  });

  final SessionStatus status;
  final DateTime? startTime;
  final int? lastPosture;
  final double? lastConfidence;
  final List<PostureEvent> timeline;

  Duration get elapsed =>
      startTime == null ? Duration.zero : DateTime.now().difference(startTime!);

  Map<int, double> get posturePercentages {
    if (timeline.isEmpty) return {};
    final counts = <int, int>{};
    for (final e in timeline) {
      counts[e.posture] = (counts[e.posture] ?? 0) + 1;
    }
    final total = timeline.length;
    return counts.map((k, v) => MapEntry(k, v / total * 100));
  }

  double get sessionScore {
    if (timeline.isEmpty) return 0;
    var total = 0.0;
    for (final e in timeline) {
      total += _postureWeights[e.posture] ?? 0;
    }
    return total / timeline.length;
  }

  SessionState copyWith({
    SessionStatus? status,
    DateTime? startTime,
    int? lastPosture,
    double? lastConfidence,
    List<PostureEvent>? timeline,
  }) {
    return SessionState(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      lastPosture: lastPosture ?? this.lastPosture,
      lastConfidence: lastConfidence ?? this.lastConfidence,
      timeline: timeline ?? this.timeline,
    );
  }
}

class SessionData {
  const SessionData({
    required this.startTime,
    required this.endTime,
    required this.posturePercentages,
    required this.timeline,
    required this.sessionScore,
  });

  final DateTime startTime;
  final DateTime endTime;
  final Map<int, double> posturePercentages;
  final List<PostureEvent> timeline;
  final double sessionScore;

  Duration get duration => endTime.difference(startTime);
}

class SessionNotifier extends Notifier<SessionState> {
  RealtimeProcessor? _processor;
  StreamSubscription<PredictionResult>? _sub;

  @override
  SessionState build() {
    ref.onDispose(_cleanup);
    return const SessionState();
  }

  Future<void> startSession() async {
    await _cleanup();
    state = SessionState(
      status: SessionStatus.starting,
      startTime: DateTime.now(),
    );

    _processor = RealtimeProcessor();
    await _processor!.start();

    _sub = _processor!.predictions.listen(_onPrediction);
  }

  void _onPrediction(PredictionResult result) {
    if (state.status == SessionStatus.idle) return;
    final event = PostureEvent(
      posture: result.posture,
      name: postureNames[result.posture] ?? 'Unknown',
      timestamp: result.timestamp,
      confidence: result.confidence,
    );
    state = state.copyWith(
      status: SessionStatus.active,
      lastPosture: result.posture,
      lastConfidence: result.confidence,
      timeline: [...state.timeline, event],
    );
  }

  SessionData stopSession() {
    final data = SessionData(
      startTime: state.startTime ?? DateTime.now(),
      endTime: DateTime.now(),
      posturePercentages: state.posturePercentages,
      timeline: state.timeline,
      sessionScore: state.sessionScore,
    );
    _cleanup();
    state = const SessionState();
    return data;
  }

  Future<void> _cleanup() async {
    await _sub?.cancel();
    _sub = null;
    await _processor?.stop();
    _processor?.dispose();
    _processor = null;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
