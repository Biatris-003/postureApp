class AppUser {
  final String uid;
  final String email;
  final String role; // 'Member' or 'Advisor'

  AppUser({required this.uid, required this.email, required this.role});
}
