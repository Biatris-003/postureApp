import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_details_screen.dart';
import '../../../domain/entities/assigned_member.dart';
import '../../../data/datasources/advisor_data_service_mock.dart';

class AssignedMembersTab extends ConsumerStatefulWidget {
  const AssignedMembersTab({Key? key}) : super(key: key);

  @override
  ConsumerState<AssignedMembersTab> createState() => _AssignedMembersTabState();
}

class _AssignedMembersTabState extends ConsumerState<AssignedMembersTab> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      // Load all patients assigned to this clinician
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('clinicianId', isEqualTo: 'c001')
          .get();

      setState(() {
        _patients = snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    if (_searchQuery.isEmpty) return _patients;
    return _patients.where((p) =>
      (p['fullName'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (p['contactEmail'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: RefreshIndicator(
        onRefresh: _loadPatients,
        child: CustomScrollView(
          slivers: [

            // ── Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Patients',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Monitor and manage patient progress',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            // Patient count badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_patients.length} Active',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search patients...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Patient List ─────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredPatients.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No patients assigned yet'
                            : 'No patients found',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPatientCard(_filteredPatients[index]),
                    childCount: _filteredPatients.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['fullName'] ?? 'Unknown';
    final email = patient['contactEmail'] ?? '';
    final gender = patient['gender'] ?? '';
    final dob = patient['dateOfBirth'] ?? '';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    // Calculate age from dateOfBirth
    String age = '';
    if (dob.isNotEmpty) {
      try {
        final birthDate = DateTime.parse(dob);
        final years = DateTime.now().difference(birthDate).inDays ~/ 365;
        age = '$years yrs';
      } catch (_) {}
    }

    // Avatar color based on name
    final colors = [
      const Color(0xFF5B8FF9),
      const Color(0xFF61DDAA),
      const Color(0xFFFFB44C),
      const Color(0xFFFF6B6B),
      const Color(0xFFB37FEB),
      const Color(0xFF54C0C0),
    ];
    final avatarColor = colors[name.length % colors.length];

    return GestureDetector(
      onTap: () {
        // Convert to AssignedMember for compatibility with existing details screen
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
        ).then((_) => _loadPatients());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [

              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: avatarColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (gender.isNotEmpty)
                          _buildTag(
                            gender == 'Female'
                                ? Icons.female
                                : Icons.male,
                            gender,
                            avatarColor,
                          ),
                        if (age.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildTag(Icons.cake_outlined, age, const Color(0xFF5B8FF9)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}