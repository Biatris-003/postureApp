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

// Global state to hold exercises per member so edits reflect immediately
class ExerciseNotifier extends Notifier<Map<String, List<Exercise>>> {
  @override
  Map<String, List<Exercise>> build() {
    return {
      '1': [
        Exercise(id: 'ex1', title: 'Chin Tucks', description: 'Pull your chin straight back, as if making a double chin. Hold for 5 seconds.', duration: '3 mins', frequency: 'Daily', iconCode: 'fitness_center', imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=1000&auto=format&fit=crop', modelUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb'),
        Exercise(id: 'ex2', title: 'Chest Opener', description: 'Clasp hands behind your back and squeeze shoulder blades together.', duration: '5 mins', frequency: 'Twice Daily', iconCode: 'accessibility_new', imageUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?q=80&w=1000&auto=format&fit=crop', modelUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb'),
        Exercise(id: 'ex3', title: 'Wall Angels', description: 'Stand against a wall and slowly slide arms up and down.', duration: '5 mins', frequency: 'Daily', iconCode: 'pan_tool', imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=1000&auto=format&fit=crop', modelUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb'),
      ],
      '3': [
        Exercise(id: 'ex4', title: 'Thoric Extension', description: 'Lie on a foam roller and extend your upper back.', duration: '10 mins', frequency: 'Daily', iconCode: 'fitness_center', imageUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?q=80&w=1000&auto=format&fit=crop', modelUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb'),
      ],
      '4': [
        Exercise(id: 'ex5', title: 'Neck stretches', description: 'Gently pull your head to each side.', duration: '2 mins', frequency: '3x Daily', iconCode: 'accessibility_new', imageUrl: 'https://images.unsplash.com/photo-1599901860904-17e08c2d4bc5?q=80&w=1000&auto=format&fit=crop', modelUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb'),
      ]
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
