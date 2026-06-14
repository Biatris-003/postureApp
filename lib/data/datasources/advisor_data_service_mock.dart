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

// ─── Placeholder reps/sets logic (to be replaced with real stats later) ───────
// Currently returns Beginner by default.
// TODO: Replace with real posture percentage calculation.
Map<String, String> _calcRepsAndSets(String dominantPosture, Map<String, int> postureCounts) {
  // PLACEHOLDER: always returns beginner values for now
  return {'reps': '5 reps', 'sets': '2 sets', 'difficulty': 'Beginner'};
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
        title: 'Circumduction',
        description: 'Stand with arms at sides.\n'
            'Make slow, controlled circles with your arms.\n'
            'Gradually increase the circle size.\n'
            'Do 10 circles forward, then 10 backward.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/circumduction.png',
        videoAssetPath: 'assets/videos/circumduction.mp4',
      ),
      Exercise(
        id: 'ex3',
        title: 'Scapular Retractions',
        description: 'Sit upright.\n'
            'Squeeze your shoulder blades together as if pinching a pencil between them.\n'
            'Hold for 3 seconds, then release.\n'
            'Repeat 15 times.',
        reps: '15 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/thoracic_back_extension.png',
        videoAssetPath: 'assets/videos/thoracic_back_extension.mp4',
      ),
      Exercise(
        id: 'ex4',
        title: 'Chin Tucks',
        description: 'Sit or stand looking straight ahead.\n'
            'Pull your chin and head straight backward (like making a double chin).\n'
            'Without tilting your head up or down.\n'
            'Hold for 5 seconds, then release.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/chin_tucks.png',
        videoAssetPath: 'assets/videos/chin_tucks.mp4',
      ),
      Exercise(
        id: 'ex5',
        title: 'Cat-Cow Stretch',
        description: 'Start on hands and knees.\n'
            'Arch your back upward toward the ceiling (cat).\n'
            'Then drop your belly toward the floor and lift your head (cow).\n'
            'Do 10 full cycles slowly.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/cat-cow_stretch.png',
        videoAssetPath: 'assets/videos/cat-cow_stretch.mp4',
      ),
      Exercise(
        id: 'ex6',
        title: 'Dead Bug',
        description: 'Lie on your back with arms toward the ceiling and knees bent at 90°.\n'
            'Slowly extend your right arm and left leg toward the floor.\n'
            'Return to start, then alternate sides.\n'
            'Complete 12 total repetitions.',
        reps: '12 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/dead_bug.png',
        videoAssetPath: 'assets/videos/dead_bug.mp4',
      ),
      Exercise(
        id: 'ex7',
        title: 'Bird Dog',
        description: 'Start on hands and knees.\n'
            'Extend your right arm and left leg straight out.\n'
            'Hold for 2 seconds, then return.\n'
            'Alternate sides for 10 repetitions each.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/bird_dog.png',
        videoAssetPath: 'assets/videos/bird_dog.mp4',
      ),
      Exercise(
        id: 'ex8',
        title: 'Tummy Twist',
        description: 'Sit with knees bent to one side.\n'
            'Twist your torso toward the opposite direction.\n'
            'Hold for 15 seconds.\n'
            'Repeat on the other side.',
        reps: '8 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/tummy_twist.png',
        videoAssetPath: 'assets/videos/tummy_twist.mp4',
      ),
      Exercise(
        id: 'ex9',
        title: 'Squatting',
        description: 'Stand with feet shoulder-width apart.\n'
            'Lower your body as if sitting in a chair, keeping chest up.\n'
            'Keep knees tracking over toes.\n'
            'Do 12 controlled repetitions.',
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
        title: 'Glute Bridges',
        description: 'Lie on your back with knees bent and feet flat on the floor.\n'
            'Push your hips up, squeezing your glutes at the top.\n'
            'Hold for 2 seconds, then lower.\n'
            'Do 15 repetitions.',
        reps: '15 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/glute_bridges.png',
        videoAssetPath: 'assets/videos/glute_bridges.mp4',
      ),
      Exercise(
        id: 'ex12',
        title: 'Leg Bent',
        description: 'Lie face down.\n'
            'Bend one knee to 90 degrees.\n'
            'Hold for 2 seconds, then lower.\n'
            'Do 12 repetitions each leg.',
        reps: '12 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/leg_bent.png',
        videoAssetPath: 'assets/videos/leg_bent.mp4',
      ),
      Exercise(
        id: 'ex13',
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
        id: 'ex14',
        title: 'Right Side Plank',
        description: 'Lie on your right side.\n'
            'Lift your body on your right forearm and feet stacked.\n'
            'Keep your body in a straight line.\n'
            'Hold for 20–30 seconds for 3 sets.',
        reps: '3 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/right_side_plank.png',
        videoAssetPath: 'assets/videos/right_side_plank.mp4',
      ),
      Exercise(
        id: 'ex15',
        title: 'Flamingo Stand (Right Leg)',
        description: 'Stand upright near a wall if needed.\n'
            'Lift your left foot off the ground and balance on your right leg.\n'
            'Keep your knee slightly bent.\n'
            'Hold for 20 seconds, repeat 3 times.',
        reps: '3 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/flamingo_stand_right_leg.png',
        videoAssetPath: 'assets/videos/flamingo_stand_right_leg.mp4',
      ),
      Exercise(
        id: 'ex16',
        title: 'Side Bending (Right)',
        description: 'Stand with feet shoulder-width apart.\n'
            'Place hands behind your head.\n'
            'Bend to the right at the waist.\n'
            'Do 12 controlled repetitions.',
        reps: '12 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/side_bending_right.png',
        videoAssetPath: 'assets/videos/side_bending_right.mp4',
      ),
      Exercise(
        id: 'ex17',
        title: 'Single Leg Balance (Right)',
        description: 'Stand on your right leg.\n'
            'Keep your core engaged and gaze fixed ahead.\n'
            'Hold for 30 seconds.\n'
            'Do 3 sets per leg.',
        reps: '3 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/single_leg_balance_right.png',
        videoAssetPath: 'assets/videos/single_leg_balance_right.mp4',
      ),
      Exercise(
        id: 'ex18',
        title: 'Left Side Plank',
        description: 'Lie on your left side.\n'
            'Lift your body on your left forearm and feet stacked.\n'
            'Keep your body in a straight line.\n'
            'Hold for 20–30 seconds for 3 sets.',
        reps: '3 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Intermediate', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/left_side_plank.png',
        videoAssetPath: 'assets/videos/left_side_plank.mp4',
      ),
      Exercise(
        id: 'ex19',
        title: 'Flamingo Stand (Left Leg)',
        description: 'Stand upright near a wall if needed.\n'
            'Lift your right foot off the ground and balance on your left leg.\n'
            'Keep your knee slightly bent.\n'
            'Hold for 20 seconds, repeat 3 times.',
        reps: '3 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/flamingo_stand_left_leg.png',
        videoAssetPath: 'assets/videos/flamingo_stand_left_leg.mp4',
      ),
      Exercise(
        id: 'ex20',
        title: 'Side Bending (Left)',
        description: 'Stand with feet shoulder-width apart.\n'
            'Place hands behind your head.\n'
            'Bend to the left at the waist.\n'
            'Do 12 controlled repetitions.',
        reps: '12 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/side_bending_left.png',
        videoAssetPath: 'assets/videos/side_bending_left.mp4',
      ),
      Exercise(
        id: 'ex21',
        title: 'Single Leg Balance (Left)',
        description: 'Stand on your left leg.\n'
            'Keep your core engaged and gaze fixed ahead.\n'
            'Hold for 30 seconds.\n'
            'Do 3 sets per leg.',
        reps: '3 reps', sets: '3 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/single_leg_balance_left.png',
        videoAssetPath: 'assets/videos/single_leg_balance_left.mp4',
      ),
      Exercise(
        id: 'ex22',
        title: 'Neck Rotation',
        description: 'Sit or stand looking straight ahead.\n'
            'Slowly turn your head to look over your right shoulder.\n'
            'Hold for a gentle stretch, then return to center.\n'
            'Repeat on the left side. Do 10 each direction.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'accessibility_new',
        imageUrl: 'assets/images/exercises/neck_rotation.png',
        videoAssetPath: 'assets/videos/neck_rotation.mp4',
      ),
      Exercise(
        id: 'ex23',
        title: 'Shoulder Rolls',
        description: 'Sit or stand upright.\n'
            'Roll your shoulders backward 10 times.\n'
            'Then roll them forward 10 times.\n'
            'Repeat for 2 sets.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'accessibility_new',
        imageUrl: 'assets/images/exercises/shoulder_rolls.png',
        videoAssetPath: 'assets/videos/shoulder_rolls.mp4',
      ),
      Exercise(
        id: 'ex24',
        title: 'Sit to Stand',
        description: 'Start seated in a chair with feet flat on the floor.\n'
            'Lean slightly forward and push through your heels.\n'
            'Stand up smoothly without using your hands.\n'
            'Lower back down with control. Do 10 repetitions.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/sit_to_stand.png',
        videoAssetPath: 'assets/videos/sit_to_stand.mp4',
      ),
      Exercise(
        id: 'ex25',
        title: 'Foot Circles',
        description: 'Sit comfortably in a chair.\n'
            'Lift one foot slightly off the floor.\n'
            'Make slow circles with your foot.\n'
            'Do 10 circles each direction per foot.',
        reps: '10 reps', sets: '2 sets', duration: '5 mins',
        difficultyLevel: 'Beginner', iconCode: 'fitness_center',
        imageUrl: 'assets/images/exercises/foot_circles.png',
        videoAssetPath: 'assets/videos/foot_circles.mp4',
      ),
    ],
      '3': [
        Exercise(
          id: 'ex4',
          title: 'Thoracic Extension',
          description: 'Sit in a chair with a low to mid-level backrest.\n'
              'Place your hands gently behind your head to support your neck.\n'
              'Slowly lean backward, arching your upper back over the top edge of the chair.\n'
              'Hold for 5 seconds, then return to neutral posture.',
          reps: '5 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'fitness_center',
          imageUrl: 'assets/images/exercises/thoracic_extension.png',
          videoAssetPath: 'assets/videos/thoracic_extension.mp4',
        ),
      ],
      '4': [
        Exercise(
          id: 'ex5',
          title: 'Neck Rotations',
          description: 'Sit or stand looking straight ahead.\n'
              'Slowly turn your head to look over your right shoulder.\n'
              'Hold for a gentle stretch, then return to center.\n'
              'Repeat on the left shoulder.',
          reps: '5 reps',
          sets: '2 sets',
          duration: '5 mins',
          difficultyLevel: 'Beginner',
          iconCode: 'accessibility_new',
          imageUrl: 'assets/images/exercises/neck_rotations.png',
          videoAssetPath: 'assets/videos/neck_rotations.mp4',
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
