import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../auth/screens/auth_screen.dart';

import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'privacy_data_screen.dart';

class AdvisorProfileTab extends ConsumerStatefulWidget {
  const AdvisorProfileTab({super.key});

  @override
  ConsumerState<AdvisorProfileTab> createState() => _AdvisorProfileTabState();
}

class _AdvisorProfileTabState extends ConsumerState<AdvisorProfileTab> {
  Map<String, dynamic>? _clinicianData;
  String? _clinicianId;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _resolveClinicianAndLoad();
  }

  Future<void> _resolveClinicianAndLoad() async {
    try {
      final appUser = ref.read(authStateProvider);
      if (appUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final query = await FirebaseFirestore.instance
          .collection('clinicians')
          .where('userId', isEqualTo: appUser.userId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      _clinicianId = query.docs.first.id;
      await _loadClinicianData();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClinicianData() async {
    if (_clinicianId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clinicians')
          .doc(_clinicianId!)
          .get();
      setState(() {
        _clinicianData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditProfile(
      String name, String specialty, String institution, String email) async {
    if (_clinicianId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          clinicianId: _clinicianId!,
          initialName: name,
          initialSpecialty: specialty,
          initialInstitution: institution,
          initialEmail: email,
          initialImageBase64: _clinicianData?['profileImageBase64'],
        ),
      ),
    );
    if (result == true) {
      await _loadClinicianData();
      if (mounted) AppToast.show(context, message: 'Profile updated successfully');
    }
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyDataScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _ProfileSkeleton();

    if (_clinicianId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Could not load profile.\nPlease log in again.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      );
    }

    final name = _clinicianData?['fullName'] ?? 'Dr. Unknown';
    final specialty = _clinicianData?['specialty'] ?? 'Specialist';
    final institution = _clinicianData?['institution'] ?? '';
    final email = _clinicianData?['contactEmail'] ?? '';
    final initials = name.split(' ').map((e) => e[0]).take(2).join();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(name, specialty, institution, initials),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Account'),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    children: [
                      _buildInfoRow(Icons.email_outlined, 'Email', email),
                      const Divider(height: 1, indent: 64),
                      _buildTapRow(
                        Icons.edit_outlined,
                        'Edit Profile',
                        () => _openEditProfile(name, specialty, institution, email),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('Preferences'),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    children: [
                      _buildSwitchRow(
                        Icons.notifications_outlined,
                        'Notifications',
                        _notificationsEnabled,
                        (val) => setState(() => _notificationsEnabled = val),
                      ),
                      const Divider(height: 1, indent: 64),
                      _buildTapRow(
                        Icons.shield_outlined,
                        'Privacy & Data',
                        _openPrivacy,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(authServiceProvider).logout();
                        ref.read(authStateProvider.notifier).setUser(null);
                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                            (route) => false,
                          );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: BorderSide(color: Colors.red.shade100),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader(
    String name,
    String specialty,
    String institution,
    String initials,
  ) {
    final image = _clinicianData?['profileImageBase64'];

    return Container(
      height: 340,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [

            Positioned(
              right: -60,
              top: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .18),
                ),
              ),
            ),

            Positioned(
              right: 40,
              top: 120,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .10),
                ),
              ),
            ),

            // Doctor photo — no camera button, purely display
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              width: MediaQuery.of(context).size.width * 0.55,
              child: image != null
                  ? Image.memory(
                      base64Decode(image),
                      fit: BoxFit.fitHeight,
                      alignment: Alignment.bottomCenter,
                      filterQuality: FilterQuality.high,
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 90,
                          color: Colors.black.withValues(alpha: .12),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),

            // Left text 
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.52,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 20, top: 28, bottom: 28, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // const Spacer(flex: 7),
                    const SizedBox(height: 60),
                    Text(
                      specialty.toUpperCase(),
                      style: TextStyle(
                        color: const Color.fromARGB(255, 30, 44, 61).withValues(alpha: .70),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      maxLines: 3,
                      style: const TextStyle(
                        height: 1.1,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2430),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (institution.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1.5),
                            child: Icon(
                              Icons.location_city_rounded,
                              size: 13,
                              color: AppColors.primaryDeep.withValues(alpha: .65),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              institution,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color.fromARGB(255, 30, 44, 61).withValues(alpha: .80),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryLight,
          letterSpacing: 0.6,
        ),
      );

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _iconBadge(IconData icon) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryDeep.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.primaryDeep),
      );

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _iconBadge(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
      IconData icon, String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _iconBadge(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildTapRow(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBadge(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 340,
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(42),
                  bottomRight: Radius.circular(42),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}