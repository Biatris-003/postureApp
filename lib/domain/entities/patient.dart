class Patient {
  final String patientId;
  final String userId;
  final String fullName;
  final String contactEmail;
  final String dateOfBirth;
  final String gender;
  final String preferredLanguage;
  final String? clinicianId;
  final String? deviceId;

  Patient({
    required this.patientId,
    required this.userId,
    required this.fullName,
    required this.contactEmail,
    required this.dateOfBirth,
    required this.gender,
    required this.preferredLanguage,
    this.clinicianId,
    this.deviceId,
  });

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patientId'] ?? '',
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      gender: map['gender'] ?? '',
      preferredLanguage: map['preferredLanguage'] ?? '',
      clinicianId: map['clinicianId'],
      deviceId: map['deviceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'userId': userId,
      'fullName': fullName,
      'contactEmail': contactEmail,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'preferredLanguage': preferredLanguage,
      'clinicianId': clinicianId,
      'deviceId': deviceId,
    };
  }
}