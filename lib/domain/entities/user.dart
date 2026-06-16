class AppUser {
  final String uid;           // Firebase UID
  final String userId;        // Clean user ID (patient001, advisor001, etc.)
  final String email;
  final String role;          // 'Member' or 'Advisor'

  AppUser({
    required this.uid,
    required this.userId,
    required this.email,
    required this.role
  });

  @override
  String toString() => 'AppUser(uid: $uid, userId: $userId, email: $email, role: $role)';
}