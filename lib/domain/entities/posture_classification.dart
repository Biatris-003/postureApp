import 'package:cloud_firestore/cloud_firestore.dart';

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
      confidenceScore: (map['confidenceScore'] ?? map['confidence'] ?? 0.0).toDouble(),
      timestamp: _parseTimestamp(map['timestamp']),
      patientId: map['patientId'] ?? '',
      sessionId: map['sessionId'] ?? '',
    );
  }
  static DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now(); // fallback (prevents crash)
}
}