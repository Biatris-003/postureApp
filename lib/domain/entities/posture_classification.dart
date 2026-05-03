class PostureClassification {
  final String classificationId;
  final String readingId;
  final String modelId;
  final String postureLabel;
  final double confidenceScore;
  final DateTime timestamp;
  final String patientId;
  final String sessionId;

  PostureClassification({
    required this.classificationId,
    required this.readingId,
    required this.modelId,
    required this.postureLabel,
    required this.confidenceScore,
    required this.timestamp,
    required this.patientId,
    required this.sessionId,
  });

  factory PostureClassification.fromMap(Map<String, dynamic> map, String docId) {
    return PostureClassification(
      classificationId: docId,
      readingId: map['readingId'] ?? '',
      modelId: map['modelId'] ?? '',
      postureLabel: map['postureLabel'] ?? '',
      confidenceScore: (map['confidenceScore'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(map['timestamp']),
      patientId: map['patientId'] ?? '',
      sessionId: map['sessionId'] ?? '',
    );
  }
}