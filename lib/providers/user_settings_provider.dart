import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/auth_service_mock.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings model
// ─────────────────────────────────────────────────────────────────────────────
class UserSettings {
  final bool postureAlerts;
  final bool vibrationFeedback;
  final bool dailySummary;
  final bool darkModeOverride;
  final int alertThresholdMinutes;
  final bool isLoaded;

  const UserSettings({
    this.postureAlerts = true,
    this.vibrationFeedback = true,
    this.dailySummary = true,
    this.darkModeOverride = false,
    this.alertThresholdMinutes = 5,
    this.isLoaded = false,
  });

  UserSettings copyWith({
    bool? postureAlerts,
    bool? vibrationFeedback,
    bool? dailySummary,
    bool? darkModeOverride,
    int? alertThresholdMinutes,
    bool? isLoaded,
  }) =>
      UserSettings(
        postureAlerts: postureAlerts ?? this.postureAlerts,
        vibrationFeedback: vibrationFeedback ?? this.vibrationFeedback,
        dailySummary: dailySummary ?? this.dailySummary,
        darkModeOverride: darkModeOverride ?? this.darkModeOverride,
        alertThresholdMinutes:
            alertThresholdMinutes ?? this.alertThresholdMinutes,
        isLoaded: isLoaded ?? this.isLoaded,
      );

  Map<String, dynamic> toMap() => {
        'postureAlerts': postureAlerts,
        'vibrationFeedback': vibrationFeedback,
        'dailySummary': dailySummary,
        'darkModeOverride': darkModeOverride,
        'alertThresholdMinutes': alertThresholdMinutes,
      };

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        postureAlerts: map['postureAlerts'] as bool? ?? true,
        vibrationFeedback: map['vibrationFeedback'] as bool? ?? true,
        dailySummary: map['dailySummary'] as bool? ?? true,
        darkModeOverride: map['darkModeOverride'] as bool? ?? false,
        alertThresholdMinutes: (map['alertThresholdMinutes'] as num?)?.toInt() ?? 5,
        isLoaded: true,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier — loads from Firestore on build, persists on every change
// ─────────────────────────────────────────────────────────────────────────────
class UserSettingsNotifier extends AsyncNotifier<UserSettings> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<UserSettings> build() async {
    return await _load();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Resolves the patientId for the current user.
  Future<String?> _getPatientId() async {
    final user = ref.read(authStateProvider);
    if (user == null) return null;

    final snap = await _db
        .collection('patients')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<UserSettings> _load() async {
    try {
      final patientId = await _getPatientId();
      if (patientId == null) return const UserSettings(isLoaded: true);

      final doc = await _db
          .collection('patients')
          .doc(patientId)
          .collection('settings')
          .doc('preferences')
          .get();

      if (doc.exists && doc.data() != null) {
        return UserSettings.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('[UserSettings] load error: $e');
    }
    return const UserSettings(isLoaded: true);
  }

  Future<void> _save(UserSettings settings) async {
    try {
      final patientId = await _getPatientId();
      if (patientId == null) return;

      await _db
          .collection('patients')
          .doc(patientId)
          .collection('settings')
          .doc('preferences')
          .set(settings.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[UserSettings] save error: $e');
    }
  }

  // ── Public update methods ─────────────────────────────────────────────────

  UserSettings _current() {
    return state.when(
      data: (s) => s,
      loading: () => const UserSettings(),
      error: (err, st) => const UserSettings(),
    );
  }

  Future<void> setPostureAlerts(bool value) async {
    final updated = _current().copyWith(postureAlerts: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setVibrationFeedback(bool value) async {
    final updated = _current().copyWith(vibrationFeedback: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setDailySummary(bool value) async {
    final updated = _current().copyWith(dailySummary: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setDarkModeOverride(bool value) async {
    final updated = _current().copyWith(darkModeOverride: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setAlertThreshold(int minutes) async {
    final updated = _current().copyWith(alertThresholdMinutes: minutes);
    state = AsyncData(updated);
    await _save(updated);
  }

  /// Reload from Firestore (e.g. after login).
  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }
}

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(
  UserSettingsNotifier.new,
);
