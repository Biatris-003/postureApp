import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sensor_frame.dart';

// Command to poll quaternion register 0x51 on WitMotion WT901BLECL.
// Sensor replies with a 0x71 frame (reg_l=0x51) containing w,x,y,z.
const List<int> _kQuatCmd = [0xFF, 0xAA, 0x27, 0x51, 0x00];
const List<int> _kBatCmd = [0xFF, 0xAA, 0x27, 0x64, 0x00];

/// MAC address → anatomical sensor label.
/// Must match SENSOR_ID_MAP in load_and_predict_realtime.py exactly.
const Map<String, String> kSensorIdMap = {
  'ED:35:33:D3:6C:F8': 'C7',
  'ED:40:FE:65:30:6C': 'T4',
  'F6:90:CC:01:6D:25': 'T12',
  'E3:CA:2D:FD:E0:8C': 'L5',
};

/// Connects to all four WitMotion BLE sensors, decodes raw frames, and emits
/// [SensorRow] events.  Frame parsing is a direct port of
/// ble_realtime_receiver.py (decode_frame / notification_handler / build_row).
class BleReceiver {
  BleReceiver();

  final _rowController = StreamController<SensorRow>.broadcast();
  /// Stream of decoded sensor rows — one per device per notification.
  Stream<SensorRow> get rows => _rowController.stream;

  final _batteryController = StreamController<Map<String, int>>.broadcast();
  /// Stream of battery percentages per sensor (keyed by MAC address).
  Stream<Map<String, int>> get batteryStream => _batteryController.stream;

  final _connectionController = StreamController<Map<String, bool>>.broadcast();
  /// Stream of connection statuses per sensor (keyed by MAC address).
  Stream<Map<String, bool>> get connectionStream => _connectionController.stream;

  final Map<String, DeviceState> _states = {};
  final Map<String, BluetoothDevice> _devices = {};
  final List<StreamSubscription> _subs = [];
  final List<Timer> _timers = [];

  final Map<String, int> _batteryLevels = {};
  final Map<String, bool> _connectionStates = {};
  Set<String>? _enabledMacs;

  bool _running = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> start({Set<String>? enabledMacs}) async {
    if (_running) return;
    _running = true;
    _enabledMacs = enabledMacs;

    // Reset status/battery maps
    _batteryLevels.clear();
    _connectionStates.clear();
    for (final mac in kSensorIdMap.keys) {
      _connectionStates[mac] = false;
      _batteryLevels[mac] = 0;
    }
    _emitConnectionUpdate();
    _emitBatteryUpdate();

    FlutterBluePlus.setLogLevel(LogLevel.none, color: false);
    await _requestPermissions();

    // Stagger connection attempts to avoid overwhelming Android's GATT stack.
    // Simultaneous connects all fail with error 133 (GATT_ERROR).
    int i = 0;
    for (final mac in kSensorIdMap.keys) {
      _states[mac] = DeviceState();
      Future<void>.delayed(Duration(milliseconds: i * 600), () {
        if (_running) _connectDevice(mac);
      });
      i++;
    }
  }

  Future<void> stop() async {
    _running = false;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    for (final device in _devices.values) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _devices.clear();
    _states.clear();

    // Set connection states to offline when stopped
    for (final mac in kSensorIdMap.keys) {
      _connectionStates[mac] = false;
    }
    _emitConnectionUpdate();
  }

  void updateEnabledMacs(Set<String> enabledMacs) {
    _enabledMacs = enabledMacs;
    // For any sensor that is now disabled, disconnect it immediately
    for (final mac in kSensorIdMap.keys) {
      if (!enabledMacs.contains(mac)) {
        final device = _devices[mac];
        if (device != null) {
          try {
            device.disconnect();
          } catch (_) {}
          _devices.remove(mac);
        }
        if (_connectionStates[mac] != false) {
          _connectionStates[mac] = false;
          _emitConnectionUpdate();
        }
      }
    }
  }

