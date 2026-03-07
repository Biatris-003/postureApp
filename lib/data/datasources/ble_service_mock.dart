import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bleServiceProvider = Provider((ref) => MockBLEService());

class MockBLEService {
  final _controller = StreamController<List<double>>.broadcast();

  MockBLEService() {
    _startSimulatingData();
  }

  void _startSimulatingData() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      // Simulating IMU data: [accelX, accelY, accelZ, gyroX, gyroY, gyroZ]
      _controller.add([0.1, 0.9, 0.2, 0.01, 0.02, 0.01]); 
    });
  }

  Stream<List<double>> get sensorDataStream => _controller.stream;

  void dispose() {
    _controller.close();
  }
}
