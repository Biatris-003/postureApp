import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
//  EXERCISES TAB — resets at midnight every calendar day
// ─────────────────────────────────────────────────────────────

class ExerciseDoneNotifier extends AsyncNotifier<Set<String>> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('exerciseDone');

  /// Today's date as 'YYYY-MM-DD' — resets at midnight
  String get _today {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Set<String>> build() async {
    if (_uid == null) return {};

    final metaDoc = await _col.doc('__meta__').get();
    final data = metaDoc.data() as Map<String, dynamic>?;
    final storedDate = data?['date'] as String?;

    if (storedDate != _today) {
      // New calendar day — wipe and start fresh
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

final exerciseDoneProvider =
    AsyncNotifierProvider<ExerciseDoneNotifier, Set<String>>(
  ExerciseDoneNotifier.new,
);

// ─────────────────────────────────────────────────────────────
//  WEEKLY ASSESSMENT — resets at the start of each ISO week
//  (Monday 12:00 AM). Completing on Thursday stays completed
//  until next Monday.
// ─────────────────────────────────────────────────────────────

class WeeklyExerciseDoneNotifier extends AsyncNotifier<Set<String>> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('weeklyExerciseDone');

  /// Returns the date of the most recent Monday as 'YYYY-MM-DD'.
  /// This is the "week key" — same value for every day Mon–Sun of the same week.
  String get _currentWeekKey {
    final now = DateTime.now();
    // weekday: Mon=1, Tue=2, ... Sun=7
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Set<String>> build() async {
    if (_uid == null) return {};

    final metaDoc = await _col.doc('__meta__').get();
    final data = metaDoc.data() as Map<String, dynamic>?;
    final storedWeek = data?['weekStarting'] as String?;

    if (storedWeek != _currentWeekKey) {
      // New week — wipe and start fresh
      await _clearAll();
      await _col
          .doc('__meta__')
          .set({'weekStarting': _currentWeekKey});
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