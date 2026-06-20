import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/assigned_member.dart';
import 'package:printing/printing.dart';
import '../../../data/datasources/auth_service_mock.dart';
import 'dart:convert';
import 'dart:typed_data';

class MemberDetailsScreen extends ConsumerStatefulWidget {
  final AssignedMember member;

  const MemberDetailsScreen({super.key, required this.member});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _loadPatient() async {
    final doc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.member.uid)
        .get();
    if (doc.exists) _patientData = doc.data();
  }

  Future<void> _loadExercises() async {
    // Get exercise plan for this patient
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
    // Try direct UID first (works when patients doc ID == auth UID)
    var snapshot = await FirebaseFirestore.instance
        .collection('sessionResults')
        .where('patientId', isEqualTo: widget.member.uid)
        .orderBy('startTimestamp', descending: true)
        .limit(10)
        .get();

    // If nothing found, bridge via email → look up auth UID in users collection
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

  @override
  Widget build(BuildContext context) {
    final name = widget.member.name;
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 360,
                  pinned: true,
                  backgroundColor: const Color(0xFF1565C0),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    // Chat button
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat coming soon!')),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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
                                      color: Colors.white.withOpacity(0.2),
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
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
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _patientData?['contactEmail'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _buildHeaderTag(
                                              _patientData?['gender'] ?? '',
                                            ),
                                            const SizedBox(width: 8),
                                            _buildHeaderTag(
                                              _patientData?['dateOfBirth'] ?? '',
                                            ),
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
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: const Color(0xFF1565C0),
                        unselectedLabelColor: Colors.white,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

  Widget _buildHeaderTag(String text) {
    if (text.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildScoreCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
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
    final scoreColor = score >= 70
        ? const Color(0xFF4CAF50)
        : score >= 40
            ? const Color(0xFFFF9800)
            : const Color(0xFFFF6B6B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Posture score card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Posture Analysis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Score circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withOpacity(0.1),
                        border: Border.all(color: scoreColor, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          '$score%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Most problematic: ${_mostProblematic.isEmpty ? 'N/A' : _mostProblematic}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on ${_classifications.length} readings',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Patient Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_alt_outlined,
                        color: Color(0xFF1565C0), size: 20),
                    const SizedBox(width: 8),
                    const Text('Doctor\'s Note',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0))),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showEditNoteDialog,
                      child: const Icon(Icons.edit_outlined,
                          color: Color(0xFF1565C0), size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _patientData?['doctorNote'] ??
                      'No note added yet. Tap edit to add a note about this patient.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
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

  // ── Session History ───────────────────────────────────────

  Widget _buildSessionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 4),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Session History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${_sessions.length} recent',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

    final scoreColor = score >= 70
        ? const Color(0xFF4CAF50)
        : score >= 40
            ? const Color(0xFFFF9800)
            : const Color(0xFFFF6B6B);

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
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$score%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${duration}min  ·  $status',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              status == 'completed' ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 16,
              color: status == 'completed' ? const Color(0xFF4CAF50) : Colors.orange,
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
                    backgroundColor: const Color(0xFF1565C0),
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
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
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
    final regionColors = {
      'C7': const Color(0xFF5B8FF9),
      'T4': const Color(0xFF61DDAA),
      'T12': const Color(0xFFFFB44C),
      'L5': const Color(0xFFFF6B6B),
    };
    final color = regionColors[region] ?? const Color(0xFF5B8FF9);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        )],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1565C0), size: 20),
            onPressed: () => _showEditExerciseDialog(exercise),
          ),
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
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
        color: color.withOpacity(0.1),
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
    final scoreColor = score >= 70
        ? const Color(0xFF4CAF50)
        : score >= 40
            ? const Color(0xFFFF9800)
            : const Color(0xFFFF6B6B);

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
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view report',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF1565C0).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$score%',
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
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
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
        title: const Text('Doctor\'s Note'),
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
              backgroundColor: const Color(0xFF1565C0),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Note saved!'),
                  backgroundColor: Colors.green,
                ),
              );
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
              backgroundColor: Colors.red,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Exercise deleted'),
                  backgroundColor: Colors.red,
                ),
              );
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
                  onChanged: (val) =>
                      setDialogState(() => selectedRegion = val!),
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
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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

                // Get or create exercise plan
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

                await FirebaseFirestore.instance
                    .collection('exercises')
                    .add({
                  'planId': planId,
                  'name': nameCtrl.text,
                  'repetitions': int.tryParse(repsCtrl.text) ?? 10,
                  'durationSeconds': int.tryParse(durationCtrl.text) ?? 30,
                  'targetSpinalRegion': selectedRegion,
                });

                Navigator.pop(context);
                await _loadExercises();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Exercise added!'),
                    backgroundColor: Colors.green,
                  ),
                );
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
    final repsCtrl = TextEditingController(
        text: '${exercise['repetitions'] ?? 10}');
    final durationCtrl = TextEditingController(
        text: '${exercise['durationSeconds'] ?? 30}');
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
                  onChanged: (val) =>
                      setDialogState(() => selectedRegion = val!),
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
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Exercise updated!'),
                    backgroundColor: Colors.green,
                  ),
                );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF available for this report')),
      );
      return;
    }

    try {
      final bytes = base64Decode(base64Str);
      
      // Navigate to a dedicated PDF viewer screen with back button
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open report: $e')),
      );
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
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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