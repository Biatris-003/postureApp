class Exercise {
  final String id;
  String title;
  String description;
  final String duration;
  final String frequency;
  final String iconCode;
  final String imageUrl;
  final String? modelUrl; // Adding modelUrl as optional

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.frequency,
    required this.iconCode,
    required this.imageUrl,
    this.modelUrl,
  });

  Exercise copyWith({
    String? title,
    String? description,
    String? duration,
    String? frequency,
    String? imageUrl,
    String? modelUrl,
  }) {
    return Exercise(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      frequency: frequency ?? this.frequency,
      iconCode: iconCode,
      imageUrl: imageUrl ?? this.imageUrl,
      modelUrl: modelUrl ?? this.modelUrl,
    );
  }
}
