import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';

final authServiceProvider = Provider((ref) => MockAuthService());

class AuthStateNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;
  void setUser(AppUser? user) => state = user;
}
final authStateProvider = NotifierProvider<AuthStateNotifier, AppUser?>(AuthStateNotifier.new);

class MockAuthService {
  Future<AppUser> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.contains('advisor')) {
      return AppUser(uid: '2', email: email, role: 'Advisor');
    }
    return AppUser(uid: '1', email: email, role: 'Member');
  }

  Future<AppUser> signUp(String email, String password, String role) async {
    await Future.delayed(const Duration(seconds: 1));
    return AppUser(uid: DateTime.now().millisecondsSinceEpoch.toString(), email: email, role: role);
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
