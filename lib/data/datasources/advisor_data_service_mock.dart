// ignore_for_file: unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/assigned_member.dart';
import '../../domain/entities/exercises/exercise.dart';
import 'exercise_data.dart';

final advisorDashboardProvider = Provider((ref) => MockAdvisorDataService());

class MockAdvisorDataService {
  final List<AssignedMember> _members = [
    AssignedMember(
      uid: '1',
      name: 'John Doe',
      email: 'john@test.com',
      status: 'Improving',
      complianceRate: 0.85,
    ),
    AssignedMember(
      uid: '3',
      name: 'Jane Smith',
      email: 'jane@test.com',
      status: 'Needs Attention',
      complianceRate: 0.42,
    ),
    AssignedMember(
      uid: '4',
      name: 'Alice Johnson',
      email: 'alice@test.com',
      status: 'Stable',
      complianceRate: 0.70,
    ),
  ];

  Future<List<AssignedMember>> getAssignedMembers() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _members;
  }
}

/// Holds each patient's assigned exercise plan.
///
/// Exercise data itself (title, description, reps, image/video paths, etc.)
/// lives ONLY in ExerciseData.catalog — this notifier just decides which
/// catalog exercises are assigned to which patient.
///
/// `state` starts empty (no per-patient overrides yet). Any lookup for a
/// patient with no override falls back to the full default catalog — see
/// `getExercisesForMember` and the top-level `effectivePlanFor` helper
/// below. Screens that currently read `mappedExercises[userId] ?? []`
/// directly should switch to `effectivePlanFor(mappedExercises, userId)`
/// so they get the catalog fallback instead of an empty list for any user
/// who hasn't been given a custom override.
class ExerciseNotifier extends Notifier<Map<String, List<Exercise>>> {
  @override
  Map<String, List<Exercise>> build() => {};

  /// The exercise plan for [uid]: a per-patient override if one has been
  /// set via [updateExercise], otherwise the full default catalog.
  List<Exercise> getExercisesForMember(String uid) {
    return state[uid] ?? ExerciseData.catalog;
  }

  void updateExercise(String memberUid, Exercise updatedExercise) {
    final memberExercises = state[memberUid] ?? ExerciseData.catalog;

    final index = memberExercises.indexWhere((e) => e.id == updatedExercise.id);
    if (index == -1) return;

    final newList = List<Exercise>.from(memberExercises);
    newList[index] = updatedExercise;
    state = {...state, memberUid: newList};
  }
}

final exerciseProvider =
    NotifierProvider<ExerciseNotifier, Map<String, List<Exercise>>>(
  ExerciseNotifier.new,
);

/// Helper for screens that read `mappedExercises[userId]` directly: returns
/// the patient's override plan if one exists, otherwise the full default
/// catalog — so every user sees the full exercise list instead of an empty
/// plan when no override has been set yet.
///
///   final defaultExercises = effectivePlanFor(mappedExercises, userId);
List<Exercise> effectivePlanFor(
  Map<String, List<Exercise>> mappedExercises,
  String userId,
) {
  return mappedExercises[userId] ?? ExerciseData.catalog;
}