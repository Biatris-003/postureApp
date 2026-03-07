class PostureData {
  final String postureClass;
  final double confidence;
  final DateTime timestamp;

  PostureData({
    required this.postureClass,
    required this.confidence,
    required this.timestamp,
  });
}
