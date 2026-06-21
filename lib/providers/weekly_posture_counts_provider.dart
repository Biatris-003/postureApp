import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/analytics_service.dart';
import '../data/datasources/auth_service_mock.dart';

/// The posture distribution for the last seven days, read from Firestore.
/// Exercise recommendations use this instead of a screen-local cache.
final weeklyPostureCountsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final user = ref.watch(authStateProvider);
  final analytics = AnalyticsService();
  if (user == null) return const <String, int>{};
  final patientId = await analytics.resolvePatientId(
    firebaseUid: user.userId,
    legacyUserId: user.uid,
  );
  if (patientId == null || patientId.isEmpty) return const <String, int>{};
  final classifications = await analytics.getClassificationsByDays(
    patientId,
    7,
  );
  return analytics.calculatePostureCounts(classifications);
});
