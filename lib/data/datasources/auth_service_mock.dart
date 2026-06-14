import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authServiceProvider = Provider((ref) => AuthService());

class AuthStateNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    // Persistence disabled: Always start at WelcomeScreen on refresh
    return null;
  }

  void setUser(AppUser? user) {
    state = user;
  }
}

final authStateProvider =
    NotifierProvider<AuthStateNotifier, AppUser?>(AuthStateNotifier.new);

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// Signs in the user with [email] and [password].
  /// Reads the user's role from the `users` collection.
  /// Throws a descriptive [Exception] on any failure.
  Future<AppUser> login(String email, String password,
      [String intendedRole = 'Member']) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = credential.user!.uid;

      final userDoc = await _db.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception(
            'Account profile not found. Please sign up or contact support.');
      }

      final data = userDoc.data()!;
      return AppUser(
        uid: uid,
        email: email,
        role: data['role'] ?? 'Member',
        profileData: data['profileData'],
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during login: ${e.code} — ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found for this email.');
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Incorrect password. Please try again.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  /// Creates a new Firebase Auth user, writes a document in `users`,
  /// and also writes the full profile into the role-specific collection
  /// (`patients` or `clinicians`) using the Firebase Auth UID as the document ID.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = credential.user!.uid;

      // Write to the shared `users` collection for role lookup on login
      await _db.collection('users').doc(uid).set({
        'email': email,
        'role': role,
        'profileData': profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write to the role-specific collection so dashboards can read profile data
      final collection = role == 'Advisor' ? 'clinicians' : 'patients';
      await _db.collection(collection).doc(uid).set({
        ...profileData,
        'uid': uid,
        'contactEmail': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AppUser(
        uid: uid,
        email: email,
        role: role,
        profileData: profileData,
      );

    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during signup: ${e.code} — ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account with this email already exists.');
        case 'weak-password':
          throw Exception('Password is too weak. Use at least 6 characters.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'operation-not-allowed':
          throw Exception('Email/Password sign-in is disabled in your Firebase console. Please go to your console and enable it.');
        case 'configuration-not-found':
          throw Exception('Firebase Authentication has not been initialized. Please open your Firebase Console, click "Get Started" in the Authentication section, and make sure Email/Password provider is enabled.');
        default:
          throw Exception('Sign up failed [${e.code}]: ${e.message}');
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
