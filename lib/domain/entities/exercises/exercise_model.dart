import 'exercise.dart';

class ExerciseModel extends Exercise {
  final String postureKey; // Which bad posture triggered this exercise

  ExerciseModel({
    required super.id,
    required super.title,
    required super.description,
    required super.reps,
    required super.sets,
    required super.duration,        
    required super.difficultyLevel,
    required super.iconCode,
    required super.imageUrl,
    super.videoAssetPath,
    required this.postureKey,
  });

  @override
  ExerciseModel copyWith({
    String? title,
    String? description,
    String? reps,
    String? sets,
    String? duration,               // ← add this
    String? difficultyLevel,
    String? imageUrl,
    String? videoAssetPath,
    String? postureKey,
  }) {
    return ExerciseModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      reps: reps ?? this.reps,
      sets: sets ?? this.sets,
      duration: duration ?? this.duration,   // ← add this
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      iconCode: iconCode,
      imageUrl: imageUrl ?? this.imageUrl,
      videoAssetPath: videoAssetPath ?? this.videoAssetPath,
      postureKey: postureKey ?? this.postureKey,
    );
  }
}