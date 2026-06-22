import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/exercises/exercise_model.dart';
import 'analytics_service.dart';

class ExerciseRecommendationSyncService {
  ExerciseRecommendationSyncService({
    FirebaseFirestore? firestore,
    AnalyticsService? analyticsService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _analyticsService = analyticsService ?? AnalyticsService();

  final FirebaseFirestore _db;
  final AnalyticsService _analyticsService;

  Future<void> syncRecommendedExercises({
    required String firebaseUid,
    required String legacyUserId,
    required List<ExerciseModel> exercises,
  }) async {
    final patientId = await _analyticsService.resolvePatientId(
      firebaseUid: firebaseUid,
      legacyUserId: legacyUserId,
    );
    if (patientId == null || patientId.isEmpty) return;

    final planId = await _getOrCreatePlanId(patientId);
    await _replaceGeneratedExercises(planId, exercises);
  }

  Future<String> _getOrCreatePlanId(String patientId) async {
    final planSnapshot = await _db
        .collection('exercisePlans')
        .where('patientId', isEqualTo: patientId)
        .limit(1)
        .get();

    if (planSnapshot.docs.isNotEmpty) return planSnapshot.docs.first.id;

    final patientDoc = await _db.collection('patients').doc(patientId).get();
    final clinicianId = patientDoc.data()?['clinicianId'] as String?;

    final planRef = await _db.collection('exercisePlans').add({
      'patientId': patientId,
      'clinicianId': clinicianId,
      'createdDate': DateTime.now().toIso8601String(),
      'status': 'active',
      'source': 'weekly_posture_recommendation',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return planRef.id;
  }

  Future<void> _replaceGeneratedExercises(
    String planId,
    List<ExerciseModel> exercises,
  ) async {
    final existing = await _db
        .collection('exercises')
        .where('planId', isEqualTo: planId)
        .where('source', isEqualTo: 'weekly_posture_recommendation')
        .get();

    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (var index = 0; index < exercises.length; index++) {
      final exercise = exercises[index];
      final docRef = _db.collection('exercises').doc();
      batch.set(docRef, {
        'planId': planId,
        'name': exercise.title,
        'repetitions': _firstNumber(exercise.reps) ?? 5,
        'durationSeconds': _durationToSeconds(exercise.duration) ?? 300,
        'targetSpinalRegion': _regionForPosture(exercise.postureKey),
        'source': 'weekly_posture_recommendation',
        'catalogExerciseId': exercise.id,
        'postureKey': exercise.postureKey,
        'difficultyLevel': exercise.difficultyLevel,
        'sortOrder': index,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint(
      '[ExerciseRecommendationSyncService] synced ${exercises.length} exercises',
    );
  }

  int? _firstNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  int? _durationToSeconds(String value) {
    final amount = _firstNumber(value);
    if (amount == null) return null;
    final lower = value.toLowerCase();
    if (lower.contains('min')) return amount * 60;
    return amount;
  }

  String _regionForPosture(String postureKey) {
    switch (postureKey) {
      case 'forward_bending':
        return 'T4';
      case 'slouching':
        return 'L5';
      case 'backward_bending':
        return 'L5';
      case 'left_bending':
      case 'right_bending':
        return 'T12';
      default:
        return 'L5';
    }
  }
}
