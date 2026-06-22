import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the set of exercise titles the user has marked as done TODAY.
/// Stored in Firestore under:
///   users/{uid}/exerciseDone/meta        → { date: 'YYYY-MM-DD' }
///   users/{uid}/exerciseDone/{title}     → { doneAt: timestamp }
///
/// On build, if the stored date differs from today, the entire collection
/// is wiped and starts fresh — no cloud functions needed.
class ExerciseDoneNotifier extends AsyncNotifier<Set<String>> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('exerciseDone');

  /// Returns today's date as a string e.g. '2025-06-23'
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Set<String>> build() async {
    if (_uid == null) return {};

    // Check what date was stored
    final metaDoc = await _col.doc('__meta__').get();
    final storedDate = (metaDoc.data() as Map<String, dynamic>?)?['date'] as String?;

    if (storedDate != _today) {
      // New day — wipe everything and write today's date
      await _clearAll();
      await _col.doc('__meta__').set({'date': _today});
      return {};
    }

    // Same day — load existing done titles (exclude the meta doc)
    final snap = await _col.get();
    return snap.docs
        .where((d) => d.id != '__meta__')
        .map((d) => d.id)
        .toSet();
  }

  Future<void> _clearAll() async {
    final snap = await _col.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> markDone(String exerciseTitle) async {
    if (_uid == null) return;
    await _col.doc(exerciseTitle).set({'doneAt': FieldValue.serverTimestamp()});
    state = AsyncData({...state.value ?? {}, exerciseTitle});
  }

  Future<void> markUndone(String exerciseTitle) async {
    if (_uid == null) return;
    await _col.doc(exerciseTitle).delete();
    final updated = {...state.value ?? {}}..remove(exerciseTitle);
    state = AsyncData(updated);
  }

  bool isDone(String exerciseTitle) =>
      state.value?.contains(exerciseTitle) ?? false;
}

final exerciseDoneProvider =
    AsyncNotifierProvider<ExerciseDoneNotifier, Set<String>>(
  ExerciseDoneNotifier.new,
);

/// Separate done state for the Weekly Assessment tab only.
/// Same daily-reset logic, stored under a different Firestore sub-collection.
class WeeklyExerciseDoneNotifier extends AsyncNotifier<Set<String>> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('weeklyExerciseDone');

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Set<String>> build() async {
    if (_uid == null) return {};

    final metaDoc = await _col.doc('__meta__').get();
    final storedDate =
        (metaDoc.data() as Map<String, dynamic>?)?['date'] as String?;

    if (storedDate != _today) {
      await _clearAll();
      await _col.doc('__meta__').set({'date': _today});
      return {};
    }

    final snap = await _col.get();
    return snap.docs
        .where((d) => d.id != '__meta__')
        .map((d) => d.id)
        .toSet();
  }

  Future<void> _clearAll() async {
    final snap = await _col.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> markDone(String exerciseTitle) async {
    if (_uid == null) return;
    await _col
        .doc(exerciseTitle)
        .set({'doneAt': FieldValue.serverTimestamp()});
    state = AsyncData({...state.value ?? {}, exerciseTitle});
  }

  Future<void> markUndone(String exerciseTitle) async {
    if (_uid == null) return;
    await _col.doc(exerciseTitle).delete();
    final updated = {...state.value ?? {}}..remove(exerciseTitle);
    state = AsyncData(updated);
  }

  bool isDone(String exerciseTitle) =>
      state.value?.contains(exerciseTitle) ?? false;
}

final weeklyExerciseDoneProvider =
    AsyncNotifierProvider<WeeklyExerciseDoneNotifier, Set<String>>(
  WeeklyExerciseDoneNotifier.new,
);