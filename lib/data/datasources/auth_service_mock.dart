import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
// User ID Mapping: Maps emails to clean user IDs
// Update this map to add new patients
// ─────────────────────────────────────────────────────────────
const Map<String, String> emailToUserIdMapping = {
  'patient@test.com': 'patient001',
  'advisor@test.com': 'advisor001',
  // Add more here: 'patient2@test.com': 'patient002', etc.
};

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

  /// Get the user ID for this email
  String _getUserIdForEmail(String email, String role) {
    // First check if email is in mapping
    if (emailToUserIdMapping.containsKey(email)) {
      return emailToUserIdMapping[email]!;
    }
    
    // Fallback: generate based on role
    if (role == 'Advisor') {
      return 'advisor_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'patient_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Login with Firebase Authentication
  Future<AppUser> login(String email, String password, String intendedRole) async {
    try {
      debugPrint('🔐 Attempting login for: $email');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('✅ Firebase auth successful for uid: ${credential.user!.uid}');

      // Fetch user profile from Firestore
      final userDoc = await _db.collection('users').doc(credential.user!.uid).get();
      final userId = _getUserIdForEmail(email, intendedRole);

      if (userDoc.exists) {
        debugPrint('✅ User document found in Firestore');
        final data = userDoc.data()!;
        
        return AppUser(
          uid: credential.user!.uid,
          userId: userId,
          email: email,
          role: data['role'] ?? intendedRole,
          profileData: data['profileData'],
        );
      }

      debugPrint('⚠️ User document not found, creating basic user');
      // Fallback: create basic user
      return AppUser(
        uid: credential.user!.uid,
        userId: userId,
        email: email,
        role: intendedRole,
      );
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

      final userId = _getUserIdForEmail(email, role);

      debugPrint('✅ Firebase account created with uid: ${credential.user!.uid}');

      // Save to Firestore
      await _db.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'role': role,
        'userId': userId,
        'profileData': profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Firestore document created for userId: $userId');

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