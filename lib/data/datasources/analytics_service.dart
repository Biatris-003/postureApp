import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/posture_classification.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Resolves the patient identifier used by saved sessions and posture
  /// classifications. Newer records link patients with Firebase's UID;
  /// the legacy app userId is retained as a fallback for older records.
  Future<String?> resolvePatientId({
    required String firebaseUid,
    String? legacyUserId,
  }) async {
    Future<String?> findByUserId(String userId) async {
      final snapshot = await _db
          .collection('patients')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final document = snapshot.docs.first;
      return document.data()['patientId'] as String? ?? document.id;
    }

    final byFirebaseUid = await findByUserId(firebaseUid);
    if (byFirebaseUid != null) return byFirebaseUid;

    if (legacyUserId != null && legacyUserId != firebaseUid) {
      final byLegacyUserId = await findByUserId(legacyUserId);
      if (byLegacyUserId != null) return byLegacyUserId;
    }

    final directDocument = await _db
        .collection('patients')
        .doc(firebaseUid)
        .get();
    if (!directDocument.exists) return null;
    return directDocument.data()?['patientId'] as String? ?? directDocument.id;
  }

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

Future<List<PostureClassification>> getTodayClassifications(
  String patientId,
) async {
  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final sinceTimestamp = Timestamp.fromDate(todayMidnight);

  final snapshot = await _db
      .collection('postureClassifications')
      .where('patientId', isEqualTo: patientId)
      .where('timestamp', isGreaterThanOrEqualTo: sinceTimestamp)
      .orderBy('timestamp')
      .get();

  final classifications = snapshot.docs
      .map((doc) => PostureClassification.fromMap(doc.data(), doc.id))
      .toList();

  // ✅ ADD THIS: fallback to statistics collection if no live readings
  if (classifications.isNotEmpty) return classifications;

  final dateKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final docId = '${patientId}_$dateKey';

  final statDoc = await _db.collection('statistics').doc(docId).get();
  if (!statDoc.exists) return [];

  final data = statDoc.data()!;
  final counts = data['counts'];
  if (counts is! Map) return [];

  final result = <PostureClassification>[];
  for (final label in allLabels) {
    final count = (counts[label] as num?)?.toInt() ?? 0;
    for (var i = 0; i < count; i++) {
      result.add(PostureClassification(
        classificationId: '${docId}_${label}_$i',
        readingId: '',
        modelId: 'daily_statistics',
        postureLabel: label,
        confidenceScore: 1,
        timestamp: todayMidnight.add(Duration(seconds: i)),
        patientId: patientId,
        sessionId: '',
      ));
    }
  }
  return result;
}

  Future<void> saveDailyStatistics(
    String patientId,
    List<PostureClassification> data,
  ) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final docId = '${patientId}_$dateKey'; // e.g. "test_patient_001_2026-05-09"

    final percentages = calculatePosturePercentages(data);
    final counts = calculatePostureCounts(data);
    final score = calculatePostureScore(data);
    final problematic = getMostProblematicPosture(data);
    final uprightCount = counts['upright'] ?? 0;

    await _db.collection('statistics').doc(docId).set({
      'patientId': patientId,
      'date': dateKey,
      'timestamp': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),

      'postureScore': score,
      'totalReadings': data.length,
      'mostProblematicPosture': problematic,
      'uprightMinutes': uprightCount * 2,

      'counts': {
        'upright': counts['upright'] ?? 0,
        'forward_bending': counts['forward_bending'] ?? 0,
        'backward_bending': counts['backward_bending'] ?? 0,
        'slouching': counts['slouching'] ?? 0,
        'left_bending': counts['left_bending'] ?? 0,
        'right_bending': counts['right_bending'] ?? 0,
      },

      'percentages': {
        'upright': percentages['upright'] ?? 0.0,
        'forward_bending': percentages['forward_bending'] ?? 0.0,
        'backward_bending': percentages['backward_bending'] ?? 0.0,
        'slouching': percentages['slouching'] ?? 0.0,
        'left_bending': percentages['left_bending'] ?? 0.0,
        'right_bending': percentages['right_bending'] ?? 0.0,
      },

      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get all classifications for a patient (all time)
  Future<List<PostureClassification>> getAllClassifications(
    String patientId,
  ) async {
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
    String patientId,
    String sessionId,
  ) async {
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
  // Future<List<PostureClassification>> getClassificationsByDays(
  //     String patientId, int days) async {
  //   final since = DateTime.now().subtract(Duration(days: days));
  //   final sinceTimestamp = Timestamp.fromDate(since);
  //   final snapshot = await _db
  //       .collection('postureClassifications')
  //       .where('patientId', isEqualTo: patientId)
  //       .where('timestamp', isGreaterThan: sinceTimestamp)
  //       .orderBy('timestamp')
  //       .get();

  //   return snapshot.docs
  //       .map((doc) => PostureClassification.fromMap(doc.data(), doc.id))
  //       .toList();
  // }

  Future<List<PostureClassification>> getClassificationsByDays(
    String patientId,
    int days,
  ) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final classificationSnapshot = await _db
        .collection('postureClassifications')
        .where('patientId', isEqualTo: patientId)
        .get();

    final classifications = classificationSnapshot.docs
        .map((doc) => PostureClassification.fromMap(doc.data(), doc.id))
        .where((classification) => !classification.timestamp.isBefore(since))
        .toList();
    classifications.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (classifications.isNotEmpty) return classifications;

    final statisticsSnapshot = await _db
        .collection('statistics')
        .where('patientId', isEqualTo: patientId)
        .get();

    final result = <PostureClassification>[];
    for (final document in statisticsSnapshot.docs) {
      final data = document.data();
      final day = _statisticsDate(data['timestamp'] ?? data['date']);
      if (day == null || day.isBefore(since)) continue;

      final counts = data['counts'];
      if (counts is! Map) continue;

      for (final label in allLabels) {
        final count = (counts[label] as num?)?.toInt() ?? 0;
        for (var index = 0; index < count; index++) {
          result.add(
            PostureClassification(
              classificationId: '${document.id}_${label}_$index',
              readingId: '',
              modelId: 'daily_statistics',
              postureLabel: label,
              confidenceScore: 1,
              timestamp: day.add(Duration(seconds: index)),
              patientId: patientId,
              sessionId: '',
            ),
          );
        }
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  DateTime? _statisticsDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
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
  Map<String, double> calculatePosturePercentages(
    List<PostureClassification> data,
  ) {
    if (data.isEmpty) return {for (var l in allLabels) l: 0.0};
    final counts = calculatePostureCounts(data);
    return counts.map(
      (label, count) => MapEntry(label, (count / data.length) * 100),
    );
  }

  // Most problematic posture (most frequent bad posture)
  String getMostProblematicPosture(List<PostureClassification> data) {
    final badData = data.where((d) => d.postureLabel != goodPosture).toList();
    if (badData.isEmpty) return 'none';
    final counts = calculatePostureCounts(badData);
    counts.remove(goodPosture);
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Trend data — group by day, calc daily score
  // Returns list of {date, score} for line chart
  // Daily — group by hour (24 points)
  List<Map<String, dynamic>> calculateHourlyTrend(
    List<PostureClassification> data,
  ) {
    final trend = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    for (int hour = 0; hour < 24; hour++) {
      final hourStart = dayStart.add(Duration(hours: hour));
      final hourEnd = hourStart.add(const Duration(hours: 1));

      final hourData = data
          .where(
            (d) =>
                d.timestamp.isAfter(hourStart) && d.timestamp.isBefore(hourEnd),
          )
          .toList();

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
    List<PostureClassification> data,
  ) {
    final trend = <Map<String, dynamic>>[];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayData = data
          .where(
            (d) =>
                d.timestamp.isAfter(dayStart) && d.timestamp.isBefore(dayEnd),
          )
          .toList();

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
    List<PostureClassification> data,
  ) {
    final trend = <Map<String, dynamic>>[];

    for (int i = 29; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayData = data
          .where(
            (d) =>
                d.timestamp.isAfter(dayStart) && d.timestamp.isBefore(dayEnd),
          )
          .toList();

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
    final doc = await _db.collection('sessionResults').doc(sessionId).get();
    if (!doc.exists) return 0;
    final data = doc.data()!;
    if (data.containsKey('durationMinutes'))
      return data['durationMinutes'] as int;
    final start = (data['startTimestamp'] as Timestamp).toDate();
    final end = (data['endTimestamp'] as Timestamp).toDate();
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
