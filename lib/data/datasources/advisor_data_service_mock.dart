// ignore_for_file: unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/assigned_member.dart';
import '../../domain/entities/exercises/exercise.dart';

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

class ExerciseNotifier extends Notifier<Map<String, List<Exercise>>> {
  @override
  Map<String, List<Exercise>> build() {
    return {
      'patient001': [
        Exercise(
          id: 'ex1',
          title: 'Chest Stretch',
          description: '',
          reps: '5 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'accessibility_new',
          imageUrl: 'assets/images/exercises/chest_stretch.png',
          videoAssetPath: 'assets/videos/chest_stretch.mp4',
        ),
        Exercise(
          id: 'ex2',
          title: 'Thoracic Back Extension',
          description: '',
          reps: '5 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/thoracic_back_extension.png',
          videoAssetPath: 'assets/videos/thoracic_back_extension.mp4',
        ),
        Exercise(
          id: 'ex3',
          title: 'Circumduction',
          description: '',
          reps: '10 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/circumduction.png',
          videoAssetPath: 'assets/videos/circumduction.mp4',
        ),
        Exercise(
          id: 'ex4',
          title: 'Cat-Cow',
          description: '',
          reps: '10 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/cat_cow.png',
          videoAssetPath: 'assets/videos/cat_cow.mp4',
        ),
        Exercise(
          id: 'ex5',
          title: 'Dead Bug',
          description: '',
          reps: '12 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Intermediate',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/dead_bug.png',
          videoAssetPath: 'assets/videos/dead_bug.mp4',
        ),
        Exercise(
          id: 'ex6',
          title: 'Bird Dog',
          description: '',
          reps: '10 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/bird_dog.png',
          videoAssetPath: 'assets/videos/bird_dog.mp4',
        ),
        Exercise(
          id: 'ex7',
          title: 'Hip Flexor Stretch',
          description: '',
          reps: '5 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/hip_flexor_stretch.png',
          videoAssetPath: 'assets/videos/hip_flexor_stretch.mp4',
        ),
        Exercise(
          id: 'ex8',
          title: 'Tummy Twist',
          description: '',
          reps: '8 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/tummy_twist.png',
          videoAssetPath: 'assets/videos/tummy_twist.mp4',
        ),
        Exercise(
          id: 'ex9',
          title: 'Squatting',
          description: '',
          reps: '12 reps',
          sets: '3 sets',
          duration: '5 mins',
          difficultyLevel: 'Intermediate',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/squatting.png',
          videoAssetPath: 'assets/videos/squatting.mp4',
        ),
        Exercise(
          id: 'ex10',
          title: 'Plank',
          description: '',
          reps: '3 reps',
          sets: '3 sets',
          duration: '5 mins',
          difficultyLevel: 'Intermediate',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/plank.png',
          videoAssetPath: 'assets/videos/plank.mp4',
        ),
        Exercise(
          id: 'ex11',
          title: 'Glute Bridge',
          description: '',
          reps: '15 reps',
          sets: '3 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/glute_bridge.png',
          videoAssetPath: 'assets/videos/glute_bridge.mp4',
        ),
        Exercise(
          id: 'ex12',
          title: 'Leg Lift',
          description: '',
          reps: '15 reps',
          sets: '3 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/leg_lift.png',
          videoAssetPath: 'assets/videos/leg_lift.mp4',
        ),
        Exercise(
          id: 'ex13',
          title: 'Right Side Leg Raise',
          description: '',
          reps: '12 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/right_side_leg_raise.png',
          videoAssetPath: 'assets/videos/right_side_leg_raise.mp4',
        ),
        Exercise(
          id: 'ex14',
          title: 'Side Bending Right',
          description: '',
          reps: '12 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/side_bending_right.png',
          videoAssetPath: 'assets/videos/side_bending_right.mp4',
        ),
        Exercise(
          id: 'ex15',
          title: 'Left Side Plank',
          description: '',
          reps: '3 reps',
          sets: '3 sets',
          duration: '5 mins',
          difficultyLevel: 'Intermediate',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/left_side_plank.png',
          videoAssetPath: 'assets/videos/left_side_plank.mp4',
        ),
        Exercise(
          id: 'ex16',
          title: 'Micro Break Walking',
          description: '',
          reps: '1 rep',
          sets: '1 set',
          duration: '3 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'directions_walk',
          imageUrl: 'assets/images/exercises/micro_break_walking.png',
          videoAssetPath: 'assets/videos/micro_break_walking.mp4',
        ),
        Exercise(
          id: 'ex17',
          title: 'Neck Rotation',
          description: '',
          reps: '10 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'accessibility_new',
          imageUrl: 'assets/images/exercises/neck_rotation.png',
          videoAssetPath: 'assets/videos/neck_rotation.mp4',
        ),
        Exercise(
          id: 'ex18',
          title: 'Sit to Stand',
          description: '',
          reps: '10 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/sit_to_stand.png',
          videoAssetPath: 'assets/videos/sit_to_stand.mp4',
        ),
      ],
    };
  }

  List<Exercise> getExercisesForMember(String uid) {
    return state[uid] ?? [];
  }

  void updateExercise(String memberUid, Exercise updatedExercise) {
    final memberExercises = state[memberUid];
    if (memberExercises == null) return;

    final index = memberExercises.indexWhere((e) => e.id == updatedExercise.id);
    if (index != -1) {
      final newList = List<Exercise>.from(memberExercises);
      newList[index] = updatedExercise;
      state = {...state, memberUid: newList};
    }
  }
}

final exerciseProvider =
    NotifierProvider<ExerciseNotifier, Map<String, List<Exercise>>>(
  ExerciseNotifier.new,
);