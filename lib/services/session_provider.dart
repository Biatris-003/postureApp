import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prediction_socket_service.dart';

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

// Score weight per posture (0–100). Used to compute session score.
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
  });

  final int posture;
  final String name;
  final DateTime timestamp;
}

class SessionState {
  const SessionState({
    this.status = SessionStatus.idle,
    this.startTime,
    this.lastPrediction,
    this.timeline = const [],
  });

  final SessionStatus status;
  final DateTime? startTime;
  final Prediction? lastPrediction;
  final List<PostureEvent> timeline;

  Duration get elapsed =>
      startTime == null ? Duration.zero : DateTime.now().difference(startTime!);

  /// Percentage (0–100) for each posture id seen this session.
  Map<int, double> get posturePercentages {
    if (timeline.isEmpty) return {};
    final counts = <int, int>{};
    for (final e in timeline) {
      counts[e.posture] = (counts[e.posture] ?? 0) + 1;
    }
    final total = timeline.length;
    return counts.map((k, v) => MapEntry(k, v / total * 100));
  }

  /// Weighted average score 0–100.
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
    Prediction? lastPrediction,
    List<PostureEvent>? timeline,
  }) {
    return SessionState(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      lastPrediction: lastPrediction ?? this.lastPrediction,
      timeline: timeline ?? this.timeline,
    );
  }
}

/// Immutable snapshot produced when a session ends.
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
  StreamSubscription<Prediction>? _sub;

  @override
  SessionState build() {
    ref.onDispose(() => _sub?.cancel());
    return const SessionState();
  }

  void startSession() {
    _sub?.cancel();
    state = SessionState(
      status: SessionStatus.starting,
      startTime: DateTime.now(),
    );
    _sub = ref
        .read(predictionSocketServiceProvider)
        .predictions
        .listen(_onPrediction);
  }

  void _onPrediction(Prediction p) {
    if (state.status == SessionStatus.idle) return;
    final event = PostureEvent(
      posture: p.posture,
      name: postureNames[p.posture] ?? 'Unknown',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      status: SessionStatus.active,
      lastPrediction: p,
      timeline: [...state.timeline, event],
    );
  }

  /// Stops the session and returns the accumulated data.
  SessionData stopSession() {
    _sub?.cancel();
    _sub = null;
    final data = SessionData(
      startTime: state.startTime ?? DateTime.now(),
      endTime: DateTime.now(),
      posturePercentages: state.posturePercentages,
      timeline: state.timeline,
      sessionScore: state.sessionScore,
    );
    state = const SessionState();
    return data;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
