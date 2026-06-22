import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/auth_service_mock.dart';
import '../data/datasources/exercise_recommendation_service.dart';
import '../data/datasources/exercise_recommendation_sync_service.dart';
import '../domain/entities/exercises/exercise_model.dart';
import 'weekly_posture_counts_provider.dart';

final exerciseRecommendationSyncServiceProvider =
    Provider((ref) => ExerciseRecommendationSyncService());

final recommendedExercisesProvider =
    FutureProvider<List<ExerciseModel>>((ref) async {
  final user = ref.watch(authStateProvider);
  final postureCountMap = await ref.watch(weeklyPostureCountsProvider.future);
  final recommendationService = ref.watch(exerciseRecommendationServiceProvider);
  final recommendedExercises =
      recommendationService.getRecommendedExercisesFromCounts(postureCountMap);

  if (user != null) {
    try {
      await ref
          .watch(exerciseRecommendationSyncServiceProvider)
          .syncRecommendedExercises(
            firebaseUid: user.userId,
            legacyUserId: user.uid,
            exercises: recommendedExercises,
          );
    } catch (error, stackTrace) {
      debugPrint(
        '[recommendedExercisesProvider] failed to sync recommendations: '
        '$error\n$stackTrace',
      );
    }
  }

  return recommendedExercises;
});
