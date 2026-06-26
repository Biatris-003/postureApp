import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_details_screen.dart';
import '../../../domain/entities/assigned_member.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';

class AssignedMembersTab extends ConsumerStatefulWidget {
  final VoidCallback? onNotificationsTap;

  const AssignedMembersTab({super.key, this.onNotificationsTap});

  @override
  ConsumerState<AssignedMembersTab> createState() => AssignedMembersTabState();
}

class AssignedMembersTabState extends ConsumerState<AssignedMembersTab> {
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'assigned'; // 'assigned' | 'pending'

  String _doctorName = '';
  int _unreadCount = 0;
  String? _clinicianId;
  String? _clinicianLogicalId;
  String? _doctorImageBase64;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void showPendingRequests() {
    setState(() {
      _activeFilter = 'pending';
    });
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
      _clinicianLogicalId = clinicianDoc.data()['clinicianId'] as String? ?? clinicianDoc.id;
      _doctorName = clinicianDoc.data()['fullName'] ?? 'Doctor';
      _doctorImageBase64 = clinicianDoc.data()['profileImageBase64'] as String?;

      print('🔍 Doctor logical id = $_clinicianLogicalId');

      await Future.wait([
        _loadPatients(),
        _loadPendingRequests(),
        _loadUnreadCount(),
      ]);
    } catch (e) {
      print('❌ Error in _loadAll: $e');
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

  // ✅ UPDATED: Load pending requests with patient profile data
  Future<void> _loadPendingRequests() async {
    if (_clinicianLogicalId == null) {
      print('⚠️ _clinicianLogicalId is null');
      return;
    }

    try {
      print('🔍 Loading pending requests for: $_clinicianLogicalId');

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: _clinicianLogicalId)
          .where('recipientType', isEqualTo: 'clinician')
          .where('type', isEqualTo: 'join_request')
          .where('status', isEqualTo: 'pending')
          .get();

      print('🔍 Found ${snapshot.docs.length} pending requests');

      List<Map<String, dynamic>> requests = [];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        
        // Get patient ID from the notification
        final patientId = data['senderId'] as String?;
        
        if (patientId != null) {
          // ✅ Fetch patient document to get profile data
          try {
            final patientQuery = await FirebaseFirestore.instance
                .collection('patients')
                .where('patientId', isEqualTo: patientId)
                .limit(1)
                .get();

            if (patientQuery.docs.isNotEmpty) {
              final patientData = patientQuery.docs.first.data();
              
              // ✅ Merge patient data with notification data
              data['fullName'] = patientData['fullName'] ?? 'Unknown';
              data['contactEmail'] = patientData['contactEmail'] ?? '';
              data['dateOfBirth'] = patientData['dateOfBirth'] ?? '';
              data['gender'] = patientData['gender'] ?? '';
              data['profileImageBase64'] = patientData['profileImageBase64'];
              data['patientId'] = patientId;
            } else {
              // Fallback to notification data if patient not found
              data['fullName'] = data['patientName'] ?? 'Unknown';
              data['profileImageBase64'] = null;
            }
          } catch (e) {
            print('⚠️ Error fetching patient data for $patientId: $e');
            data['fullName'] = data['patientName'] ?? 'Unknown';
            data['profileImageBase64'] = null;
          }
        } else {
          data['fullName'] = data['patientName'] ?? 'Unknown';
          data['profileImageBase64'] = null;
        }

        data['id'] = doc.id;
        requests.add(data);
      }

      setState(() {
        _pendingRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading pending requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    if (_clinicianLogicalId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: _clinicianLogicalId)
          .where('recipientType', isEqualTo: 'clinician')
          .where('isRead', isEqualTo: false)
          .get();

      setState(() => _unreadCount = snapshot.docs.length);
    } catch (_) {}
  }

  Future<void> _acceptPendingRequest(Map<String, dynamic> request) async {
    final patientId = request['senderId'] as String? ?? '';
    final patientName = request['fullName'] ?? request['patientName'] ?? 'Patient';
    final requestId = request['id'] as String?;

    print('✅ ACCEPT: patientId=$patientId, requestId=$requestId');

    if (patientId.isEmpty || requestId == null || _clinicianId == null) {
      print('❌ Missing data for accept');
      return;
    }

    try {
      // 1. Assign patient to this clinician
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      if (patientDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientDoc.docs.first.id)
            .update({'clinicianId': _clinicianId});
        print('✅ Patient assigned');
      } else {
        print('⚠️ Patient not found for patientId: $patientId');
      }

      // 2. Delete the join request notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .delete();
      print('✅ Request notification deleted');

      // 3. Create acceptance notification FOR THE PATIENT
      final docRef = await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': patientId,
        'recipientType': 'patient',
        'senderId': _clinicianLogicalId,
        'senderType': 'clinician',
        'senderName': _doctorName,
        'type': 'join_response',
        'decision': 'accepted',
        'title': 'Request Accepted',
        'message': 'Your doctor has accepted your request. You are now assigned!',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('✅ Acceptance notification created: ${docRef.id}');

      await _loadAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$patientName has been accepted as your patient.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('❌ Error accepting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept request. Try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _declinePendingRequest(Map<String, dynamic> request) async {
    final patientId = request['senderId'] as String? ?? '';
    final patientName = request['fullName'] ?? request['patientName'] ?? 'Patient';
    final requestId = request['id'] as String?;

    print('❌ DECLINE: patientId=$patientId, requestId=$requestId');

    if (patientId.isEmpty || requestId == null) {
      print('❌ Missing data for decline');
      return;
    }

    try {
      // 1. Delete the join request notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .delete();
      print('✅ Request notification deleted');

      // 2. Create decline notification FOR THE PATIENT
      final docRef = await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': patientId,
        'recipientType': 'patient',
        'senderId': _clinicianLogicalId,
        'senderType': 'clinician',
        'senderName': _doctorName,
        'type': 'join_response',
        'decision': 'declined',
        'title': 'Request Declined',
        'message': 'Your request was not accepted at this time.',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('✅ Decline notification created: ${docRef.id}');

      await _loadAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$patientName\'s request has been declined.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      print('❌ Error declining: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline request. Try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    var list = _activeFilter == 'assigned' ? _patients : _pendingRequests;

    if (_searchQuery.isNotEmpty) {
      list = list.where((Map<String, dynamic> p) {
        final name = (p['fullName'] ?? p['patientName'] ?? '');
        final email = (p['contactEmail'] ?? '');
        return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            email.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    return list;
  }

  String _ageFromDob(String dob) {
    if (dob.isEmpty) return '';
    try {
      final birth = DateTime.parse(dob);
      final years = DateTime.now().difference(birth).inDays ~/ 365;
      return '$years yrs';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = _doctorName.split(' ');
    final firstName = parts.length > 1 ? parts[1] : parts.firstOrNull ?? _doctorName;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: AppColors.primaryDeep,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
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
                          color: AppColors.textSecondaryLight,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textSecondaryLight,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        _activeFilter == 'assigned' ? 'Assigned Patients' : 'Pending Requests',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryDeep)),
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

  // ✅ UPDATED: _buildPatientRow with profile image support
  Widget _buildPatientRow(Map<String, dynamic> patient) {
    final name = patient['fullName'] ?? patient['patientName'] ?? 'Unknown';
    final email = patient['contactEmail'] ?? '';
    final dob = patient['dateOfBirth'] ?? '';
    final gender = patient['gender'] ?? '';
    final age = _ageFromDob(dob);
    final isPending = _activeFilter == 'pending';
    
    // ✅ Get profile image if available
    final imageBase64 = patient['profileImageBase64'];

    final parts = name.split(' ').where((String e) => e.isNotEmpty).take(2).toList();
    final initials = parts.map((String e) => e[0]).join();

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
      onTap: isPending
          ? null
          : () {
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
            // ✅ Updated avatar with profile image support
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageBase64 != null && imageBase64.toString().isNotEmpty
                  ? Image.memory(
                      base64Decode(imageBase64),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to initials if image fails to load
                        return Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: avatarColor,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMid.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primaryMid.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMid,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (dob.isNotEmpty)
                    Text(
                      'DOB: $dob',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  if (isPending) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _acceptPendingRequest(patient),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Accept',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _declinePendingRequest(patient),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.danger.withValues(alpha: 0.20),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!isPending)
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