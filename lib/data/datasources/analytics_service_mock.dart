import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/posture_data.dart';

final analyticsServiceProvider = Provider((ref) => MockAnalyticsService());

class MockAnalyticsService {
  Future<List<PostureData>> getDailyHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final random = Random();
    List<PostureData> history = [];
    final now = DateTime.now();

    for (int i = 0; i < 24; i++) {
        history.add(PostureData(
        postureClass: i % 4 == 0 ? 'Slouching' : 'Upright',
        confidence: 0.8 + (random.nextDouble() * 0.1),
        timestamp: now.subtract(Duration(hours: 24 - i)),
      ));
    }
    return history;
  }
}
