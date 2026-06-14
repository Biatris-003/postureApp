class Exercise {
  final String id;
  String title;
  String description;
  final String reps;
  final String sets;
  final String duration;        // ← add this
  final String difficultyLevel;
  final String iconCode;
  final String imageUrl;
  final String? videoAssetPath;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.reps,
    required this.sets,
    required this.duration,     // ← add this
    required this.difficultyLevel,
    required this.iconCode,
    required this.imageUrl,
    this.videoAssetPath,
  });

  Exercise copyWith({
    String? title,
    String? description,
    String? reps,
    String? sets,
    String? duration,           // ← add this
    String? difficultyLevel,
    String? imageUrl,
    String? videoAssetPath,
  }) {
    return Exercise(
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
    );
  }
}