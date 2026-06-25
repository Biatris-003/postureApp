import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';

class FindDoctorScreen extends StatefulWidget {
  final String patientDocId;
  final String patientLogicalId;
  final String patientName;

  const FindDoctorScreen({
    super.key,
    required this.patientDocId,
    required this.patientLogicalId,
    required this.patientName,
  });

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  List<Map<String, dynamic>> _doctors = [];
  Map<String, String> _requestStatus = {}; // clinicianDocId → status
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Load all clinicians
      final snap = await FirebaseFirestore.instance
          .collection('clinicians')
          .get();
      _doctors = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['docId'] = doc.id;
        return data;
      }).toList();

      // ✅ Load from notifications collection instead of joinRequests
      _requestStatus = {};
      
      // Check for pending requests
      final reqSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: widget.patientLogicalId)
          .where('type', isEqualTo: 'join_request')
          .get();

      for (final doc in reqSnap.docs) {
        final data = doc.data();
        final recipientId = data['recipientId'] as String? ?? '';
        final status = data['status'] as String? ?? 'pending';
        if (recipientId.isNotEmpty) {
          // Store by clinician docId - we need to find the clinician docId from the logical ID
          // Find the clinician document with this logical ID
          final clinicianQuery = await FirebaseFirestore.instance
              .collection('clinicians')
              .where('clinicianId', isEqualTo: recipientId)
              .limit(1)
              .get();
          
          if (clinicianQuery.docs.isNotEmpty) {
            final clinicianDocId = clinicianQuery.docs.first.id;
            _requestStatus[clinicianDocId] = status;
          }
        }
      }

      // Check if already assigned
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientDocId)
          .get();
      final assignedClinicianId =
          patientDoc.data()?['clinicianId'] as String? ?? '';
      if (assignedClinicianId.isNotEmpty) {
        _requestStatus[assignedClinicianId] = 'assigned';
      }
    } catch (e) {
      print('❌ Error in _load: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sendRequest(Map<String, dynamic> doctor) async {
    final clinicianDocId = doctor['docId'] as String;
    final clinicianLogicalId = doctor['clinicianId'] as String? ?? clinicianDocId;
    final doctorName = doctor['fullName'] as String? ?? 'Doctor';

    print('======================');
    print('SEND REQUEST START');
    print('recipientId = $clinicianLogicalId');
    print('patientId = ${widget.patientLogicalId}');
    print('patientName = ${widget.patientName}');
    print('======================');

    // ✅ Set pending status immediately
    setState(() {
      _requestStatus[clinicianDocId] = 'pending';
    });

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'recipientId': clinicianLogicalId,
        'recipientType': 'clinician',
        'senderId': widget.patientLogicalId,
        'senderType': 'patient',
        'patientName': widget.patientName,
        'type': 'join_request',
        'status': 'pending', // ✅ Add status field
        'title': 'New Patient Request',
        'message': '${widget.patientName} wants to connect with you.',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print('✅ DOCUMENT CREATED: ${docRef.id}');

      final check = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docRef.id)
          .get();

      print('✅ EXISTS = ${check.exists}');
      print('✅ DATA = ${check.data()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request sent to $doctorName!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e, s) {
      print('❌ ERROR WRITING NOTIFICATION');
      print(e);
      print(s);
      
      // ✅ Revert status on error
      setState(() {
        _requestStatus.remove(clinicianDocId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request. Try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _doctors;
    final q = _search.toLowerCase();
    return _doctors.where((Map<String, dynamic> d) {
      return (d['fullName'] ?? '').toLowerCase().contains(q) ||
          (d['specialty'] ?? '').toLowerCase().contains(q) ||
          (d['institution'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPrimaryLight, size: 18),
                  ),
                  const Expanded(
                    child: Text(
                      'Find a Doctor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name, specialty...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondaryLight, 
                      fontSize: 14
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondaryLight, 
                      size: 20
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 14
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primaryDeep,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryDeep))
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text('No doctors found',
                              style: TextStyle(
                                  color: AppColors.textSecondaryLight)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primaryDeep,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                20, 0, 20, 40),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) =>
                                _buildDoctorCard(_filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final docId = doctor['docId'] as String;
    final name = doctor['fullName'] as String? ?? 'Doctor';
    final specialty = doctor['specialty'] as String? ?? '';
    final institution = doctor['institution'] as String? ?? '';
    final status = _requestStatus[docId];
    final profileImage = doctor['profileImageBase64'] as String?;

    final initials = name
        .split(' ')
        .where((String e) => e.isNotEmpty)
        .take(2)
        .map((String e) => e[0])
        .join();

    // Button state
    Widget actionButton;
    if (status == 'assigned') {
      actionButton = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Your Doctor',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (status == 'pending') {
      actionButton = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.textSecondaryLight.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(
            color: AppColors.textSecondaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      actionButton = GestureDetector(
        onTap: () => _sendRequest(doctor),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryMid,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Doctor Avatar - now with image support
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryDeep.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: profileImage != null && profileImage.isNotEmpty
                ? Image.memory(
                    base64Decode(profileImage),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 17,
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
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                if (specialty.isNotEmpty)
                  Text(specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      )),
                if (institution.isNotEmpty)
                  Text(institution,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          actionButton,
        ],
      ),
    );
  }
}