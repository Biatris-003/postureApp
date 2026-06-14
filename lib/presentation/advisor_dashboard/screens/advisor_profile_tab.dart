import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/auth_service_mock.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';



class AdvisorProfileTab extends ConsumerStatefulWidget {
  const AdvisorProfileTab({Key? key}) : super(key: key);

  @override
  ConsumerState<AdvisorProfileTab> createState() => _AdvisorProfileTabState();
}

class _AdvisorProfileTabState extends ConsumerState<AdvisorProfileTab> {
  Map<String, dynamic>? _clinicianData;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  /// Returns the UID of the currently logged-in clinician.
  String get _clinicianId => ref.read(authStateProvider)?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadClinicianData();
  }

  Future<void> _pickAndSaveImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    
    if (picked == null) return;

    setState(() => _isLoading = true);

    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);

    await FirebaseFirestore.instance
        .collection('clinicians')
        .doc(_clinicianId)
        .update({'profileImageBase64': base64Image});

    await _loadClinicianData();
  }

  Future<void> _loadClinicianData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clinicians')
          .doc(_clinicianId)
          .get();
      setState(() {
        _clinicianData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final name = _clinicianData?['fullName'] ?? 'Dr. Unknown';
    final specialty = _clinicianData?['specialty'] ?? 'Specialist';
    final institution = _clinicianData?['institution'] ?? '';
    final email = _clinicianData?['contactEmail'] ?? '';
    final initials = name.split(' ').map((e) => e[0]).take(2).join();

    return SingleChildScrollView(
      child: Column(
        children: [

          // ── Header Banner ──────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _pickAndSaveImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child: _clinicianData?['profileImageBase64'] != null
                                  ? Image.memory(
                                      base64Decode(_clinicianData!['profileImageBase64']),
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.white.withOpacity(0.2),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          // Camera icon badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Color(0xFF1565C0),
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
          ),

          // ── Info Cards ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Info card
                _buildSectionCard(
                  children: [
                    _buildInfoRow(Icons.email_outlined, 'Email', email),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.local_hospital_outlined, 'Specialty', specialty),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.business_outlined, 'Institution', institution),
                  ],
                ),

                const SizedBox(height: 12),

                // Edit profile button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      foregroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showEditProfileDialog(name, specialty, institution, email),
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),

                // Settings card
                _buildSectionCard(
                  children: [
                    _buildSwitchRow(
                      Icons.notifications_outlined,
                      'Alerts & Notifications',
                      _notificationsEnabled,
                      (val) => setState(() => _notificationsEnabled = val),
                    ),
                    const Divider(height: 1),
                    _buildTapRow(
                      Icons.shield_outlined,
                      'Privacy & Data',
                      () => _showPrivacyDialog(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                    onPressed: () {
                      ref.read(authServiceProvider).logout();
                      ref.read(authStateProvider.notifier).setUser(null);
                    },
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1565C0)),
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
      ),
    );
  }

  Widget _buildSwitchRow(IconData icon, String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1565C0)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1565C0),
          ),
        ],
      ),
    );
  }

  Widget _buildTapRow(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── Edit Profile Dialog ───────────────────────────────────

  void _showEditProfileDialog(String name, String specialty, String institution, String email) {
    final nameCtrl = TextEditingController(text: name);
    final specialtyCtrl = TextEditingController(text: specialty);
    final institutionCtrl = TextEditingController(text: institution);
    final emailCtrl = TextEditingController(text: email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameCtrl, 'Full Name', Icons.person_outline),
              const SizedBox(height: 12),
              _buildTextField(specialtyCtrl, 'Specialty', Icons.local_hospital_outlined),
              const SizedBox(height: 12),
              _buildTextField(institutionCtrl, 'Institution', Icons.business_outlined),
              const SizedBox(height: 12),
              _buildTextField(emailCtrl, 'Email', Icons.email_outlined),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              // Save to Firestore
              await FirebaseFirestore.instance
                  .collection('clinicians')
                  .doc(_clinicianId)
                  .update({
                'fullName': nameCtrl.text,
                'specialty': specialtyCtrl.text,
                'institution': institutionCtrl.text,
                'contactEmail': emailCtrl.text,
              });
              Navigator.pop(context);
              // Reload data
              _loadClinicianData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Profile updated successfully!'),
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

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ── Privacy & Data Dialog ─────────────────────────────────

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Privacy & Data'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Data Collection', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('We collect posture data, session recordings, and exercise compliance data to provide you and your patients with accurate health insights.'),
              SizedBox(height: 16),
              Text('Data Storage', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('All data is securely stored using Firebase and encrypted in transit. Patient data is only accessible to their assigned clinician.'),
              SizedBox(height: 16),
              Text('Data Sharing', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Patient data is never shared with third parties. Reports are only accessible to the patient and their assigned doctor.'),
              SizedBox(height: 16),
              Text('Your Rights', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('You may request deletion of your account and all associated data at any time by contacting support.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}