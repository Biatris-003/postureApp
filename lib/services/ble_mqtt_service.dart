// // lib/services/ble_mqtt_service.dart

// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';

// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:mqtt_client/mqtt_server_client.dart';
// import 'package:permission_handler/permission_handler.dart';

// // ── MQTT CONFIG ─────────────────────────────────────────────────────────────
// const String mqttHost = 'facfee6409bf43efb53dd01d7df4178f.s1.eu.hivemq.cloud';
// const int mqttPort = 8884;
// const String mqttUsername = 'posture';
// const String mqttPassword = 'Posture123';

// // ── SENSOR MAP ──────────────────────────────────────────────────────────────
// const Map<String, String> kSensors = {
//   'f6:90:cc:01:6d:25': 't12',
// };

// // ── TOPICS ───────────────────────────────────────────────────────────────────
// const String topicRaw = 'imu/raw';
// const String topicLive = 'imu/live';
// const String topicPosture = 'posture/classification';

// class BleMqttService {
//   MqttServerClient? _mqtt;

//   final Map<String, Map<String, dynamic>> _latest = {};
//   final Map<String, Map<String, dynamic>> _state = {};

//   final _postureController =
//       StreamController<Map<String, dynamic>>.broadcast();

//   Stream<Map<String, dynamic>> get postureStream =>
//       _postureController.stream;

//   final _liveController =
//       StreamController<Map<String, dynamic>>.broadcast();

//   Stream<Map<String, dynamic>> get liveStream =>
//       _liveController.stream;

//   // ─────────────────────────────────────────────────────────────
//   // PERMISSIONS
//   // ─────────────────────────────────────────────────────────────
//   Future<void> _requestPermissions() async {
//     print("Requesting permissions...");

//     await [
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//       Permission.locationWhenInUse,
//     ].request();

//     print("Permissions done");
//   }

//   // ─────────────────────────────────────────────────────────────
//   // MQTT
//   // ─────────────────────────────────────────────────────────────
//   Future<void> connectMqtt() async {
//     print("Connecting MQTT...");

//     _mqtt = MqttServerClient.withPort(
//       mqttHost,
//       'flutter_gateway_${DateTime.now().millisecondsSinceEpoch}',
//       mqttPort,
//     );

//     _mqtt!.useWebSocket = true;
//     _mqtt!.secure = true;
//     _mqtt!.logging(on: true);

//     _mqtt!.keepAlivePeriod = 30;
//     _mqtt!.onDisconnected = () {
//       print("MQTT disconnected → reconnecting...");
//       Future.delayed(const Duration(seconds: 3), connectMqtt);
//     };

//     _mqtt!.connectionMessage = MqttConnectMessage()
//         .withClientIdentifier(
//           'flutter_gateway_${DateTime.now().millisecondsSinceEpoch}',
//         )
//         .authenticateAs(mqttUsername, mqttPassword)
//         .startClean();

//     try {
//       await _mqtt!.connect();
//     } catch (e) {
//       print("MQTT ERROR: $e");
//       return;
//     }

//     if (_mqtt!.connectionStatus?.state !=
//         MqttConnectionState.connected) {
//       print("MQTT NOT CONNECTED: ${_mqtt!.connectionStatus}");
//       return;
//     }

//     print("MQTT CONNECTED ✅");

//     _mqtt!.subscribe(topicPosture, MqttQos.atMostOnce);
//   }

//   // ─────────────────────────────────────────────────────────────
//   // BLE SCAN (DEBUGGED)
//   // ─────────────────────────────────────────────────────────────
//   Future<void> startScanning() async {
//     print("Starting BLE scan...");

//     FlutterBluePlus.scanResults.listen((results) {
//       for (final r in results) {
//         final addr =
//             r.device.remoteId.str.toLowerCase().replaceAll('-', ':');

//         print("FOUND DEVICE: $addr RSSI: ${r.rssi}");

//         if (kSensors.containsKey(addr)) {
//           print("MATCH FOUND → $addr");

//           FlutterBluePlus.stopScan();

//           _connectToSensor(r.device, kSensors[addr]!);
//         }
//       }
//     });

//     await FlutterBluePlus.startScan(
//       timeout: const Duration(seconds: 10),
//     );
//   }

//   // ─────────────────────────────────────────────────────────────
//   // CONNECT SENSOR (DEBUGGED)
//   // ─────────────────────────────────────────────────────────────
//   Future<void> _connectToSensor(
//     BluetoothDevice device,
//     String label,
//   ) async {
//     final address =
//         device.remoteId.str.toLowerCase().replaceAll('-', ':');

//     print("[$label] Connecting to $address");

//     while (true) {
//       try {
//         await device.connect(
//           timeout: const Duration(seconds: 15),
//         );

//         print("[$label] CONNECTED ✓");

//         final services = await device.discoverServices();

//         print("[$label] Services: ${services.length}");

//         for (final service in services) {
//           for (final char in service.characteristics) {
//             print(
//                 "CHAR: ${char.characteristicUuid} notify=${char.properties.notify}");

//             if (char.properties.notify) {
//               await char.setNotifyValue(true);

//               char.onValueReceived.listen((value) {
//                 print("RAW BLE DATA RECEIVED: $value");
//                 _onNotification(address, label, value);
//               });

//               print("[$label] SUBSCRIBED ✓");
//             }
//           }
//         }

//         await device.connectionState.firstWhere(
//           (s) => s == BluetoothConnectionState.disconnected,
//         );

//         print("[$label] DISCONNECTED → retrying...");
//       } catch (e) {
//         print("[$label] ERROR: $e");
//         await Future.delayed(const Duration(seconds: 3));
//       }
//     }
//   }

//   // ─────────────────────────────────────────────────────────────
//   // BLE DATA HANDLER
//   // ─────────────────────────────────────────────────────────────
//   void _onNotification(
//     String address,
//     String label,
//     List<int> rawData,
//   ) {
//     final payload = Uint8List.fromList(rawData);

//     final state = _state.putIfAbsent(address, () => {});

//     if (payload.isEmpty) return;

//     state['acc'] = [0, 0, 0]; // placeholder for now

//     final row = _buildRow(address, label, state);

//     print("PUBLISHING ROW → $row");

//     _publishRow(row, label);
//   }

//   // ─────────────────────────────────────────────────────────────
//   // MQTT PUBLISH
//   // ─────────────────────────────────────────────────────────────
//   void _publishRow(
//     Map<String, dynamic> row,
//     String sensorLabel,
//   ) {
//     if (_mqtt?.connectionStatus?.state !=
//         MqttConnectionState.connected) {
//       print("MQTT NOT READY");
//       return;
//     }

//     final builder = MqttClientPayloadBuilder()
//       ..addString(jsonEncode(row));

//     _mqtt!.publishMessage(
//       topicRaw,
//       MqttQos.atMostOnce,
//       builder.payload!,
//     );

//     print("MQTT SENT ✔");
//   }

//   // ─────────────────────────────────────────────────────────────
//   Future<void> start() async {
//     print("SERVICE STARTING...");

//     await _requestPermissions();
//     await connectMqtt();
//     await startScanning();
//   }

//   void dispose() {
//     _postureController.close();
//     _liveController.close();
//     _mqtt?.disconnect();
//   }

//   // ─────────────────────────────────────────────────────────────
//   Map<String, dynamic> _buildRow(
//     String address,
//     String label,
//     Map<String, dynamic> state,
//   ) {
//     final now = DateTime.now();

//     return {
//       'time': now.toIso8601String(),
//       'device': address,
//       'label': label,
//       'status': 'live',
//     };
//   }
// }