import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'patient_notifications_screen.dart';
import 'find_doctor_screen.dart';
import '../../advisor_dashboard/screens/chat_screen.dart';

class HomeTab extends ConsumerStatefulWidget {
  final VoidCallback? onGoToExercises;
  final VoidCallback? onGoToSpine;

  const HomeTab({
    super.key,
    this.onGoToExercises,
    this.onGoToSpine,
  });

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  // Patient data
  Map<String, dynamic>? _patientData;
  String? _patientDocId;
  String? _patientLogicalId;
  String? _patientImageBase64;

  // Doctor data
  Map<String, dynamic>? _doctorData;
  String? _doctorDocId;
  String? _doctorImageBase64;

  // Stats
  int _postureScore = 0;
  int _exerciseCount = 0;
  int _sessionsThisWeek = 0;
  int _bestScoreThisWeek = 0;
  int _streakDays = 0;
  int _unreadNotifications = 0;

  bool _isLoading = true;

  // Navigation state
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await _loadPatient();
      await Future.wait([
        _loadDoctor(),
        _loadPostureScore(),
        _loadExerciseCount(),
        _loadSessionStats(),
        _loadUnreadCount(),
      ]);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadPatient() async {
    final appUser = ref.read(authStateProvider);
    if (appUser == null) return;

    final q = await FirebaseFirestore.instance
        .collection('patients')
        .where('userId', isEqualTo: appUser.userId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return;

    _patientDocId = q.docs.first.id;
    _patientData = Map<String, dynamic>.from(q.docs.first.data());
    _patientLogicalId = _patientData?['patientId'] as String?;
    _patientImageBase64 = _patientData?['profileImageBase64'] as String?;
  }

  Future<void> _loadDoctor() async {
    final clinicianDocId = _patientData?['clinicianId'] as String?;
    if (clinicianDocId == null || clinicianDocId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('clinicians')
          .doc(clinicianDocId)
          .get();
      if (doc.exists) {
        _doctorDocId = doc.id;
        _doctorData = Map<String, dynamic>.from(doc.data()!);
        _doctorImageBase64 = _doctorData?['profileImageBase64'] as String?;
      }
    } catch (_) {}
  }

  Future<void> _loadPostureScore() async {
    if (_patientLogicalId == null) {
      debugPrint('❌ patientLogicalId is null');
      return;
    }

    debugPrint('✅ Loading score for $_patientLogicalId');

    try {
      final snap = await FirebaseFirestore.instance
          .collection('statistics')
          .where('patientId', isEqualTo: _patientLogicalId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      debugPrint('📊 Docs found: ${snap.docs.length}');

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();

        debugPrint('📊 Statistics data: $data');
        debugPrint('📊 postureScore field: ${data['postureScore']}');

        _postureScore =
            ((data['postureScore'] as num?)?.toDouble() ?? 0)
                .round()
                .clamp(0, 100);

        debugPrint('📊 Final score = $_postureScore');

        if (mounted) setState(() {});
      }
    } catch (e, st) {
      debugPrint('❌ Error loading posture score: $e');
      debugPrint('$st');
    }
  }

  Future<void> _loadExerciseCount() async {
    if (_patientDocId == null) return;
    try {
      final planSnap = await FirebaseFirestore.instance
          .collection('exercisePlans')
          .where('patientId', isEqualTo: _patientDocId)
          .limit(1)
          .get();
      if (planSnap.docs.isEmpty) return;
      final planId = planSnap.docs.first.id;
      final exSnap = await FirebaseFirestore.instance
          .collection('exercises')
          .where('planId', isEqualTo: planId)
          .get();
      _exerciseCount = exSnap.docs.length;
    } catch (_) {}
  }

  Future<void> _loadSessionStats() async {
    if (_patientDocId == null) return;
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartClean =
          DateTime(weekStart.year, weekStart.month, weekStart.day);

      final snap = await FirebaseFirestore.instance
          .collection('sessionResults')
          .where('patientId', isEqualTo: _patientDocId)
          .orderBy('startTimestamp', descending: true)
          .limit(50)
          .get();

      int sessions = 0;
      int best = 0;
      final Set<String> daysWithSessions = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['startTimestamp'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();

        if (dt != null && dt.isAfter(weekStartClean)) {
          sessions++;
          final score = (data['sessionScore'] as num?)?.toInt() ?? 0;
          if (score > best) best = score;
        }
        if (dt != null) {
          daysWithSessions.add('${dt.year}-${dt.month}-${dt.day}');
        }
      }

      // Streak: count consecutive days backwards from today
      int streak = 0;
      var day = DateTime(now.year, now.month, now.day);
      while (daysWithSessions
          .contains('${day.year}-${day.month}-${day.day}')) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      }

      _sessionsThisWeek = sessions;
      _bestScoreThisWeek = best;
      _streakDays = streak;
    } catch (_) {}
  }

  // ✅ FIXED: Use recipientId + recipientType for patient with setState
  Future<void> _loadUnreadCount() async {
    if (_patientLogicalId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: _patientLogicalId)
          .where('recipientType', isEqualTo: 'patient')
          .where('isRead', isEqualTo: false)
          .get();
      
      if (mounted) {
        setState(() {
          _unreadNotifications = snap.docs.length;
        });
      }
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ';
    if (h < 17) return 'Good afternoon ';
    return 'Good evening ';
  }

  Color _scoreColor(int score) {
    if (score >= 70) return const Color(0xFF3D7A63); // AppColors.success
    if (score >= 40) return const Color(0xFFE08A00);
    return AppColors.danger;
  }

  String _scoreLabel(int score) {
    if (score >= 70) return 'Good Progress';
    if (score >= 40) return 'Needs Attention';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    final name = _patientData?['fullName'] as String? ?? '';
    final firstName = name.split(' ').firstWhere(
      (String w) => w.isNotEmpty,
      orElse: () => name,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: AppColors.primaryDeep,
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Greeting ─────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello,',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoading ? '...' : '$firstName!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),

                      // ── Right Capsule ───────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            // Notification
                            GestureDetector(
                              onTap: () async {
                                // ✅ FIX: Refresh unread count when returning
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientNotificationsScreen(
                                      patientLogicalId: _patientLogicalId ?? '',
                                      onGoToExercises: widget.onGoToExercises,
                                    ),
                                  ),
                                );
                                
                                // ✅ Reload unread count after returning
                                await _loadUnreadCount();
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none,
                                      color: AppColors.primaryDeep,
                                      size: 22,
                                    ),
                                  ),

                                  // red dot
                                  if (_unreadNotifications > 0)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.danger,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // Avatar
                            Container(
                              width: 38,
                              height: 38,
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: _patientImageBase64 != null
                                  ? Image.memory(
                                      base64Decode(_patientImageBase64!),
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppColors.primaryDeep.withValues(alpha: 0.1),
                                      child: Center(
                                        child: Text(
                                          firstName.isNotEmpty ? firstName[0] : 'P',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDeep,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDeep,
                    ),
                  ),
                )
              else ...[
                // ── Posture Score Card ───────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
                    child: _buildScoreCard(),
                  ),
                ),
                // ── Quick Stats ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 5),
                    child: _buildQuickStats(),
                  ),
                ),
                // ── Exercises Card ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 5),
                    child: _buildExercisesCard(),
                  ),
                ),
                // ── My Doctor Card ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                    child: _buildDoctorCard(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        _handleNavigation(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryDeep.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 23,
              color: isSelected ? AppColors.primaryDeep : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primaryDeep : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        break;
      case 2:
        break;
      case 3:
        break;
      case 4:
        break;
    }
  }

  // ── Posture Score Card ────────────────────────────────────

  Widget _buildScoreCard() {
    final color = _scoreColor(_postureScore);
    final label = _scoreLabel(_postureScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Posture Score",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onGoToSpine,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDeep.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.accessibility_new,
                          size: 14, color: AppColors.primaryDeep),
                      SizedBox(width: 5),
                      Text(
                        'View Spine',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: _postureScore / 100,
                        strokeWidth: 8,
                        backgroundColor:
                            color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$_postureScore%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _postureScore == 0
                          ? 'No data recorded today yet.'
                          : 'Keep it up! Your posture is being monitored.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Doctor Card ───────────────────────────────────────────

  Widget _buildDoctorCard() {
    if (_doctorData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecor(),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryDeep.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_outlined,
                  color: AppColors.primaryDeep, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No doctor assigned yet",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Find a doctor to get personalized care.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindDoctorScreen(
                    patientDocId: _patientDocId ?? '',
                    patientLogicalId: _patientLogicalId ?? '',
                    patientName:
                        _patientData?['fullName'] as String? ?? '',
                  ),
                ),
              ).then((_) => _loadAll()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryMid,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Find Doctor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final doctorName =
        _doctorData!['fullName'] as String? ?? 'Your Doctor';
    final specialty =
        _doctorData!['specialty'] as String? ?? '';
    final institution =
        _doctorData!['institution'] as String? ?? '';
    final clinicianLogicalId =
        _doctorData!['clinicianId'] as String? ?? _doctorDocId ?? '';
    final initials = doctorName
        .split(' ')
        .where((String e) => e.isNotEmpty)
        .take(2)
        .map((String e) => e[0])
        .join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY DOCTOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryLight,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDeep.withValues(alpha: 0.10),
                ),
                child: _doctorImageBase64 != null
                    ? Image.memory(
                        base64Decode(_doctorImageBase64!),
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    if (specialty.isNotEmpty)
                      Text(
                        specialty,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    if (institution.isNotEmpty)
                      Text(
                        institution,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId:
                          '${clinicianLogicalId}_${_patientLogicalId ?? ''}',
                      recipientId: clinicianLogicalId,
                      recipientName: doctorName,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.chat_bubble_outline,
                          color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Exercises Card ────────────────────────────────────────

  Widget _buildExercisesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecor(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryMid.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.self_improvement_outlined,
              color: AppColors.primaryMid,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Exercises",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _exerciseCount == 0
                      ? 'No exercises assigned yet'
                      : '$_exerciseCount exercise${_exerciseCount == 1 ? '' : 's'} assigned',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onGoToExercises,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryMid,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Go',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Stats ───────────────────────────────────────────

  Widget _buildQuickStats() {
    return Row(
      children: [
        _statBox(
          'STREAK',
          '$_streakDays',
          'Days',
        ),
        const SizedBox(width: 10),
        _statBox(
          'BEST SCORE',
          '$_bestScoreThisWeek%',
          'This Week',
        ),
        const SizedBox(width: 10),
        _statBox(
          'SESSIONS',
          '$_sessionsThisWeek',
          'This Week',
        ),
      ],
    );
  }

  Widget _statBox(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecor(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
}