import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authServiceProvider = Provider((ref) => FirebaseAuthService());

class AuthStateNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    return null;
  }

  void setUser(AppUser? user) {
    state = user;
  }

  void logout() {
    state = null;
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AppUser?>(AuthStateNotifier.new);

class FirebaseAuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// Login with Firebase Authentication
  Future<AppUser> login(String email, String password) async {
    try {
      debugPrint('🔐 Attempting login for: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('✅ Firebase auth successful for uid: ${credential.user!.uid}');

      // Fetch user profile from Firestore
      final userDoc = await _db.collection('users').doc(credential.user!.uid).get();

      if (userDoc.exists) {
        debugPrint('✅ User document found in Firestore');
        final data = userDoc.data()!;
        final role = data['role'] as String?;

        // Read userId from Firestore document (e.g. "patient001")
        final userId = data['userId'] as String? ?? credential.user!.uid;

        debugPrint('✅ userId from Firestore: $userId | role: $role');

        if (role == null) {
          throw Exception('User role not set in Firestore. Please contact admin.');
        }

        return AppUser(
          uid: credential.user!.uid,
          userId: userId,
          email: email,
          role: role,
          profileData: data['profileData'],
        );
      }

      throw Exception('User profile not found in Firestore. Please contact admin.');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Login Error: $e');
      rethrow;
    }
  }

  /// Sign up new user
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      debugPrint('📝 Attempting signup for: $email');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Auto-generate userId from Firebase UID
      final userId = credential.user!.uid;

      debugPrint('✅ Firebase account created with uid: ${credential.user!.uid}');

      // Save to Firestore
      await _db.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'role': role,
        'userId': userId,
        'profileData': profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Firestore document created for userId: $userId with role: $role');

      return AppUser(
        uid: credential.user!.uid,
        userId: userId,
        email: email,
        role: role,
        profileData: profileData,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Signup Error: $e');
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Get current Firebase user
  User? getCurrentFirebaseUser() {
    return _auth.currentUser;
  }
}