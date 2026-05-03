import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class FirebaseSeeder {
  static final _db = FirebaseFirestore.instance;
  static final _random = Random();

  static final _labels = [
    'upright',
    'forward_bending',
    'backward_bending',
    'slouching',
    'left_bending',
    'right_bending',
  ];

  static Future<void> seedAll() async {
    print('🌱 Starting seeding...');
    await _seedClinician();        // Entity 1
    await _seedPatient();          // Entity 2
    await _seedDevice();           // Entity 3
    await _seedSession();          // Entity 4
    await _seedPostureReadings();  // Entity 5
    await _seedDlModel();          // Entity 6
    await _seedClassifications();  // Entity 7
    await _seedAlerts();           // Entity 8
    await _seedReport();           // Entity 9
    await _seedExercisePlan();     // Entity 10
    await _seedExercises();        // Entity 11
    print('✅ All 11 entities seeded!');
  }

  // Entity 1 - Clinician
  static Future<void> _seedClinician() async {
    await _db.collection('clinicians').doc('c001').set({
      'clinicianId': 'c001',
      'fullName': 'Dr. Mohamed Hassan',
      'specialty': 'Orthopedics',
      'institution': 'Cairo University Hospital',
      'contactEmail': 'dr.hassan@hospital.com',
    });
    print('✅ Clinician created');
  }

  // Entity 2 - Patient
  static Future<void> _seedPatient() async {
    await _db.collection('patients').doc('p001').set({
      'patientId': 'p001',
      'fullName': 'Sara Ahmed',
      'dateOfBirth': '1995-03-12',
      'gender': 'Female',
      'contactEmail': 'sara@email.com',
      'preferredLanguage': 'Arabic',
      'deviceId': 'd001',
      'clinicianId': 'c001',
    });
    print('✅ Patient created');
  }

  // Entity 3 - Device
  static Future<void> _seedDevice() async {
    await _db.collection('devices').doc('d001').set({
      'deviceId': 'd001',
      'patientId': 'p001',
      'serialNumber': 'SN-2025-001',
      'firmwareVersion': '1.2.3',
      'numSensors': 4,
      'sensorPlacements': ['C7', 'T4', 'T12', 'L5'],
    });
    print('✅ Device created');
  }

  // Entity 4 - Session
  static Future<void> _seedSession() async {
    await _db.collection('sessions').doc('s001').set({
      'sessionId': 's001',
      'patientId': 'p001',
      'deviceId': 'd001',
      'startTimestamp':
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'endTimestamp': DateTime.now().toIso8601String(),
      'activityContext': 'sitting',
    });
    print('✅ Session created');
  }

  // Entity 5 - Posture Readings (RAW sensor data only, no labels here)
  static Future<void> _seedPostureReadings() async {
    print('🌱 Seeding posture readings...');
    for (int i = 0; i < 50; i++) {
      final timestamp = DateTime.now()
          .subtract(Duration(minutes: (50 - i) * 2))
          .toIso8601String();

      await _db.collection('postureReadings').doc('r${i.toString().padLeft(3, '0')}').set({
        'readingId': 'r${i.toString().padLeft(3, '0')}',
        'sessionId': 's001',        // FK → Session
        'sensorPlacement': 'C7, T4, T12, L5',
        'timestamp': timestamp,
        // C7 - Cervical
        'C7_pitch': _randomAngle(),
        'C7_roll': _randomAngle(),
        'C7_yaw': _randomAngle(),
        'C7_accelX': _randomAccel(),
        'C7_accelY': _randomAccel(),
        'C7_accelZ': _randomAccel(),
        'C7_gyroX': _randomGyro(),
        'C7_gyroY': _randomGyro(),
        'C7_gyroZ': _randomGyro(),
        // T4 - Upper Thoracic
        'T4_pitch': _randomAngle(),
        'T4_roll': _randomAngle(),
        'T4_yaw': _randomAngle(),
        'T4_accelX': _randomAccel(),
        'T4_accelY': _randomAccel(),
        'T4_accelZ': _randomAccel(),
        'T4_gyroX': _randomGyro(),
        'T4_gyroY': _randomGyro(),
        'T4_gyroZ': _randomGyro(),
        // T12 - Lower Thoracic
        'T12_pitch': _randomAngle(),
        'T12_roll': _randomAngle(),
        'T12_yaw': _randomAngle(),
        'T12_accelX': _randomAccel(),
        'T12_accelY': _randomAccel(),
        'T12_accelZ': _randomAccel(),
        'T12_gyroX': _randomGyro(),
        'T12_gyroY': _randomGyro(),
        'T12_gyroZ': _randomGyro(),
        // L5 - Lumbar
        'L5_pitch': _randomAngle(),
        'L5_roll': _randomAngle(),
        'L5_yaw': _randomAngle(),
        'L5_accelX': _randomAccel(),
        'L5_accelY': _randomAccel(),
        'L5_accelZ': _randomAccel(),
        'L5_gyroX': _randomGyro(),
        'L5_gyroY': _randomGyro(),
        'L5_gyroZ': _randomGyro(),
      });
    }
    print('✅ 50 posture readings created');
  }

  // Entity 6 - DL Model
  static Future<void> _seedDlModel() async {
    await _db.collection('dlModels').doc('m001').set({
      'modelId': 'm001',
      'version': '1.0.0',
      'trainingDate': '2025-01-15',
      'validationAccuracy': 0.94,
      'populationDesc': 'Egyptian population posture data',
      'modelType': 'CNN-LSTM',
    });
    print('✅ DL Model created');
  }

  // Entity 7 - Posture Classifications (DL output only, linked to readings)
  static Future<void> _seedClassifications() async {
    print('🌱 Seeding posture classifications...');
    for (int i = 0; i < 50; i++) {
      final label = _labels[_random.nextInt(_labels.length)];
      final timestamp = DateTime.now()
          .subtract(Duration(minutes: (50 - i) * 2))
          .toIso8601String();

      await _db.collection('postureClassifications').doc('cl${i.toString().padLeft(3, '0')}').set({
        'classificationId': 'cl${i.toString().padLeft(3, '0')}',
        'readingId': 'r${i.toString().padLeft(3, '0')}', // FK → PostureReading (1:1)
        'modelId': 'm001',                               // FK → DL Model
        'postureLabel': label,
        'confidenceScore': 0.80 + _random.nextDouble() * 0.19,
        'timestamp': timestamp,
        // These are added for easy querying in statistics
        'patientId': 'p001',
        'sessionId': 's001',
      });
    }
    print('✅ 50 posture classifications created');
  }

  // Entity 8 - Alerts
  static Future<void> _seedAlerts() async {
    final severities = ['low', 'moderate', 'high'];
    final types = ['haptic', 'push_notification'];

    for (int i = 0; i < 5; i++) {
      await _db.collection('alerts').add({
        'sessionId': 's001',   // FK → Session
        'patientId': 'p001',   // FK → Patient
        'alertType': types[_random.nextInt(types.length)],
        'severity': severities[_random.nextInt(severities.length)],
        'triggerTimestamp': DateTime.now()
            .subtract(Duration(minutes: i * 20))
            .toIso8601String(),
      });
    }
    print('✅ Alerts created');
  }

  // Entity 9 - Report
  static Future<void> _seedReport() async {
    await _db.collection('reports').doc('rep001').set({
      'reportId': 'rep001',
      'patientId': 'p001',    // FK → Patient
      'sessionId': 's001',    // FK → Session
      'generatedAt': DateTime.now().toIso8601String(),
      'reportType': 'session_summary',
      'exportFormat': 'PDF',
      'postureScore': 72,
      'uprightPercent': 35,
      'forwardBendingPercent': 20,
      'backwardBendingPercent': 10,
      'slouchingPercent': 20,
      'leftBendingPercent': 8,
      'rightBendingPercent': 7,
    });
    print('✅ Report created');
  }

  // Entity 10 - Exercise Plan
  static Future<void> _seedExercisePlan() async {
    await _db.collection('exercisePlans').doc('ep001').set({
      'planId': 'ep001',
      'patientId': 'p001',    // FK → Patient
      'clinicianId': 'c001',  // FK → Clinician
      'createdDate': '2025-04-25',
      'status': 'active',
    });
    print('✅ Exercise plan created');
  }

  // Entity 11 - Exercises
  static Future<void> _seedExercises() async {
    final exercises = [
      {
        'planId': 'ep001',           // FK → ExercisePlan
        'name': 'Cat-Cow Stretch',
        'targetSpinalRegion': 'L5',
        'durationSeconds': 30,
        'repetitions': 10,
      },
      {
        'planId': 'ep001',
        'name': 'Chin Tuck',
        'targetSpinalRegion': 'C7',
        'durationSeconds': 20,
        'repetitions': 15,
      },
      {
        'planId': 'ep001',
        'name': 'Thoracic Extension',
        'targetSpinalRegion': 'T4',
        'durationSeconds': 45,
        'repetitions': 8,
      },
      {
        'planId': 'ep001',
        'name': 'Lateral Stretch',
        'targetSpinalRegion': 'T12',
        'durationSeconds': 30,
        'repetitions': 10,
      },
    ];

    for (final exercise in exercises) {
      await _db.collection('exercises').add(exercise);
    }
    print('✅ Exercises created');
  }

// Add this to your FirebaseSeeder class

  static Future<void> seedMultipleSessions() async {
    print('🌱 Seeding multiple sessions for better analytics...');
    
    // Seed 7 days of data, 2 sessions per day
    for (int day = 6; day >= 0; day--) {
      for (int sessionNum = 0; sessionNum < 2; sessionNum++) {
        final sessionId = 'session_d${day}_s$sessionNum';
        final sessionStart = DateTime.now()
            .subtract(Duration(days: day, hours: sessionNum == 0 ? 8 : 14));
        final sessionEnd = sessionStart.add(const Duration(hours: 2));

        // Create session
        await _db.collection('sessions').doc(sessionId).set({
          'sessionId': sessionId,
          'patientId': 'p001',
          'deviceId': 'd001',
          'startTimestamp': sessionStart.toIso8601String(),
          'endTimestamp': sessionEnd.toIso8601String(),
          'activityContext': sessionNum == 0 ? 'morning_work' : 'afternoon_work',
        });

        // Create 30 readings + classifications per session
        for (int i = 0; i < 30; i++) {
          final timestamp = sessionStart
              .add(Duration(minutes: i * 4))
              .toIso8601String();
          final readingId = 'r_${sessionId}_$i';

          // Reading (raw sensor data)
          await _db.collection('postureReadings').doc(readingId).set({
            'readingId': readingId,
            'sessionId': sessionId,
            'sensorPlacement': 'C7, T4, T12, L5',
            'timestamp': timestamp,
            'C7_pitch': _randomAngle(),
            'C7_roll': _randomAngle(),
            'C7_yaw': _randomAngle(),
            'T4_pitch': _randomAngle(),
            'T4_roll': _randomAngle(),
            'T4_yaw': _randomAngle(),
            'T12_pitch': _randomAngle(),
            'T12_roll': _randomAngle(),
            'T12_yaw': _randomAngle(),
            'L5_pitch': _randomAngle(),
            'L5_roll': _randomAngle(),
            'L5_yaw': _randomAngle(),
          });

          // Classification (DL model output)
          // Make upright more likely to show realistic data
          final rand = _random.nextDouble();
          String label;
          if (rand < 0.40) {
            label = 'upright';
          } else if (rand < 0.60) {
            label = 'forward_bending';
          } else if (rand < 0.75) {
            label = 'slouching';
          } else if (rand < 0.85) {
            label = 'backward_bending';
          } else if (rand < 0.92) {
            label = 'left_bending';
          } else {
            label = 'right_bending';
          }

          await _db.collection('postureClassifications').doc('cl_${sessionId}_$i').set({
            'classificationId': 'cl_${sessionId}_$i',
            'readingId': readingId,
            'modelId': 'm001',
            'postureLabel': label,
            'confidenceScore': 0.80 + _random.nextDouble() * 0.19,
            'timestamp': timestamp,
            'patientId': 'p001',
            'sessionId': sessionId,
          });
        }
        print('✅ Session $sessionId seeded');
      }
    }
    print('✅ 7 days of data seeded (14 sessions, 420 readings)');
  }

  static double _randomAngle() => (_random.nextDouble() * 30) - 15;
  static double _randomAccel() => (_random.nextDouble() * 2) - 1;
  static double _randomGyro() => (_random.nextDouble() * 4) - 2;
}