import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/analytics_service.dart';
import '../data/datasources/auth_service_mock.dart';
import '../providers/user_settings_provider.dart';
import '../providers/weekly_posture_counts_provider.dart';
import 'ble/ble_monitor_provider.dart';
import 'ml/realtime_processor.dart';
import 'posture_notification_service.dart';

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

const Map<int, String> _postureLabels = {
  1: 'backward_bending',
  2: 'upright',
  3: 'slouching',
  4: 'forward_bending',
  5: 'right_bending',
  6: 'left_bending',
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
    this.lastProbabilities,
    this.timeline = const [],
    this.bestStreakSeconds = 0,
    this.currentStreakStart,
    this.sensorBatteryLevels = const {},
    this.sensorConnections = const {},
  });

  final SessionStatus status;
  final DateTime? startTime;
  final int? lastPosture;
  final double? lastConfidence;
  // Full softmax output — used to compute deviation from upright for non-upright postures.
  final List<double>? lastProbabilities;
  final List<PostureEvent> timeline;
  // Peak upright streak from completed streaks (seconds). Frozen when a streak ends.
  final int bestStreakSeconds;
  // Start time of the current upright streak; null when not in upright.
  final DateTime? currentStreakStart;
  final Map<String, int> sensorBatteryLevels;
  final Map<String, bool> sensorConnections;

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

  // Number of times the classified posture changed.
  int get postureChanges {
    if (timeline.length < 2) return 0;
    int changes = 0;
    for (int i = 1; i < timeline.length; i++) {
      if (timeline[i].posture != timeline[i - 1].posture) changes++;
    }
    return changes;
  }

  SessionState copyWith({
    SessionStatus? status,
    DateTime? startTime,
    int? lastPosture,
    double? lastConfidence,
    List<double>? lastProbabilities,
    List<PostureEvent>? timeline,
    int? bestStreakSeconds,
    DateTime? currentStreakStart,
    bool clearCurrentStreakStart = false,
    Map<String, int>? sensorBatteryLevels,
    Map<String, bool>? sensorConnections,
  }) {
    return SessionState(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      lastPosture: lastPosture ?? this.lastPosture,
      lastConfidence: lastConfidence ?? this.lastConfidence,
      lastProbabilities: lastProbabilities ?? this.lastProbabilities,
      timeline: timeline ?? this.timeline,
      bestStreakSeconds: bestStreakSeconds ?? this.bestStreakSeconds,
      currentStreakStart: clearCurrentStreakStart
          ? null
          : (currentStreakStart ?? this.currentStreakStart),
      sensorBatteryLevels: sensorBatteryLevels ?? this.sensorBatteryLevels,
      sensorConnections: sensorConnections ?? this.sensorConnections,
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
    required this.bestStreakSeconds,
  });

  final DateTime startTime;
  final DateTime endTime;
  final Map<int, double> posturePercentages;
  final List<PostureEvent> timeline;
  final double sessionScore;
  final int bestStreakSeconds;

  Duration get duration => endTime.difference(startTime);
}

/// Holds the latest per-sensor raw quaternions [q0,q1,q2,q3] from the active
/// session's BLE sync. Null when no session is running.
/// Updated at the BLE data rate (every sync), so SpineViewTab can animate
/// the spine without going through the ML preprocessing pipeline.
class LatestQuatsNotifier extends Notifier<Map<String, List<double>>?> {
  @override
  Map<String, List<double>>? build() => null;

  void update(Map<String, List<double>>? quats) => state = quats;
}

final latestQuatsProvider =
    NotifierProvider<LatestQuatsNotifier, Map<String, List<double>>?>(
      LatestQuatsNotifier.new,
    );

class SessionNotifier extends Notifier<SessionState> {
  static const int _firstPostureAlertSeconds = 20;
  static const int _secondPostureAlertSeconds =
      _firstPostureAlertSeconds + 60;
  static const int _thirdPostureAlertSeconds =
      _secondPostureAlertSeconds + 120;
  static const Duration _normalResetDelay = Duration(seconds: 10);
  static const Duration _frequentAlertWindow = Duration(minutes: 30);
  static const Duration _movementReminderInterval = Duration(minutes: 60);

