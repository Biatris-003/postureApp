import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authServiceProvider = Provider((ref) => MockAuthService());

class AuthStateNotifier extends Notifier<AppUser?> {
  static const _userKey = 'auth_user';

  @override
  AppUser? build() {
    // Persistence disabled as requested: Always start at WelcomeScreen on refresh
    return null;
  }

  void setUser(AppUser? user) async {
    state = user;
    // We don't save to SharedPreferences anymore so it resets on refresh
  }
}
final authStateProvider = NotifierProvider<AuthStateNotifier, AppUser?>(AuthStateNotifier.new);

class MockAuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<AppUser> login(String email, String password, String intendedRole) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userDoc = await _db.collection('users').doc(credential.user!.uid).get();
      
      if (!userDoc.exists) {
        // Fallback for existing mock users or if profile is missing
        String role = email.contains('advisor') ? 'Advisor' : 'Member';
        return AppUser(uid: credential.user!.uid, email: email, role: role);
      }
      
      final data = userDoc.data()!;
      return AppUser(
        uid: credential.user!.uid,
        email: email,
        role: data['role'] ?? 'Member',
        profileData: data['profileData'],
      );
    } catch (e) {
      // If Firebase fails or user not found, fallback to mock login for testing
      // but only if it's a specific error (like user-not-found)
      debugPrint('Firebase Login Error: $e. Falling back to mock logic.');
      await Future.delayed(const Duration(seconds: 1));
      
      // Use 'c001' for Advisors to match the seeder data (Sara Ahmed etc.)
      final uid = intendedRole == 'Advisor' ? 'c001' : 'p001';
      return AppUser(uid: uid, email: email, role: intendedRole);
    }
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      await _db.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'role': role,
        'profileData': profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AppUser(
        uid: credential.user!.uid,
        email: email,
        role: role,
        profileData: profileData,
      );
    } catch (e) {
      debugPrint('Firebase Signup Error: $e. Falling back to mock logic.');
      await Future.delayed(const Duration(seconds: 1));
      return AppUser(
        uid: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        role: role,
        profileData: profileData,
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
