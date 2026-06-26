import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/assigned_member.dart';
import '../../../data/datasources/auth_service_mock.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'chat_screen.dart'; 

class MemberDetailsScreen extends ConsumerStatefulWidget {
  final AssignedMember member;
  final int initialTabIndex;

  const MemberDetailsScreen({
    super.key,
    required this.member,
    this.initialTabIndex = 0, // default Overview
  });

  @override
  ConsumerState<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends ConsumerState<MemberDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _patientData;
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _classifications = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _clinicianLogicalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await _loadPatient(); // must finish first — sessions fall back to email lookup
      await _resolveClinicianLogicalId();
      await Future.wait([
        _loadExercises(),
        _loadReports(),
        _loadClassifications(),
        _loadSessions(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    setState(() => _isLoading = false);
  }
  Future<void> _resolveClinicianLogicalId() async {
    final appUser = ref.read(authStateProvider);
    if (appUser == null) return;
    final query = await FirebaseFirestore.instance
        .collection('clinicians')
        .where('userId', isEqualTo: appUser.userId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      _clinicianLogicalId = query.docs.first.data()['clinicianId'] as String?;
    }
  }

  Future<void> _loadPatient() async {
    final doc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.member.uid)
        .get();
    if (doc.exists) _patientData = doc.data();
  }

  Future<void> _loadExercises() async {
    final planSnapshot = await FirebaseFirestore.instance
        .collection('exercisePlans')
        .where('patientId', isEqualTo: widget.member.uid)
        .get();

    if (planSnapshot.docs.isEmpty) return;

    final planId = planSnapshot.docs.first.id;

    final exercisesSnapshot = await FirebaseFirestore.instance
        .collection('exercises')
        .where('planId', isEqualTo: planId)
        .get();

    _exercises = exercisesSnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }

  Future<void> _loadReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('patientId', isEqualTo: widget.member.uid)
        .get();

    _reports = snapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }

  Future<void> _loadClassifications() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('postureClassifications')
        .where('patientId', isEqualTo: widget.member.uid)
        .get();

    _classifications = snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _loadSessions() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('sessionResults')
        .where('patientId', isEqualTo: widget.member.uid)
        .orderBy('startTimestamp', descending: true)
        .limit(10)
        .get();