  RealtimeProcessor? _processor;
  StreamSubscription<PredictionResult>? _sub;
  StreamSubscription<Map<String, List<double>>>? _quatSub;
  final PostureNotificationService _notificationService =
      PostureNotificationService();
  String? _activePatientId;
  String? _sessionTrackingId;
  String? _lastSessionTrackingId;
  int? _currentBadPosture;
  DateTime? _currentBadPostureStartedAt;
  DateTime? _normalStartedAt;
  DateTime? _nextMovementReminderAt;
  bool _frequentAlertSent = false;
  final Map<int, int> _postureNotificationCounts = {};
  final List<DateTime> _postureAlertTimestamps = [];

  @override
  SessionState build() {
    ref.onDispose(_cleanup);

    ref.listen<Map<String, bool>>(enabledSensorsProvider, (prev, next) {
      if (_processor != null) {
        final enabledMacs = next.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toSet();
        _processor!.updateEnabledSensors(enabledMacs);
      }
    });

    ref.listen<BleMonitorState>(bleMonitorProvider, (prev, next) {
      if (state.status != SessionStatus.idle) {
        state = state.copyWith(
          sensorBatteryLevels: next.batteryLevels,
          sensorConnections: next.connections,
        );
      }
    });

    return const SessionState();
  }

  // ── Helper: read current user settings without relying on valueOrNull ──
  // Mirrors the .when(...) pattern already used in SettingsTab, so it works
  // regardless of the installed flutter_riverpod version.
  bool _vibrationFeedbackEnabled() {
    return ref.read(userSettingsProvider).when(
      data: (value) => value.vibrationFeedback,
      loading: () => true,
      error: (_, __) => true,
    );
  }

  bool _dailySummaryEnabled() {
    return ref.read(userSettingsProvider).when(
      data: (value) => value.dailySummary,
      loading: () => true,
      error: (_, __) => true,
    );
  }

  // Future<void> startSession() async {
  //   await _cleanup();
  //   final initialMonitor = ref.read(bleMonitorProvider);
  //   final startedAt = DateTime.now();
  //   _resetSessionNotificationTracking(startedAt: startedAt);
  //   _activePatientId = await _resolveCurrentPatientId();
  //   _sessionTrackingId = 'monitoring_${startedAt.millisecondsSinceEpoch}';
  //   state = SessionState(
  //     status: SessionStatus.starting,
  //     startTime: startedAt,
  //     sensorBatteryLevels: initialMonitor.batteryLevels,
  //     sensorConnections: initialMonitor.connections,
  //   );

  Future<void> startSession() async {
    await _cleanup();
    // Roll a fresh batch of (simulated) per-sensor battery levels for this
    // session. They stay frozen until the next time a session starts.
    ref.read(bleMonitorProvider.notifier).rollFakeBatteryLevels();
    final initialMonitor = ref.read(bleMonitorProvider);
    final startedAt = DateTime.now();
    _resetSessionNotificationTracking(startedAt: startedAt);
    _activePatientId = await _resolveCurrentPatientId();
    _sessionTrackingId = 'monitoring_${startedAt.millisecondsSinceEpoch}';
    state = SessionState(
      status: SessionStatus.starting,
      startTime: startedAt,
      sensorBatteryLevels: initialMonitor.batteryLevels,
      sensorConnections: initialMonitor.connections,
    );
    // ...rest unchanged

    // Get the shared BleReceiver from the persistent monitor
    final bleReceiver = ref.read(bleMonitorProvider.notifier).bleReceiver;

    _processor = RealtimeProcessor(bleReceiver: bleReceiver);

    // Read the current enabled configuration
    final enabledSensors = ref.read(enabledSensorsProvider);
    final enabledMacs = enabledSensors.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    await _processor!.start(enabledMacs: enabledMacs);

    _sub = _processor!.predictions.listen(_onPrediction);
    _quatSub = _processor!.latestQuats.listen((quats) {
      ref.read(latestQuatsProvider.notifier).update(quats);
    });

    // Battery and connection data are now provided by bleMonitorProvider.
    // The session still copies them into SessionState for backward
    // compatibility with other screens that read from sessionProvider.
    // This is updated dynamically by the listener configured in [build].
  }

