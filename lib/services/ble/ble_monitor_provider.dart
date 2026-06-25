import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble_receiver.dart';
import '../session_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Persistent BLE monitor — owns the single [BleReceiver] instance that is
// always running.  Exposes live battery levels and connection status so the
// Settings page (and any other UI) can show real data even when no posture
// session is active.
//
// When a session starts, [RealtimeProcessor] reuses the same [BleReceiver]
// instead of creating its own, avoiding BLE connection conflicts.
//
// NOTE: Battery levels shown in the UI are currently simulated rather than
// read from the real BLE battery register. [rollFakeBatteryLevels] generates
// one batch of values per posture session (called from
// SessionNotifier.startSession()) and they stay frozen until the next
// session starts. All four sensors are clustered within ~2-3% of each other
// and always land at 80% or above.
// ─────────────────────────────────────────────────────────────────────────────

class BleMonitorState {
  const BleMonitorState({
    this.batteryLevels = const {},
    this.connections = const {},
  });

  final Map<String, int> batteryLevels;
  final Map<String, bool> connections;

  BleMonitorState copyWith({
    Map<String, int>? batteryLevels,
    Map<String, bool>? connections,
  }) {
    return BleMonitorState(
      batteryLevels: batteryLevels ?? this.batteryLevels,
      connections: connections ?? this.connections,
    );
  }
}

class BleMonitorNotifier extends Notifier<BleMonitorState> {
  final BleReceiver _bleReceiver = BleReceiver();
  StreamSubscription<Map<String, int>>? _batterySub;
  StreamSubscription<Map<String, bool>>? _connectionSub;
  bool _started = false;
  final Random _random = Random();

  /// The single shared BLE receiver. Used by [RealtimeProcessor] during
  /// active sessions.
  BleReceiver get bleReceiver => _bleReceiver;

  @override
  BleMonitorState build() {
    ref.onDispose(() {
      _batterySub?.cancel();
      _connectionSub?.cancel();
      _bleReceiver.dispose();
    });

    // Listen for changes to enabled sensors and forward to BleReceiver.
    ref.listen<Map<String, bool>>(enabledSensorsProvider, (prev, next) {
      final enabledMacs = next.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();
      _bleReceiver.updateEnabledMacs(enabledMacs);
    });

    // Fire-and-forget the BLE start.
    _startMonitoring();

    return const BleMonitorState();
  }

  Future<void> _startMonitoring() async {
    if (_started) return;
    _started = true;

    final enabledSensors = ref.read(enabledSensorsProvider);
    final enabledMacs = enabledSensors.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    debugPrint('[BleMonitor] Starting persistent BLE monitor...');
    await _bleReceiver.start(enabledMacs: enabledMacs);

    // Real battery stream is left connected for future use, but its values
    // are no longer surfaced into state — fake values take over instead.
    // (See rollFakeBatteryLevels, called once per posture session.)
    _batterySub = _bleReceiver.batteryStream.listen((_) {
      // Intentionally ignored — battery display is simulated.
    });

    _connectionSub = _bleReceiver.connectionStream.listen((connectionMap) {
      state = state.copyWith(connections: connectionMap);
    });

    // Seed an initial fake reading immediately so the UI never shows 0%/N/A
    // before the first posture session has started.
    rollFakeBatteryLevels();
  }

  /// Generates one new batch of fake battery levels, one per sensor in
  /// [kSensorIdMap]. All four values are clustered within 2-3% of each other
  /// and never drop below 80%. Intended to be called once per posture
  /// session (from SessionNotifier.startSession()) — values then stay
  /// frozen until the next call.
  void rollFakeBatteryLevels() {
    // Base sits high enough that every sensor's offset still clears 80,
    // and low enough that values don't all bunch up against 100.
    final base = 85 + _random.nextInt(11); // 85-95 inclusive

    final newLevels = <String, int>{};
    for (final mac in kSensorIdMap.keys) {
      // Spread of -3 to +3 percentage points around the base.
      final offset = _random.nextInt(7) - 3; // -3..3 inclusive
      final value = (base + offset).clamp(80, 100);
      newLevels[mac] = value;
    }

    state = state.copyWith(batteryLevels: newLevels);
  }
}

final bleMonitorProvider =
    NotifierProvider<BleMonitorNotifier, BleMonitorState>(
  BleMonitorNotifier.new,
);