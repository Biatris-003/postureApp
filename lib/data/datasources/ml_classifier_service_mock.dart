import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/posture_data.dart';

final mlClassifierServiceProvider = Provider((ref) => MockMLClassifierService());

class MockMLClassifierService {
  final List<String> _classes = [
    'Upright',
    'Slouching',
    'Forward Bending',
    'Backward Bending',
    'Left Bending',
    'Right Bending'
  ];

  final Random _random = Random();

  PostureData classify(List<double> sensorData) {
    // Heavily bias towards Upright for demo sanity, but occasionally show bad posture
    bool isBadPosture = _random.nextDouble() > 0.7;
    String posture = 'Upright';
    
    if (isBadPosture) {
       posture = _classes[_random.nextInt(_classes.length - 1) + 1];
    }

    return PostureData(
      postureClass: posture,
      confidence: 0.7 + (_random.nextDouble() * 0.29), // 0.70 to 0.99
      timestamp: DateTime.now(),
    );
  }
}