  void _onPrediction(PredictionResult result) {
    if (state.status == SessionStatus.idle) return;
    final now = result.timestamp;
    _handlePostureNotificationTiming(result.posture, now);
    _handleMovementBreakReminder(now);
    final event = PostureEvent(
      posture: result.posture,
      name: postureNames[result.posture] ?? 'Unknown',
      timestamp: now,
      confidence: result.confidence,
    );

    final streakStart = state.currentStreakStart;
    var newBest = state.bestStreakSeconds;
    DateTime? nextStreakStart;
    bool clearStreak = false;

    if (result.posture == 2) {
      nextStreakStart = streakStart ?? now; // start or continue
    } else {
      if (streakStart != null) {
        final dur = now.difference(streakStart).inSeconds;
        if (dur > newBest) newBest = dur;
      }
      clearStreak = true;
    }

    state = state.copyWith(
      status: SessionStatus.active,
      lastPosture: result.posture,
      lastConfidence: result.confidence,
      lastProbabilities: result.probabilities,
      timeline: [...state.timeline, event],
      bestStreakSeconds: newBest,
      currentStreakStart: nextStreakStart,
      clearCurrentStreakStart: clearStreak,
    );
  }

  Future<String?> _resolveCurrentPatientId() async {
    final user = ref.read(authStateProvider);
    if (user == null) return null;
    final analytics = AnalyticsService();
    return analytics.resolvePatientId(
      firebaseUid: user.userId,
      legacyUserId: user.uid,
    );
  }

  void _resetPostureNotificationTracking() {
    _currentBadPosture = null;
    _currentBadPostureStartedAt = null;
    _normalStartedAt = null;
    _postureNotificationCounts.clear();
  }

  void _resetSessionNotificationTracking({DateTime? startedAt}) {
    _resetPostureNotificationTracking();
    _frequentAlertSent = false;
    _postureAlertTimestamps.clear();
    final base = startedAt ?? DateTime.now();
    _nextMovementReminderAt = base.add(_movementReminderInterval);
  }

  void _handlePostureNotificationTiming(int posture, DateTime now) {
    if (posture == 2) {
      _currentBadPosture = null;
      _currentBadPostureStartedAt = null;
      _normalStartedAt ??= now;

      if (now.difference(_normalStartedAt!) >= _normalResetDelay) {
        _resetPostureNotificationTracking();
        _normalStartedAt = now;
      }
      return;
    }

    _normalStartedAt = null;
    if (!_isBadPosture(posture)) return;

    if (_currentBadPosture != posture) {
      _currentBadPosture = posture;
      _currentBadPostureStartedAt = now;
    }

    final badStartedAt = _currentBadPostureStartedAt;
    if (badStartedAt == null) return;

    final heldSeconds = now.difference(badStartedAt).inSeconds;
    final sentCount = _postureNotificationCounts[posture] ?? 0;

    if (sentCount == 0 && heldSeconds >= _firstPostureAlertSeconds) {
      _sendPostureNotification(posture, now, sequenceNumber: 1);
    } else if (sentCount == 1 && heldSeconds >= _secondPostureAlertSeconds) {
      _sendPostureNotification(posture, now, sequenceNumber: 2);
    } else if (sentCount == 2 && heldSeconds >= _thirdPostureAlertSeconds) {
      _sendPostureNotification(posture, now, sequenceNumber: 3);
    }
  }

