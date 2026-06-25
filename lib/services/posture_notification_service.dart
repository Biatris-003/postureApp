import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PostureNotificationContent {
  const PostureNotificationContent({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class PostureNotificationService {
  PostureNotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const MethodChannel _localNotificationsChannel =
      MethodChannel('smart_posture_app/local_notifications');
  static int _nextLocalNotificationId = 1000;

  final FirebaseFirestore _db;

  Future<void> savePatientAlert({
    required String patientId,
    required String title,
    required String message,
    required String alertType,
    required DateTime timestamp,
    String? postureLabel,
    String? sessionTrackingId,
    int? sequenceNumber,
    bool vibrate = true,
  }) async {
    await _showLocalNotification(
      title: title,
      message: message,
      alertType: alertType,
      vibrate: vibrate,
    );

    await _db.collection('alerts').add({
      'patientId': patientId,
      'sessionId': sessionTrackingId,
      'sessionTrackingId': sessionTrackingId,
      'alertType': alertType,
      'severity': _severityFor(alertType, sequenceNumber),
      'triggerTimestamp': timestamp.toIso8601String(),
      'title': title,
      'message': message,
      'postureLabel': postureLabel,
      'sequenceNumber': sequenceNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String message,
    required String alertType,
    required bool vibrate,
  }) async {
    try {
      await _localNotificationsChannel.invokeMethod<void>(
        'showNotification',
        {
          'id': _nextLocalNotificationId++,
          'title': title,
          'message': message,
          'alertType': alertType,
          'vibrate': vibrate,
        },
      );
    } on MissingPluginException {
      debugPrint(
        '[PostureNotificationService] local notifications are not available on this platform.',
      );
    } catch (e) {
      debugPrint('[PostureNotificationService] failed to show notification: $e');
    }
  }

  Future<void> attachAlertsToSession({
    required String sessionTrackingId,
    required String sessionId,
  }) async {
    final snapshot = await _db
        .collection('alerts')
        .where('sessionTrackingId', isEqualTo: sessionTrackingId)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'sessionId': sessionId});
    }
    await batch.commit();
  }

  String _severityFor(String alertType, int? sequenceNumber) {
    if (alertType == 'frequent_posture_corrections') return 'high';
    if (alertType == 'movement_break') return 'moderate';
    if ((sequenceNumber ?? 0) >= 3) return 'high';
    if ((sequenceNumber ?? 0) == 2) return 'moderate';
    return 'low';
  }
}
