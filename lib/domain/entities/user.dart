class AppUser {
  final String uid;
  final String email;
  final String role; // 'Member' or 'Advisor'
  final Map<String, dynamic>? profileData;

  AppUser({required this.uid, required this.email, required this.role, this.profileData,});
}