    if (snapshot.docs.isEmpty) {
      final email = _patientData?['contactEmail'] as String?;
      if (email != null) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          final authUid = userQuery.docs.first.id;
          snapshot = await FirebaseFirestore.instance
              .collection('sessionResults')
              .where('patientId', isEqualTo: authUid)
              .orderBy('startTimestamp', descending: true)
              .limit(10)
              .get();
        }
      }
    }

    _sessions = snapshot.docs.map((doc) => doc.data()).toList();
  }

  void _openChat() {
      final patientLogicalId = _patientData?['patientId'] as String? ?? widget.member.uid;

      if (_clinicianLogicalId == null) {
        AppToast.show(context, message: 'Unable to open chat right now', isError: true);
        return;
      }

      final chatId = '${_clinicianLogicalId}_$patientLogicalId';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            recipientId: patientLogicalId,
            recipientName: widget.member.name,
          ),
        ),
      );
    }

  // Calculate posture score
  int get _postureScore {
    if (_classifications.isEmpty) return 0;
    final upright = _classifications
        .where((c) => c['postureLabel'] == 'upright')
        .length;
    return ((upright / _classifications.length) * 100).round();
  }

  // Most problematic posture
  String get _mostProblematic {
    if (_classifications.isEmpty) return 'N/A';
    final badOnes = _classifications
        .where((c) => c['postureLabel'] != 'upright')
        .toList();
    if (badOnes.isEmpty) return 'None';
    final counts = <String, int>{};
    for (final c in badOnes) {
      final label = c['postureLabel'] as String;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return top.key.replaceAll('_', ' ');
  }

  // Score → status color, shared across the screen
  Color _scoreColor(int score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return const Color(0xFFB8860B); // muted amber, theme-consistent
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.member.name;
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDeep))
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 360,
                  pinned: true,
                  backgroundColor: AppColors.primaryDeep,
                  elevation: 0,
                  leading: _buildAppBarIconButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context),
                  ),
                  actions: [
                    _buildAppBarIconButton(
                      icon: Icons.chat_bubble_outline,
                      onTap: _openChat,
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.headerGradient,
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                          child: Column(
                            children: [
                              // Avatar + name
                              Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: AppColors.primaryDeep.withValues(alpha: 0.25),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: (_patientData?['profileImageBase64'] != null &&
                                            (_patientData!['profileImageBase64'] as String).isNotEmpty)
                                        ? Image.memory(
                                            base64Decode(_patientData!['profileImageBase64']),
                                            fit: BoxFit.cover,
                                          )
                                        : Center(
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primaryDeep,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _patientData?['contactEmail'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primaryDeep.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildHeaderTag(_patientData?['gender'] ?? ''),
                                            const SizedBox(width: 8),
                                            _buildHeaderTag(_patientData?['dateOfBirth'] ?? ''),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Score cards row
                              Row(
                                children: [
                                  _buildScoreCard(
                                    'Posture Score',
                                    '$_postureScore%',
                                    Icons.favorite_outline,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildScoreCard(
                                    'Readings',
                                    '${_classifications.length}',
                                    Icons.data_usage_outlined,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildScoreCard(
                                    'Reports',
                                    '${_reports.length}',
                                    Icons.description_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(52),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppColors.primaryDeep,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondaryLight,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Exercises'),
                          Tab(text: 'Reports'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildExercisesTab(),
                  _buildReportsTab(),
                ],
              ),
            ),
    );
  }

  // ── Header Helpers ────────────────────────────────────────

  Widget _buildAppBarIconButton({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primaryDeep, size: 18),
        ),
      ),
    );
  }

  Widget _buildHeaderTag(String text) {
    if (text.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryDeep, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimaryLight,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────

  Widget _buildOverviewTab() {
    final score = _postureScore;
    final scoreColor = _scoreColor(score);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Posture score card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Posture Analysis',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withValues(alpha: 0.10),
                        border: Border.all(color: scoreColor, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          '$score%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score >= 70
                                ? 'Good Progress'
                                : score >= 40
                                    ? 'Needs Attention'
                                    : 'Critical — Immediate Action',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Most problematic: ${_mostProblematic.isEmpty ? 'N/A' : _mostProblematic}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on ${_classifications.length} readings',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Patient info card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Patient Information',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight)),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.email_outlined, 'Email',
                    _patientData?['contactEmail'] ?? 'N/A'),
                const Divider(height: 20),
                _buildInfoRow(Icons.person_outline, 'Gender',
                    _patientData?['gender'] ?? 'N/A'),
                const Divider(height: 20),
                _buildInfoRow(Icons.cake_outlined, 'Date of Birth',
                    _patientData?['dateOfBirth'] ?? 'N/A'),
                const Divider(height: 20),
                _buildInfoRow(Icons.language, 'Language',
                    _patientData?['preferredLanguage'] ?? 'N/A'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Session history card
          _buildSessionsSection(),

          const SizedBox(height: 16),

          // Doctor's note card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryDeep.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryDeep.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_alt_outlined,
                        color: AppColors.primaryDeep, size: 20),
                    const SizedBox(width: 8),
                    const Text("Doctor's Note",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDeep)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showEditNoteDialog,
                      child: const Icon(Icons.edit_outlined,
                          color: AppColors.primaryDeep, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _patientData?['doctorNote'] ??
                      'No note added yet. Tap edit to add a note about this patient.',
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared card wrapper ────────────────────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Session History ───────────────────────────────────────

  Widget _buildSessionsSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Session History',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight)),
              const Spacer(),
              Text(
                '${_sessions.length} recent',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_sessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No sessions found',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ),
            )
          else
            ...(_sessions.map((s) => _buildSessionRow(s))),
        ],
      ),
    );
  }

  Widget _buildSessionRow(Map<String, dynamic> session) {
    final score = (session['sessionScore'] as num?)?.toInt() ?? 0;
    final duration = (session['durationMinutes'] as num?)?.toInt() ?? 0;
    final status = session['status'] as String? ?? 'completed';
    final startTs = session['startTimestamp'];
    DateTime? date;
    if (startTs is Timestamp) date = startTs.toDate();

    final scoreColor = _scoreColor(score);

    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}  '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$score%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight),
                ),
                const SizedBox(height: 2),
                Text(
                  '${duration}min  ·  $status',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? AppColors.success.withValues(alpha: 0.10)
                  : const Color(0xFFB8860B).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              status == 'completed' ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 16,
              color: status == 'completed' ? AppColors.success : const Color(0xFFB8860B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Exercises Tab ─────────────────────────────────────────

  Widget _buildExercisesTab() {
    return _exercises.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No exercises assigned yet',
                    style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Exercise'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDeep,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showAddExerciseDialog,
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _exercises.length + 1,
            itemBuilder: (context, index) {
              if (index == _exercises.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDeep,
                      side: const BorderSide(color: AppColors.primaryDeep),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showAddExerciseDialog,
                  ),
                );
              }
              return _buildExerciseCard(_exercises[index]);
            },
          );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final region = exercise['targetSpinalRegion'] ?? '';
    // Theme-consistent slate-blue ramp — distinct shades for quick scanning,
    // not arbitrary/stereotyped colors.
    final regionColors = {
      'C7': AppColors.primaryDeep,
      'T4': AppColors.primaryMid,
      'T12': const Color(0xFFB8860B), // muted amber
      'L5': AppColors.danger,
    };
    final color = regionColors[region] ?? AppColors.primaryDeep;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimaryLight),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildExerciseTag('${exercise['repetitions'] ?? 0} reps', color),
                    const SizedBox(width: 6),
                    _buildExerciseTag('${exercise['durationSeconds'] ?? 0}s', color),
                    const SizedBox(width: 6),
                    _buildExerciseTag(region, color),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryDeep, size: 20),
            onPressed: () => _showEditExerciseDialog(exercise),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            onPressed: () => _confirmDeleteExercise(exercise),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Reports Tab ───────────────────────────────────────────

  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No reports generated yet',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) => _buildReportCard(_reports[index]),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final score = report['postureScore'] ?? 0;
    final type = report['reportType'] ?? 'report';
    final date = report['generatedAt'] ?? '';
    final scoreColor = _scoreColor(score is int ? score : (score as num).toInt());

    String formattedDate = '';
    if (date.isNotEmpty) {
      try {
        final dt = DateTime.parse(date);
        formattedDate = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _openReport(report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.picture_as_pdf, color: scoreColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimaryLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view report',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryDeep.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$score%',
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDeep),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight)),
          ],
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────

  void _showEditNoteDialog() {
    final ctrl = TextEditingController(text: _patientData?['doctorNote'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Doctor's Note"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Write your note about this patient...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('patients')
                  .doc(widget.member.uid)
                  .update({'doctorNote': ctrl.text});
              Navigator.pop(context);
              await _loadPatient();
              setState(() {});
              if (mounted) AppToast.show(context, message: 'Note saved');
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExercise(Map<String, dynamic> exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Exercise'),
        content: Text(
          'Are you sure you want to delete "${exercise['name']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('exercises')
                  .doc(exercise['id'])
                  .delete();
              Navigator.pop(context);
              await _loadExercises();
              setState(() {});
              if (mounted) AppToast.show(context, message: 'Exercise deleted', isError: true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog() {
    final nameCtrl = TextEditingController();
    final repsCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String selectedRegion = 'L5';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Exercise'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(nameCtrl, 'Exercise Name', Icons.fitness_center),
                const SizedBox(height: 12),
                _buildDialogField(repsCtrl, 'Repetitions', Icons.repeat,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildDialogField(durationCtrl, 'Duration (seconds)', Icons.timer,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRegion,
                  decoration: InputDecoration(
                    labelText: 'Target Region',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  items: ['C7', 'T4', 'T12', 'L5']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedRegion = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final appUser = ref.read(authStateProvider);
                String clinicianId = 'c001';
                if (appUser != null) {
                  final clinicianQuery = await FirebaseFirestore.instance
                      .collection('clinicians')
                      .where('userId', isEqualTo: appUser.userId)
                      .limit(1)
                      .get();
                  if (clinicianQuery.docs.isNotEmpty) {
                    clinicianId = clinicianQuery.docs.first.id;
                  }
                }

                final planSnapshot = await FirebaseFirestore.instance
                    .collection('exercisePlans')
                    .where('patientId', isEqualTo: widget.member.uid)
                    .get();

                String planId;
                if (planSnapshot.docs.isEmpty) {
                  final newPlan = await FirebaseFirestore.instance
                      .collection('exercisePlans')
                      .add({
                    'patientId': widget.member.uid,
                    'clinicianId': clinicianId,
                    'createdDate': DateTime.now().toIso8601String(),
                    'status': 'active',
                  });
                  planId = newPlan.id;
                } else {
                  planId = planSnapshot.docs.first.id;
                }

                await FirebaseFirestore.instance.collection('exercises').add({
                  'planId': planId,
                  'name': nameCtrl.text,
                  'repetitions': int.tryParse(repsCtrl.text) ?? 10,
                  'durationSeconds': int.tryParse(durationCtrl.text) ?? 30,
                  'targetSpinalRegion': selectedRegion,
                });

                Navigator.pop(context);
                await _loadExercises();
                setState(() {});
                if (mounted) AppToast.show(context, message: 'Exercise added');
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExerciseDialog(Map<String, dynamic> exercise) {
    final nameCtrl = TextEditingController(text: exercise['name'] ?? '');
    final repsCtrl = TextEditingController(text: '${exercise['repetitions'] ?? 10}');
    final durationCtrl = TextEditingController(text: '${exercise['durationSeconds'] ?? 30}');
    String selectedRegion = exercise['targetSpinalRegion'] ?? 'L5';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Exercise'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(nameCtrl, 'Exercise Name', Icons.fitness_center),
                const SizedBox(height: 12),
                _buildDialogField(repsCtrl, 'Repetitions', Icons.repeat,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildDialogField(durationCtrl, 'Duration (seconds)', Icons.timer,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRegion,
                  decoration: InputDecoration(
                    labelText: 'Target Region',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  items: ['C7', 'T4', 'T12', 'L5']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedRegion = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('exercises')
                    .doc(exercise['id'])
                    .update({
                  'name': nameCtrl.text,
                  'repetitions': int.tryParse(repsCtrl.text) ?? 10,
                  'durationSeconds': int.tryParse(durationCtrl.text) ?? 30,
                  'targetSpinalRegion': selectedRegion,
                });

                Navigator.pop(context);
                await _loadExercises();
                setState(() {});
                if (mounted) AppToast.show(context, message: 'Exercise updated');
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    final base64Str = report['pdfBase64'];

    if (base64Str == null || base64Str.isEmpty) {
      AppToast.show(context, message: 'No PDF available for this report', isError: true);
      return;
    }

    try {
      final bytes = base64Decode(base64Str);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _PdfViewerScreen(
            pdfBytes: bytes,
            title: report['reportType']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'Report',
          ),
        ),
      );
    } catch (e) {
      AppToast.show(context, message: 'Failed to open report: $e', isError: true);
    }
  }

  Widget _buildDialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const _PdfViewerScreen({
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => Printing.sharePdf(bytes: pdfBytes, filename: '$title.pdf'),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: '$title.pdf',
      ),
    );
  }
}