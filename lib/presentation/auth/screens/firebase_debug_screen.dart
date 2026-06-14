import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A temporary debug screen to confirm Firebase is connected.
/// Navigate to this from the WelcomeScreen during testing.
class FirebaseDebugScreen extends StatefulWidget {
  const FirebaseDebugScreen({super.key});

  @override
  State<FirebaseDebugScreen> createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  String _authStatus = '⏳ Checking...';
  String _firestoreStatus = '⏳ Checking...';
  String _projectId = '⏳ Checking...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _isLoading = true);

    // 1. Firebase Auth check
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      _authStatus = currentUser != null
          ? '✅ Signed in as: ${currentUser.email}\nUID: ${currentUser.uid}'
          : '✅ Auth connected — No user signed in';
      _projectId = '✅ App: ${auth.app.name}';
    } catch (e) {
      _authStatus = '❌ Auth error: $e';
      _projectId = '❌ Could not read project';
    }

    // 2. Firestore read check — try to reach any collection
    try {
      await FirebaseFirestore.instance
          .collection('_connection_test')
          .limit(1)
          .get(const GetOptions(source: Source.server)); // force server hit
      _firestoreStatus = '✅ Firestore reachable (server response received)';
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Permission denied means Firestore IS reachable — rules blocked us
        _firestoreStatus =
            '✅ Firestore reachable (rules blocked test collection — expected)';
      } else {
        _firestoreStatus = '❌ Firestore error [${e.code}]: ${e.message}';
      }
    } catch (e) {
      _firestoreStatus = '❌ Firestore unreachable: $e';
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text('Firebase Status',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _runChecks,
            tooltip: 'Re-run checks',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Running Firebase checks...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  icon: Icons.cloud,
                  title: 'Firebase Project',
                  status: _projectId,
                ),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.person,
                  title: 'Firebase Authentication',
                  status: _authStatus,
                ),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.storage,
                  title: 'Cloud Firestore',
                  status: _firestoreStatus,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFECB3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                          SizedBox(width: 8),
                          Text('How to verify in Firebase Console',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF57F17))),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Go to console.firebase.google.com\n'
                        '2. Select your project\n'
                        '3. Authentication → Users (see logged-in users)\n'
                        '4. Firestore → Database (see created documents)\n'
                        '5. Sign up in the app → user appears immediately',
                        style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF5D4037)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String status,
  }) {
    final isOk = status.startsWith('✅');
    final isError = status.startsWith('❌');
    final color = isOk
        ? const Color(0xFF4CAF50)
        : isError
            ? const Color(0xFFEF5350)
            : const Color(0xFFFFA726);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 6),
                Text(status,
                    style: TextStyle(
                        fontSize: 13,
                        color: color,
                        height: 1.5,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
