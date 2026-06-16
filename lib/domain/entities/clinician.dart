class Clinician {
  final String clinicianId;
  final String userId;
  final String fullName;
  final String contactEmail;
  final String specialty;
  final String institution;

  Clinician({
    required this.clinicianId,
    required this.userId,
    required this.fullName,
    required this.contactEmail,
    required this.specialty,
    required this.institution,
  });

  factory Clinician.fromMap(Map<String, dynamic> map) {
    return Clinician(
      clinicianId: map['clinicianId'] ?? '',
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      specialty: map['specialty'] ?? '',
      institution: map['institution'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clinicianId': clinicianId,
      'userId': userId,
      'fullName': fullName,
      'contactEmail': contactEmail,
      'specialty': specialty,
      'institution': institution,
    };
  }
}