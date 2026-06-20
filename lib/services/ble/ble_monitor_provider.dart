import 'dart:async';

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

    _batterySub = _bleReceiver.batteryStream.listen((batteryMap) {
      state = state.copyWith(batteryLevels: batteryMap);
    });

    _connectionSub = _bleReceiver.connectionStream.listen((connectionMap) {
      state = state.copyWith(connections: connectionMap);
    });
  }
}

final bleMonitorProvider =
    NotifierProvider<BleMonitorNotifier, BleMonitorState>(
  BleMonitorNotifier.new,
);