  void _handleMovementBreakReminder(DateTime now) {
    final patientId = _activePatientId;
    final nextReminderAt = _nextMovementReminderAt;
    if (patientId == null || nextReminderAt == null) return;
    if (now.isBefore(nextReminderAt)) return;

    _notificationService.savePatientAlert(
      patientId: patientId,
      title: 'Time for a Movement Break',
      message:
          "You've been sitting for an extended period. Stand up, stretch, or walk for a few minutes before continuing your work.",
      alertType: 'movement_break',
      timestamp: now,
      sessionTrackingId: _sessionTrackingId,
      vibrate: _vibrationFeedbackEnabled(),
    );

    do {
      _nextMovementReminderAt =
          (_nextMovementReminderAt ?? now).add(_movementReminderInterval);
    } while (!_nextMovementReminderAt!.isAfter(now));
  }

  bool _isBadPosture(int posture) =>
      posture != 2 && _postureLabels.containsKey(posture);

  void _sendPostureNotification(
    int posture,
    DateTime now, {
    required int sequenceNumber,
  }) {
    final patientId = _activePatientId;
    final content = _notificationContent[posture];
    if (patientId == null || content == null) return;

    _postureNotificationCounts[posture] = sequenceNumber;
    final postureLabel = _postureLabels[posture];

    _notificationService.savePatientAlert(
      patientId: patientId,
      title: content.title,
      message: content.message,
      alertType: 'posture_correction',
      postureLabel: postureLabel,
      timestamp: now,
      sessionTrackingId: _sessionTrackingId,
      sequenceNumber: sequenceNumber,
      vibrate: _vibrationFeedbackEnabled(),
    );

    _postureAlertTimestamps.add(now);
    _removeOldPostureAlerts(now);
    if (!_frequentAlertSent && _postureAlertTimestamps.length >= 5) {
      _frequentAlertSent = true;
      _notificationService.savePatientAlert(
        patientId: patientId,
        title: 'Frequent Posture Corrections Needed',
        message:
            "We've noticed several posture alerts during this session. Consider taking a short standing, walking, or stretching break.",
        alertType: 'frequent_posture_corrections',
        timestamp: now,
        sessionTrackingId: _sessionTrackingId,
        vibrate: _vibrationFeedbackEnabled(),
      );
    }
  }

  void _removeOldPostureAlerts(DateTime now) {
    final cutoff = now.subtract(_frequentAlertWindow);
    _postureAlertTimestamps.removeWhere(
      (timestamp) => timestamp.isBefore(cutoff),
    );
  }

  SessionData stopSession() {
    // If user stops while in an upright streak, count it toward the best.
    final streakStart = state.currentStreakStart;
    final finalBest = streakStart != null
        ? () {
            final dur = DateTime.now().difference(streakStart).inSeconds;
            return dur > state.bestStreakSeconds
                ? dur
                : state.bestStreakSeconds;
          }()
        : state.bestStreakSeconds;

    final data = SessionData(
      startTime: state.startTime ?? DateTime.now(),
      endTime: DateTime.now(),
      posturePercentages: state.posturePercentages,
      timeline: state.timeline,
      sessionScore: state.sessionScore,
      bestStreakSeconds: finalBest,
    );
    _lastSessionTrackingId = _sessionTrackingId;
    _cleanup();
    state = const SessionState();
    _saveSessionToFirestore(data);
    return data;
  }

