import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/exercises/exercise_model.dart';
import 'exercise_data.dart';

final exerciseRecommendationServiceProvider =
    Provider((ref) => ExerciseRecommendationService());

class ExerciseRecommendationService {
  /// Generates recommended exercises based on posture counts from statistics.
  ///
  /// Only postures exceeding [ExerciseData.recommendationThresholdPercent]
  /// of [totalReadings] are included; everything else is excluded entirely.
  /// The returned list is ordered by posture percentage descending (the
  /// posture the user struggled with most this period comes first).
  ///
  /// NOTE: reps/sets/difficulty on the returned models are fixed catalog
  /// values — they are NOT scaled by posture percentage. Percentage is
  /// used only to decide which postures qualify and what order their
  /// exercises appear in.
  ///
  /// Args:
  ///   postureCountMap: Map from posture labels to their counts
  ///                    e.g. {'forward_bending': 15, 'slouching': 8, ...}
  ///   totalReadings: Total number of readings (for percentage calculation)
  ///
  /// Returns: List of ExerciseModel, deduped, ordered by posture percentage.
  List<ExerciseModel> getRecommendedExercises({
    required Map<String, int> postureCountMap,
    required int totalReadings,
  }) {
    if (postureCountMap.isEmpty || totalReadings == 0) {
      return [];
    }

    // Use ExerciseData to build and filter exercises
    return ExerciseData.buildExerciseModels(
      postureCountMap: postureCountMap,
      totalReadings: totalReadings,
    );
  }

  /// Convenience method: takes postureCountMap only, calculates total
  List<ExerciseModel> getRecommendedExercisesFromCounts(
    Map<String, int> postureCountMap,
  ) {
    final total = postureCountMap.values.fold<int>(0, (sum, val) => sum + val);
    return getRecommendedExercises(
      postureCountMap: postureCountMap,
      totalReadings: total,
    );
  }
}