  void dispose() {
    stop();
    _rowController.close();
    _batteryController.close();
    _connectionController.close();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _emitConnectionUpdate() {
    if (!_connectionController.isClosed) {
      _connectionController.add(Map.from(_connectionStates));
    }
  }

  void _emitBatteryUpdate() {
    if (!_batteryController.isClosed) {
      _batteryController.add(Map.from(_batteryLevels));
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  /// Connects to one device and auto-reconnects on disconnect.
  void _connectDevice(String mac) async {
    final label = kSensorIdMap[mac] ?? mac;
    while (_running) {
      // Check if this sensor is enabled. If not, sleep and wait until it is.
      if (_enabledMacs != null && !_enabledMacs!.contains(mac)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }

      final device = BluetoothDevice.fromId(mac);
      _devices[mac] = device;
      Timer? quatTimer;
      Timer? batTimer;
      try {
        try { await device.disconnect(); } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 300));

        if (!_running || (_enabledMacs != null && !_enabledMacs!.contains(mac))) {
          continue;
        }

        // ignore: avoid_print
        print('[BLE] $label: connecting...');
        await device.connect(
          timeout: const Duration(seconds: 20),
          autoConnect: false,
        );

        _connectionStates[mac] = true;
        _emitConnectionUpdate();

        // ignore: avoid_print
        print('[BLE] $label: connected, discovering services...');

        final services = await device.discoverServices();
        BluetoothCharacteristic? writeChar;

        for (final service in services) {
          for (final char in service.characteristics) {
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.onValueReceived.listen((data) {
                if (_running) _handleNotification(mac, data);
              });
              _subs.add(sub);
            }
            if (char.uuid.toString().toLowerCase().contains('0000ffe9') &&
                (char.properties.write || char.properties.writeWithoutResponse)) {
              writeChar = char;
            }
          }
        }

        if (writeChar != null) {
          final wc = writeChar;

          // ignore: avoid_print
          print('[BLE] $label: polling quaternion via FFE9 every 200ms');
          quatTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
            if (!_running || (_enabledMacs != null && !_enabledMacs!.contains(mac))) return;
            try {
              await wc.write(_kQuatCmd, withoutResponse: true);
            } catch (_) {}
          });
          _timers.add(quatTimer);

          // Poll battery on connect, and then every 10 seconds
          try {
            await wc.write(_kBatCmd, withoutResponse: true);
          } catch (_) {}

          batTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
            if (!_running || (_enabledMacs != null && !_enabledMacs!.contains(mac))) return;
            try {
              await wc.write(_kBatCmd, withoutResponse: true);
            } catch (_) {}
          });
          _timers.add(batTimer);
        } else {
          // ignore: avoid_print
          print('[BLE] $label: write char FFE9 not found — no quat/battery polling');
        }

        // ignore: avoid_print
        print('[BLE] $label: subscribed, waiting for data...');

        await device.connectionState
            .firstWhere((s) => s == BluetoothConnectionState.disconnected);

        _connectionStates[mac] = false;
        _emitConnectionUpdate();

        // ignore: avoid_print
        print('[BLE] $label: disconnected, retrying...');
      } catch (e) {
        _connectionStates[mac] = false;
        _emitConnectionUpdate();
        // ignore: avoid_print
        print('[BLE] $label: error — $e');
      } finally {
        quatTimer?.cancel();
        _timers.remove(quatTimer);
        batTimer?.cancel();
        _timers.remove(batTimer);
      }

      if (_running) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  }

  /// Port of notification_handler() in ble_realtime_receiver.py.
  void _handleNotification(String mac, List<int> data) {
    final frames = _splitFrames(data);
    final state = _states[mac];
    if (state == null) return;

    for (final frame in frames) {
      final decoded = _decodeFrame(frame);
      if (decoded == null) continue;

      final type = decoded['type'] as String;

      if (type == '0x61') {
        state.ax = decoded['ax'] as double;
        state.ay = decoded['ay'] as double;
        state.az = decoded['az'] as double;
        state.gx = decoded['gx'] as double;
        state.gy = decoded['gy'] as double;
        state.gz = decoded['gz'] as double;
        state.angleX = decoded['roll'] as double;
        state.angleY = decoded['pitch'] as double;
        state.angleZ = decoded['yaw'] as double;
        state.hasAcc = true;
      } else if (type == '0x59' || type == '0x71_quat') {
        state.q0 = decoded['q0'] as double;
        state.q1 = decoded['q1'] as double;
        state.q2 = decoded['q2'] as double;
        state.q3 = decoded['q3'] as double;
        state.quatReal = true;
      } else if (type == '0x54' || type == '0x71_mag') {
        state.mx = decoded['mx'] as double;
        state.my = decoded['my'] as double;
        state.mz = decoded['mz'] as double;
      } else if (type == '0x71_bat') {
        final percentage = decoded['battery'] as int;
        _batteryLevels[mac] = percentage;
        _emitBatteryUpdate();
      }

      // Emit a row as soon as we have at least acc/gyro/angle.
      if (state.hasAcc) {
        _rowController.add(SensorRow(
          deviceAddress: mac,
          sensorId: kSensorIdMap[mac]!,
          ax: state.ax, ay: state.ay, az: state.az,
          gx: state.gx, gy: state.gy, gz: state.gz,
          angleX: state.angleX, angleY: state.angleY, angleZ: state.angleZ,
          mx: state.mx, my: state.my, mz: state.mz,
          q0: state.q0, q1: state.q1, q2: state.q2, q3: state.q3,
          quatReal: state.quatReal,
          timestampUs: DateTime.now().microsecondsSinceEpoch,
        ));
      }
    }
  }

  // ── Frame parsing — exact port of decode_frame() ──────────────────────────

  /// Port of split_frames() — locates 0x55-prefixed 20-byte frames.
  static List<List<int>> _splitFrames(List<int> payload) {
    final frames = <List<int>>[];
    int i = 0;
    while (i <= payload.length - 20) {
      if (payload[i] != 0x55) {
        i++;
        continue;
      }
      frames.add(payload.sublist(i, i + 20));
      i += 20;
    }
    return frames;
  }

  /// Port of decode_frame().  Returns null for unrecognised frames.
  static Map<String, dynamic>? _decodeFrame(List<int> frame) {
    if (frame.length < 20 || frame[0] != 0x55) return null;

    final bd = ByteData.sublistView(Uint8List.fromList(frame));
    final type = frame[1];

    // 0x61 — Acc + Gyro + Euler (9 × int16 starting at byte 2)
    if (type == 0x61) {
      const accScale = 16.0 / 32768.0;
      const gyroScale = 2000.0 / 32768.0;
      const angleScale = 180.0 / 32768.0;

      return {
        'type': '0x61',
        'ax': bd.getInt16(2, Endian.little) * accScale,
        'ay': bd.getInt16(4, Endian.little) * accScale,
        'az': bd.getInt16(6, Endian.little) * accScale,
        'gx': bd.getInt16(8, Endian.little) * gyroScale,
        'gy': bd.getInt16(10, Endian.little) * gyroScale,
        'gz': bd.getInt16(12, Endian.little) * gyroScale,
        'roll':  bd.getInt16(14, Endian.little) * angleScale,
        'pitch': bd.getInt16(16, Endian.little) * angleScale,
        'yaw':   bd.getInt16(18, Endian.little) * angleScale,
      };
    }

    // 0x71 — register-read reply (mag or quat or bat)
    if (type == 0x71) {
      final regL = frame[2];
      final regH = frame[3];

      // Magnetometer reply (reg 0x3A)
      if (regL == 0x3A && regH == 0x00) {
        return {
          'type': '0x71_mag',
          'mx': bd.getInt16(4, Endian.little).toDouble(),
          'my': bd.getInt16(6, Endian.little).toDouble(),
          'mz': bd.getInt16(8, Endian.little).toDouble(),
        };
      }

      // Quaternion reply (reg 0x51)
      if (regL == 0x51 && regH == 0x00) {
        const scale = 1.0 / 32768.0;
        return {
          'type': '0x71_quat',
          'q0': bd.getInt16(4, Endian.little) * scale,
          'q1': bd.getInt16(6, Endian.little) * scale,
          'q2': bd.getInt16(8, Endian.little) * scale,
          'q3': bd.getInt16(10, Endian.little) * scale,
        };
      }

      // Battery/Power reply (reg 0x64)
      if (regL == 0x64 && regH == 0x00) {
        final rawVal = bd.getUint16(4, Endian.little);
        // Map 680 (6.8V) - 840 (8.4V) to 0 - 100 percentage.
        double pct = ((rawVal - 680) / (840 - 680)) * 100.0;
        final pctClamped = pct.clamp(0.0, 100.0).round();
        return {
          'type': '0x71_bat',
          'battery': pctClamped,
        };
      }

      return null;
    }

    // 0x54 — passive magnetometer frame
    if (type == 0x54) {
      const scale = 4912.0 / 32768.0;
      return {
        'type': '0x54',
        'mx': bd.getInt16(2, Endian.little) * scale,
        'my': bd.getInt16(4, Endian.little) * scale,
        'mz': bd.getInt16(6, Endian.little) * scale,
      };
    }

    // 0x59 — passive quaternion frame
    if (type == 0x59) {
      const scale = 1.0 / 32768.0;
      return {
        'type': '0x59',
        'q0': bd.getInt16(2, Endian.little) * scale,
        'q1': bd.getInt16(4, Endian.little) * scale,
        'q2': bd.getInt16(6, Endian.little) * scale,
        'q3': bd.getInt16(8, Endian.little) * scale,
      };
    }

    return null;
  }
}