  Future<void> _saveSessionToFirestore(SessionData data) async {
    try {
      final user = ref.read(authStateProvider);
      if (user == null) return;

      final db = FirebaseFirestore.instance;
      final analytics = AnalyticsService();
      final patientId = await analytics.resolvePatientId(
        firebaseUid: user.userId,
        legacyUserId: user.uid,
      );
      if (patientId == null) return;

      final sessionRef = await db.collection('sessionResults').add({
        'patientId': patientId,
        'startTimestamp': Timestamp.fromDate(data.startTime),
        'endTimestamp': Timestamp.fromDate(data.endTime),
        'durationMinutes': data.duration.inMinutes,
        'sessionScore': data.sessionScore,
        'status': 'completed',
        'posturePercentages': data.posturePercentages.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      });

      final sessionTrackingId = _lastSessionTrackingId;
      if (sessionTrackingId != null) {
        await _notificationService.attachAlertsToSession(
          sessionTrackingId: sessionTrackingId,
          sessionId: sessionRef.id,
        );
      }

      // Write each prediction event to postureClassifications so the
      // analytics page has data to read. Split into 500-item batches.
      const chunkSize = 500;
      final timeline = data.timeline;
      for (int i = 0; i < timeline.length; i += chunkSize) {
        final chunk = timeline.sublist(
          i,
          (i + chunkSize).clamp(0, timeline.length),
        );
        final batch = db.batch();
        for (final event in chunk) {
          batch.set(db.collection('postureClassifications').doc(), {
            'patientId': patientId,
            'sessionId': sessionRef.id,
            'postureLabel': _postureLabels[event.posture] ?? 'unknown',
            'confidenceScore': event.confidence,
            'timestamp': Timestamp.fromDate(event.timestamp),
            'readingId': '',
            'modelId': 'loso_model',
          });
        }
        await batch.commit();
      }

      // Recalculate today's saved aggregate using every completed session
      // from today, then refresh the rolling weekly recommendations.
      final todayClassifications = await analytics.getClassificationsByDays(
        patientId,
        1,
      );
      if (todayClassifications.isNotEmpty) {
        await analytics.saveDailyStatistics(patientId, todayClassifications);
        if (_dailySummaryEnabled()) {
          await _notificationService.savePatientAlert(
            patientId: patientId,
            title: 'Daily Posture Summary Ready',
            message:
                'Your posture summary has been updated with today\'s latest session.',
            alertType: 'daily_summary',
            timestamp: DateTime.now(),
            sessionTrackingId: _sessionTrackingId,
            vibrate: _vibrationFeedbackEnabled(),
          );
        }
      }
      ref.invalidate(weeklyPostureCountsProvider);
    } catch (e) {
      debugPrint('[SessionNotifier] failed to save session: $e');
    }
  }

  Future<void> _cleanup() async {
    await _sub?.cancel();
    _sub = null;
    await _quatSub?.cancel();
    _quatSub = null;
    ref.read(latestQuatsProvider.notifier).update(null);
    await _processor?.stop();
    _processor?.dispose();
    _processor = null;
    _activePatientId = null;
    _sessionTrackingId = null;
    _resetSessionNotificationTracking();
  }
}

const Map<int, PostureNotificationContent> _notificationContent = {
  1: PostureNotificationContent(
    title: 'Backward Bending Detected',
    message:
        'You have been leaning backward for some time. Adjust your posture for better support.',
  ),
  3: PostureNotificationContent(
    title: 'Slouching Detected',
    message:
        'Your back appears rounded. Try straightening your spine and relaxing your shoulders.',
  ),
  4: PostureNotificationContent(
    title: 'Forward Bending Detected',
    message:
        'You have been leaning forward for a while. Gently return to an upright sitting position.',
  ),
  5: PostureNotificationContent(
    title: 'Right Leaning Detected',
    message:
        'You are leaning to the right. Try returning to a centered sitting position.',
  ),
  6: PostureNotificationContent(
    title: 'Left Leaning Detected',
    message:
        'You are leaning to the left. Try returning to a centered sitting position.',
  ),
};

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class EnabledSensorsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    return {
      'ED:35:33:D3:6C:F8': true, // C7
      'ED:40:FE:65:30:6C': true, // T4
      'F6:90:CC:01:6D:25': true, // T12
      'E3:CA:2D:FD:E0:8C': true, // L5
    };
  }

  void toggleSensor(String mac) {
    state = {...state, mac: !(state[mac] ?? true)};
  }
}

final enabledSensorsProvider =
    NotifierProvider<EnabledSensorsNotifier, Map<String, bool>>(
      EnabledSensorsNotifier.new,
    );