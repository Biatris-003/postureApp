// ignore_for_file: unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/assigned_member.dart';
import '../../domain/entities/exercises/exercise.dart';

final advisorDashboardProvider = Provider((ref) => MockAdvisorDataService());

class MockAdvisorDataService {
  final List<AssignedMember> _members = [
    AssignedMember(uid: '1', name: 'John Doe', email: 'john@test.com', status: 'Improving', complianceRate: 0.85),
    AssignedMember(uid: '3', name: 'Jane Smith', email: 'jane@test.com', status: 'Needs Attention', complianceRate: 0.42),
    AssignedMember(uid: '4', name: 'Alice Johnson', email: 'alice@test.com', status: 'Stable', complianceRate: 0.70),
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
          description: 'Stand in a doorway with elbows bent at 90 degrees.\n'
              'Your forearms resting on the doorframe.\n'
              'Gently lean your body forward until you feel a stretch across chest and shoulders.\n'
              'Keep your back straight and shoulders relaxed.\n'
              'Hold for 20–30 seconds.',
          reps: '5 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'accessibility_new',
          imageUrl: 'assets/images/exercises/chest_stretch.png',
          videoAssetPath: 'assets/videos/chest_stretch.mp4',
        ),
        Exercise(
          id: 'ex2',
          title: 'Thoracic Back Extension',
          description: 'Sit in a chair with low to mid-level backrest.\n'
              'Place your hands gently behind your head to support your neck.\n'
              'Slowly lean backward, arching your upper back over the top edge of the chair.\n'
              'Hold for 5 seconds, then return to a neutral posture.',
          reps: '5 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/thoracic_back_extension.png',
          videoAssetPath: 'assets/videos/thoracic_back_extension.mp4',
        ),
        Exercise(
          id: 'ex3',
          title: 'Circumduction',
          description: 'Stand tall and extend one arm straight down by your side.\n'
              'Slowly move your arm in a large, controlled circle (forward, up, back, and down).\n'
              'Gradually increase the circle size.\n'
              'Do 10 circles forward, then 10 backward.',
          reps: '10 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/circumduction.png',
          videoAssetPath: 'assets/videos/circumduction.mp4',
        ),
        Exercise(
          id: 'ex4',
          title: 'Cat-Cow Stretch',
          description: 'Start on your hands and knees with a flat back.\n'
              'Inhale, drop your belly toward the floor, and lift your chest and tailbone upward.\n'
              'Exhale, round your spine up toward the ceiling, tuck your chin toward your chest.\n'
              'Maintain each position for 20–30 seconds then relax.',
          reps: '10 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/cat_cow.png',
          videoAssetPath: 'assets/videos/cat_cow.mp4',
        ),
        Exercise(
          id: 'ex5',
          title: 'Dead Bug',
          description: 'Lie on your back and point your arms straight up.\n'
              'Bend your knees at 90 degrees with shins parallel to the floor.\n'
              'Slowly lower your right arm and left leg toward the floor at the same time.\n'
              'Keep your lower back pressed into the floor, return, and switch sides.',
          reps: '12 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/dead_bug.png',
          videoAssetPath: 'assets/videos/dead_bug.mp4',
        ),
        Exercise(
          id: 'ex6',
          title: 'Bird Dog',
          description: 'Get on your hands and knees.\n'
              'Simultaneously extend your right arm forward and your left leg straight backward.\n'
              'Keep your back flat and your hips square to the floor.\n'
              'Return and switch sides.',
          reps: '10 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/bird_dog.png',
          videoAssetPath: 'assets/videos/bird_dog.mp4',
        ),
        Exercise(
          id: 'ex7',
          title: 'Hip Flexor Stretch',
          description: 'Kneel on your right knee with your left foot flat on the floor in front of you.\n'
              'Keep your torso upright and engage your abdominal muscles.\n'
              'Squeeze your right gluteal muscles to maintain a neutral pelvic position.\n'
              'Gently shift your hips forward until you feel a stretch at the front of your right hip.\n'
              'Hold for 20–30 seconds, then repeat on the opposite side.',
          reps: '5 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/hip_flexor_stretch.png',
          videoAssetPath: 'assets/videos/hip_flexor_stretch.mp4',
        ),
        Exercise(
          id: 'ex8',
          title: 'Tummy Twist',
          description: 'Lie on your back with your knees bent and feet flat.\n'
              'Keep your arms out wide to anchor your shoulders.\n'
              'Slowly let both knees fall to the right side, bring them back to center.\n'
              'Then let them fall to the left side to gently twist the lower back.',
          reps: '8 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/tummy_twist.png',
          videoAssetPath: 'assets/videos/tummy_twist.mp4',
        ),
        Exercise(
          id: 'ex9',
          title: 'Squatting',
          description: 'Stand with your feet shoulder-width apart.\n'
              'Push your hips back and bend your knees to lower yourself as if sitting in a chair.\n'
              'Keep your chest up and your heels on the ground.\n'
              'Push through your heels to stand back up.',
          reps: '12 reps', sets: '3 sets', duration: '5 mins',
          difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/squatting.png',
          videoAssetPath: 'assets/videos/squatting.mp4',
        ),
        Exercise(
          id: 'ex10',
          title: 'Plank',
          description: 'Hold a plank position on your forearms and toes.\n'
              'Keep your body in a straight line from head to heels.\n'
              'Engage your core throughout.\n'
              'Start with 20 seconds, gradually increase to 60 seconds.',
          reps: '3 reps', sets: '3 sets', duration: '5 mins',
          difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/plank.png',
          videoAssetPath: 'assets/videos/plank.mp4',
        ),
        Exercise(
          id: 'ex11',
          title: 'Glute Bridge',
          description: 'Lie on your back with knees bent and feet flat on the floor.\n'
              'Push your hips up, squeezing your glutes at the top.\n'
              'Hold for 2 seconds, then lower.\n'
              'Do 15 repetitions.',
          reps: '15 reps', sets: '3 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/glute_bridge.png',
          videoAssetPath: 'assets/videos/glute_bridge.mp4',
        ),
        Exercise(
          id: 'ex12',
          title: 'Leg Lift',
          description: 'Lie on your side.\n'
              'Lift your top leg slowly and with control.\n'
              'Lower it back down.\n'
              'Do 15 lifts per side for 3 sets.',
          reps: '15 reps', sets: '3 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/leg_lift.png',
          videoAssetPath: 'assets/videos/leg_lift.mp4',
        ),
        Exercise(
          id: 'ex13',
          title: 'Right Side Leg Raise',
          description: 'Stand tall or lie on your side.\n'
              'Keep your toes pointing straight ahead.\n'
              'Lift your right leg straight out to the side without tilting your torso.\n'
              'Lower it back down with control.',
          reps: '12 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/right_side_leg_raise.png',
          videoAssetPath: 'assets/videos/right_side_leg_raise.mp4',
        ),
        Exercise(
          id: 'ex14',
          title: 'Side Bending (Right)',
          description: 'Stand tall.\n'
              'Slowly slide your right hand down the side of your right leg, letting your torso bend to the right.\n'
              'Use your core to pull yourself back up to a straight standing position.\n'
              'Maintain position for 20 seconds then relax.',
          reps: '12 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/side_bending_right.png',
          videoAssetPath: 'assets/videos/side_bending_right.mp4',
        ),
        Exercise(
          id: 'ex15',
          title: 'Left Side Plank',
          description: 'Lie on your left side propped up on your left forearm with elbow directly under your shoulder.\n'
              'Lift your hips off the ground so your body forms a straight line from head to feet.\n'
              'Hold this position for 20–30 seconds.\n'
              'Do 3 sets.',
          reps: '3 reps', sets: '3 sets', duration: '5 mins',
          difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/left_side_plank.png',
          videoAssetPath: 'assets/videos/left_side_plank.mp4',
        ),
        Exercise(
          id: 'ex16',
          title: 'Micro-Break Walking',
          description: 'Stand up from your workspace.\n'
              'Take a relaxed walk around the room for 2–3 minutes.\n'
              'Used to get your blood circulating and relieve joint stiffness.',
          reps: '1 rep', sets: '1 set', duration: '3 mins',
          difficultyLevel: 'Beginner', iconCode: 'directions_walk',
          imageUrl: 'assets/images/exercises/micro_break_walking.png',
          videoAssetPath: 'assets/videos/micro_break_walking.mp4',
        ),
        Exercise(
          id: 'ex17',
          title: 'Neck Rotation',
          description: 'Sit or stand looking straight ahead.\n'
              'Slowly turn your head to look over your right shoulder.\n'
              'Hold for a gentle stretch, then return to the center.\n'
              'Look over your left shoulder. Do 10 rotations each direction.',
          reps: '10 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'accessibility_new',
          imageUrl: 'assets/images/exercises/neck_rotation.png',
          videoAssetPath: 'assets/videos/neck_rotation.mp4',
        ),
        Exercise(
          id: 'ex18',
          title: 'Sit to Stand',
          description: 'Sit near the edge of a sturdy chair.\n'
              'Cross your arms over your chest and lean forward slightly.\n'
              'Push through your heels to stand up.\n'
              'Slowly and with control, sit back down.',
          reps: '10 reps', sets: '2 sets', duration: '5 mins',
          difficultyLevel: 'Beginner', iconCode: 'fitness_center',
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

final exerciseProvider = NotifierProvider<ExerciseNotifier, Map<String, List<Exercise>>>(ExerciseNotifier.new);