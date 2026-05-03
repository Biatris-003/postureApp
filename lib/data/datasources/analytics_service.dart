import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/posture_classification.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // All posture labels
  static const List<String> allLabels = [
    'upright',
    'forward_bending',
    'backward_bending',
    'slouching',
    'left_bending',
    'right_bending',
  ];

  // Good posture = only upright
  static const String goodPosture = 'upright';

  // ─── FETCH DATA ───────────────────────────────────────────────

  // Get all classifications for a patient (all time)
  Future<List<PostureClassification>> getAllClassifications(String patientId) async {
    final snapshot = await _db
        .collection('postureClassifications')
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp')
        .get();

    return snapshot.docs
        .map((doc) => PostureClassification.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get classifications for a specific session
  Future<List<PostureClassification>> getSessionClassifications(
      String patientId, String sessionId) async {
    final snapshot = await _db
        .collection('postureClassifications')
        .where('patientId', isEqualTo: patientId)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp')
        .get();

    return snapshot.docs
        .map((doc) => PostureClassification.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get classifications for last N days
  Future<List<PostureClassification>> getClassificationsByDays(
      String patientId, int days) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _db
        .collection('postureClassifications')
        .where('patientId', isEqualTo: patientId)
        .where('timestamp', isGreaterThan: since.toIso8601String())
        .orderBy('timestamp')
        .get();

    return snapshot.docs
        .map((doc) => PostureClassification.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ─── CALCULATE STATS ──────────────────────────────────────────

  // Posture score (0-100) = % of upright readings
  int calculatePostureScore(List<PostureClassification> data) {
    if (data.isEmpty) return 0;
    final upright = data.where((d) => d.postureLabel == goodPosture).length;
    return ((upright / data.length) * 100).round();
  }

  // Count each posture label
  Map<String, int> calculatePostureCounts(List<PostureClassification> data) {
    final counts = <String, int>{};
    for (final label in allLabels) {
      counts[label] = data.where((d) => d.postureLabel == label).length;
    }
    return counts;
  }

  // Calculate % for each posture
  Map<String, double> calculatePosturePercentages(List<PostureClassification> data) {
    if (data.isEmpty) return {for (var l in allLabels) l: 0.0};
    final counts = calculatePostureCounts(data);
    return counts.map((label, count) =>
        MapEntry(label, (count / data.length) * 100));
  }

  // Most problematic posture (most frequent bad posture)
  String getMostProblematicPosture(List<PostureClassification> data) {
    final badData = data.where((d) => d.postureLabel != goodPosture).toList();
    if (badData.isEmpty) return 'none';
    final counts = calculatePostureCounts(badData);
    counts.remove(goodPosture);
    return counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // Trend data — group by day, calc daily score
  // Returns list of {date, score} for line chart
  // Daily — group by hour (24 points)
  List<Map<String, dynamic>> calculateHourlyTrend(
      List<PostureClassification> data) {
    final trend = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    for (int hour = 0; hour < 24; hour++) {
      final hourStart = dayStart.add(Duration(hours: hour));
      final hourEnd = hourStart.add(const Duration(hours: 1));

      final hourData = data.where((d) =>
          d.timestamp.isAfter(hourStart) &&
          d.timestamp.isBefore(hourEnd)).toList();

      trend.add({
        'label': '${hour.toString().padLeft(2, '0')}:00',
        'score': hourData.isEmpty ? -1 : calculatePostureScore(hourData),
        'totalReadings': hourData.length,
      });
    }
    return trend;
  }

  // Weekly — group by day (7 points)
  List<Map<String, dynamic>> calculateWeeklyTrend(
      List<PostureClassification> data) {
    final trend = <Map<String, dynamic>>[];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayData = data.where((d) =>
          d.timestamp.isAfter(dayStart) &&
          d.timestamp.isBefore(dayEnd)).toList();

      trend.add({
        'label': dayNames[dayStart.weekday - 1],
        'score': dayData.isEmpty ? -1 : calculatePostureScore(dayData),
        'totalReadings': dayData.length,
      });
    }
    return trend;
  }

  // Monthly — group by day (30 points)
  List<Map<String, dynamic>> calculateMonthlyTrend(
      List<PostureClassification> data) {
    final trend = <Map<String, dynamic>>[];

    for (int i = 29; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayData = data.where((d) =>
          d.timestamp.isAfter(dayStart) &&
          d.timestamp.isBefore(dayEnd)).toList();

      trend.add({
        'label': '${day.day}/${day.month}',
        'score': dayData.isEmpty ? -1 : calculatePostureScore(dayData),
        'totalReadings': dayData.length,
      });
    }
    return trend;
  }

  // Total wearing time in minutes for a session
  Future<int> getSessionDurationMinutes(String sessionId) async {
    final doc = await _db.collection('sessions').doc(sessionId).get();
    if (!doc.exists) return 0;
    final data = doc.data()!;
    final start = DateTime.parse(data['startTimestamp']);
    final end = DateTime.parse(data['endTimestamp']);
    return end.difference(start).inMinutes;
  }

  // Total alerts count for a patient
  Future<int> getTotalAlerts(String patientId) async {
    final snapshot = await _db
        .collection('alerts')
        .where('patientId', isEqualTo: patientId)
        .get();
    return snapshot.docs.length;
  }
}