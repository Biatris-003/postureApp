import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_details_screen.dart';
import '../../../domain/entities/assigned_member.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';

class AssignedMembersTab extends ConsumerStatefulWidget {
  /// Optional callback to switch to the notifications tab from parent scaffold
  final VoidCallback? onNotificationsTap;

  const AssignedMembersTab({super.key, this.onNotificationsTap});

  @override
  ConsumerState<AssignedMembersTab> createState() => _AssignedMembersTabState();
}

class _AssignedMembersTabState extends ConsumerState<AssignedMembersTab> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'assigned'; // 'assigned' | 'pending'

  // Doctor info for greeting
  String _doctorName = '';
  int _unreadCount = 0;
  String? _clinicianId; // Firestore doc ID (for patient query)
  String? _clinicianLogicalId; // e.g. "c001" (for notifications query)
  String? _doctorImageBase64;


  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final appUser = ref.read(authStateProvider);
      if (appUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final clinicianQuery = await FirebaseFirestore.instance
          .collection('clinicians')
          .where('userId', isEqualTo: appUser.userId)
          .limit(1)
          .get();

      if (clinicianQuery.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final clinicianDoc = clinicianQuery.docs.first;
      _clinicianId = clinicianDoc.id;
      _clinicianLogicalId =
          clinicianDoc.data()['clinicianId'] as String? ?? clinicianDoc.id;
      _doctorName = clinicianDoc.data()['fullName'] ?? 'Doctor';
      _doctorImageBase64 = clinicianDoc.data()['profileImageBase64'] as String?;

      await Future.wait([
        _loadPatients(),
        _loadUnreadCount(),
      ]);
    } catch (e) {
      setState(() => _isLoading = false);
    }
        
  }

  Future<void> _loadPatients() async {
    if (_clinicianId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('clinicianId', isEqualTo: _clinicianId)
          .get();

      setState(() {
      _patients = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    if (_clinicianLogicalId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('clinicianId', isEqualTo: _clinicianLogicalId)
          .where('isRead', isEqualTo: false)
          .get();
      setState(() => _unreadCount = snapshot.docs.length);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredPatients {
    var list = _activeFilter == 'assigned' ? _patients : <Map<String, dynamic>>[];
    if (_searchQuery.isNotEmpty) {
    list = list.where((Map<String, dynamic> p) =>
      (p['fullName'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (p['contactEmail'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    }
    return list;
  }

  String _ageFromDob(String dob) {
    if (dob.isEmpty) return '';
    try {
      final birth = DateTime.parse(dob);
      final years = DateTime.now().difference(birth).inDays ~/ 365;
      return '$years yrs';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    // First name only for greeting
    final parts = _doctorName.split(' ');
    final firstName = parts.length > 1
      ? parts[1]
      : parts.firstOrNull ?? _doctorName;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: AppColors.primaryDeep,
          child: CustomScrollView(
            slivers: [

              // ── Top greeting header ──────────────────────
    SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight, // clean background (NO gradient)
          border: Border(
            bottom: BorderSide(
              color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),
    child: Row(
      children: [

        // Avatar (slightly bigger looks more modern)
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryDeep.withValues(alpha: 0.12),
          ),
          clipBehavior: Clip.antiAlias,
          child: _doctorImageBase64 != null
              ? Image.memory(
                  base64Decode(_doctorImageBase64!),
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
        ),

        const SizedBox(width: 12),

        // Text block (better hierarchy)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome back!",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Dr. $firstName",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),

              // ── Search bar ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search patients...',
                        hintStyle: TextStyle(
                            color: AppColors.textSecondaryLight, fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.textSecondaryLight, size: 20),
                        border:  OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color.fromARGB(255, 255, 255, 255),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Filter tabs ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _filterChip('Your Patients', 'assigned'),
                      const SizedBox(width: 10),
                      _filterChip('Pending Requests', 'pending'),
                    ],
                  ),
                ),
              ),

              // ── Section title + count ────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        _activeFilter == 'assigned'
                            ? 'Assigned Patients'
                            : 'Pending Requests',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDeep.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredPatients.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Patient list ─────────────────────────────
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primaryDeep)),
                )
              else if (_filteredPatients.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _activeFilter == 'pending'
                              ? Icons.inbox_outlined
                              : Icons.people_outline,
                          size: 56,
                          color: AppColors.primaryDeep.withValues(alpha: 0.20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activeFilter == 'pending'
                              ? 'No pending requests'
                              : _searchQuery.isEmpty
                                  ? 'No patients assigned yet'
                                  : 'No patients found',
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ...List.generate(_filteredPatients.length, (index) {
                          final patient = _filteredPatients[index];
                          final isLast = index == _filteredPatients.length - 1;
                          return Column(
                            children: [
                              _buildPatientRow(patient),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  thickness: 0.8,
                                  indent: 76,
                                  endIndent: 20,
                                  color: AppColors.borderLight,
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter chip ──────────────────────────────────────────

  Widget _filterChip(String label, String value) {
    final selected = _activeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMid : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  // ── Patient row ──────────────────────────────────────────

  Widget _buildPatientRow(Map<String, dynamic> patient) {
    final name = patient['fullName'] ?? 'Unknown';
    final email = patient['contactEmail'] ?? '';
    final dob = patient['dateOfBirth'] ?? '';
    final gender = patient['gender'] ?? '';
    final age = _ageFromDob(dob);
    final parts = name.split(' ').where((String e) => e.isNotEmpty).take(2).toList();
    final initials = parts.map((String e) => e[0]).join();

    // Consistent avatar color per patient
    final avatarColors = [
      AppColors.primaryDeep,
      AppColors.primaryMid,
      const Color(0xFF4CAF50),
      const Color(0xFFFF7043),
      const Color(0xFF7E57C2),
      const Color(0xFF00ACC1),
    ];
    final avatarColor = avatarColors[name.length % avatarColors.length];

    return InkWell(
      onTap: () {
        final member = AssignedMember(
          uid: patient['id'] ?? patient['patientId'] ?? '',
          name: name,
          email: email,
          status: 'Active',
          complianceRate: 0.75,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailsScreen(member: member),
          ),
        ).then((_) => _loadAll());
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [

            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: avatarColor,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (email.isNotEmpty)
                        Flexible(
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (age.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textSecondaryLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          age,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (gender.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        gender,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryDeep.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.primaryDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}