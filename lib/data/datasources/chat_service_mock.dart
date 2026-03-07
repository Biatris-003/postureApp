import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatServiceProvider = Provider((ref) => MockChatService());

class MockChatService {
  Future<String> sendMessage(String message) async {
    await Future.delayed(const Duration(seconds: 1));
    if (message.toLowerCase().contains('pain') || message.toLowerCase().contains('hurt')) {
      return "I'm sorry to hear that. I recommend adjusting your chair so your feet are flat and taking a 5-minute walking break. If pain persists, consult your advisor.";
    }
    return "Based on your recent posture, try to keep your shoulders back and monitor your forward head posture. You're doing great!";
  }
}
