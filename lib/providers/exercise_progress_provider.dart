import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/datasources/auth_service_mock.dart'; // adjust path as needed

final exerciseProgressProvider = FutureProvider<Map<String, int>>((ref) async {
  final user = ref.watch(authStateProvider);
  if (user == null) return {};

  final snapshot = await FirebaseFirestore.instance
      .collection('exerciseProgress')
      .where('userId', isEqualTo: user.userId)
      .get();

  final Map<String, int> progress = {};
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final exerciseId = data['exerciseId'] as String;
    final reps = data['completedReps'] as int;
    progress[exerciseId] = reps;
  }
  return progress;
});

final exerciseProgressNotifierProvider =
    StateNotifierProvider<ExerciseProgressNotifier, Map<String, int>>((ref) {
  return ExerciseProgressNotifier(ref);
});

class ExerciseProgressNotifier extends StateNotifier<Map<String, int>> {
  final Ref ref;

  ExerciseProgressNotifier(this.ref) : super({}) {
    _loadInitialProgress(); // 👈 auto-load on first use
  }

  Future<void> _loadInitialProgress() async {
    final progress = await ref.read(exerciseProgressProvider.future);
    state = progress;
  }

  Future<void> saveProgress(String exerciseId, int reps) async {
    final user = ref.read(authStateProvider);
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('exerciseProgress')
        .doc('${user.userId}_$exerciseId');

    await docRef.set({
      'userId': user.userId,
      'exerciseId': exerciseId,
      'completedReps': reps,
      'timestamp': FieldValue.serverTimestamp(),
    });

    state = {...state, exerciseId: reps};
  }

  Future<void> clearProgress() async {
    final user = ref.read(authStateProvider);
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('exerciseProgress')
        .where('userId', isEqualTo: user.userId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    state = {};
  }
}