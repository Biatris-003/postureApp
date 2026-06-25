import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ble/ble_monitor_provider.dart';
import '../../../services/ble/ble_receiver.dart';
import 'settings_tab.dart';
import 'edit_patient_profile_screen.dart';
import '../../advisor_dashboard/screens/privacy_data_screen.dart';
import '../../auth/screens/auth_screen.dart';
import '../../../services/session_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  Map<String, dynamic>? _patientData;
  String? _patientId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolvePatientAndLoad();
  }

  // ── Step 1: find the patient doc that belongs to the logged-in user ──
  Future<void> _resolvePatientAndLoad() async {
    try {
      final appUser = ref.read(authStateProvider); // AppUser?
      if (appUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('patients')
          .where('userId', isEqualTo: appUser.userId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      _patientId = query.docs.first.id;
      await _loadPatientData();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Step 2: load the full patient document ────────────────────────────
  Future<void> _loadPatientData() async {
    if (_patientId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_patientId!)
          .get();
      setState(() {
        _patientData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditProfile(
    String name,
    String email,
    String gender,
    String dob,
    String language,
  ) async {
    if (_patientId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPatientProfileScreen(
          patientId: _patientId!,
          initialName: name,
          initialEmail: email,
          initialGender: gender,
          initialDateOfBirth: dob,
          initialLanguage: language,
          initialImageBase64: _patientData?['profileImageBase64'],
        ),
      ),
    );
    if (result == true) {
      await _loadPatientData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
    if (_isLoading) return const _PatientProfileSkeleton();

    if (_patientId == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Could not load profile.\nPlease log in again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = _patientData?['fullName'] as String? ?? 'Unknown';
    final email = _patientData?['contactEmail'] as String? ?? '';
    final gender = _patientData?['gender'] as String? ?? '';
    final dob = _patientData?['dateOfBirth'] as String? ?? '';
    final language = _patientData?['preferredLanguage'] as String? ?? '';
    final initials = name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join();
    final image = _patientData?['profileImageBase64'] as String?;
    final monitor = ref.watch(bleMonitorProvider);
    final enabledMap = ref.watch(enabledSensorsProvider);
    final sensors = _sensorChargeInfo(monitor, enabledMap);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderBlock(
              name: name,
              initials: initials,
              image: image,
              email: email,
              onEdit: () => _openEditProfile(name, email, gender, dob, language),
            ),
            // Pulls the content block up to close the gap left by the
            // floating card's overlap (Transform doesn't shrink reserved
            // space, so without this the gap below the card = cardOverlap).
            Transform.translate(
              offset: const Offset(0, -84), // cardOverlap (100) minus desired gap (16)
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel('Personal Information'),
                    const SizedBox(height: 10),
                    _buildInfoCard(gender, dob, language),
                    const SizedBox(height: 24),
                    _sectionLabel('Sensor Charge'),
                    const SizedBox(height: 10),
                    _buildSensorChargeCard(sensors),
                    const SizedBox(height: 24),
                    _sectionLabel('Account Settings'),
                    const SizedBox(height: 10),
                    _buildSettingsGroup(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top background block + floating profile card ─────────────────────

  Widget _buildHeaderBlock({
    required String name,
    required String initials,
    required String? image,
    required String email,
    required VoidCallback onEdit,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bgHeight = screenHeight * 0.26;
    const cardOverlap = 120.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Solid background panel — rounded bottom corners only ──
        Container(
          height: bgHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDeep, AppColors.primaryMid],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
              ),
            ),
          ),
        ),
        // ── Floating profile card, pulled up to overlap the panel ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Transform.translate(
            offset: const Offset(0, -cardOverlap),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryDeep.withValues(alpha: 0.10),
                      border: Border.all(color: AppColors.borderLight, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: image != null
                        ? Image.memory(
                            base64Decode(image),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          )
                        : Center(
                            child: Text(
                              initials.isEmpty ? '?' : initials,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Role subtitle
                  const Text(
                    'Patient',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action pill — "Edit Profile" in place of "Connect"
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                      decoration: const ShapeDecoration(
                        color: AppColors.primaryDeep,
                        shape: StadiumBorder(),
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description block
                  Text(
                    email.isEmpty
                        ? 'Tracking posture and mobility progress with Smart Posture Monitoring System.'
                        : email,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section label ────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryLight,
          letterSpacing: 0.6,
        ),
      );

  // ── Shared card wrapper ───────────────────────────────────

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Personal Info Card ────────────────────────────────────
  // Email now lives in the profile card's description block above, so it's
  // dropped here to avoid showing the same value twice.

  Widget _buildInfoCard(String gender, String dob, String language) {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
      child: Column(
        children: [
          _buildInfoRow(Icons.wc_outlined, 'Gender', gender),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildInfoRow(Icons.cake_outlined, 'Date of Birth', dob),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildInfoRow(Icons.language_outlined, 'Language', language),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDeep),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hardware Card ─────────────────────────────────────────

  Widget buildHardwareCard() {
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bluetooth_connected_rounded,
              color: AppColors.success,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Shirt Sensors',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Connected • Synced just now',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.battery_4_bar_rounded, color: AppColors.success, size: 22),
              const SizedBox(height: 4),
              const Text(
                '82%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Settings Group ────────────────────────────────────────

  List<_SensorChargeInfo> _sensorChargeInfo(
    BleMonitorState monitor,
    Map<String, bool> enabledMap,
  ) {
    const locations = {
      'C7': 'Neck',
      'T4': 'Upper back',
      'T12': 'Lower thoracic',
      'L5': 'Lower back',
    };

    return kSensorIdMap.entries.map((entry) {
      final mac = entry.key;
      final label = entry.value;
      final enabled = enabledMap[mac] ?? true;
      final connected = enabled && (monitor.connections[mac] ?? false);
      return _SensorChargeInfo(
        label: label,
        location: locations[label] ?? label,
        batteryPct: monitor.batteryLevels[mac] ?? 0,
        connected: connected,
        enabled: enabled,
      );
    }).toList();
  }

  Color _batteryColor(int pct) {
    if (pct >= 60) return AppColors.success;
    if (pct >= 30) return const Color(0xFFB8860B);
    return AppColors.danger;
  }

  IconData _batteryIcon(int pct) {
    if (pct >= 80) return Icons.battery_full_rounded;
    if (pct >= 60) return Icons.battery_5_bar_rounded;
    if (pct >= 40) return Icons.battery_3_bar_rounded;
    if (pct >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  Widget _buildSensorChargeCard(List<_SensorChargeInfo> sensors) {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < sensors.length; i++) ...[
            _buildSensorChargeRow(sensors[i]),
            if (i < sensors.length - 1)
              const Divider(height: 1, indent: 72, color: AppColors.borderLight),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorChargeRow(_SensorChargeInfo sensor) {
    final showBattery = sensor.enabled && sensor.connected;
    final batteryColor =
        showBattery ? _batteryColor(sensor.batteryPct) : AppColors.textSecondaryLight;
    final batteryIcon =
        showBattery ? _batteryIcon(sensor.batteryPct) : Icons.battery_unknown_rounded;
    final status = !sensor.enabled
        ? 'Disabled'
        : sensor.connected
            ? 'Connected'
            : 'Offline';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(
              sensor.label,
              style: const TextStyle(
                color: AppColors.primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sensor.location,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sensor.connected ? AppColors.success : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(batteryIcon, color: batteryColor, size: 20),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    showBattery ? '${sensor.batteryPct}%' : 'N/A',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: batteryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup() {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.settings_outlined,
            title: 'Feedback Settings',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
              size: 24,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsTab()),
              );
            },
          ),
          const Divider(height: 1, indent: 64, color: AppColors.borderLight),
          _buildSettingsTile(
            icon: Icons.security_outlined,
            title: 'Privacy & Data',
            onTap: _openPrivacy,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
              size: 24,
            ),
          ),
          const Divider(height: 1, indent: 64, color: AppColors.borderLight),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 24),
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            // onTap: () {
            //   ref.read(authServiceProvider).logout();
            //   ref.read(authStateProvider.notifier).setUser(null);
              onTap: () async {
                await ref.read(authServiceProvider).logout();
                ref.read(authStateProvider.notifier).setUser(null);

                if (!mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AuthScreen(),
                  ),
                  (route) => false,
                );
              },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryDeep.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryDeep, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.textPrimaryLight,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────

class _SensorChargeInfo {
  const _SensorChargeInfo({
    required this.label,
    required this.location,
    required this.batteryPct,
    required this.connected,
    required this.enabled,
  });

  final String label;
  final String location;
  final int batteryPct;
  final bool connected;
  final bool enabled;
}

class _PatientProfileSkeleton extends StatelessWidget {
  const _PatientProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 240,
              decoration: const BoxDecoration(
                color: AppColors.primaryDeep,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
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
