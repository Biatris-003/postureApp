import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'assigned_members_tab.dart';
import 'advisor_profile_tab.dart';
import 'notifications_tab.dart';

class AdvisorDashboardScreen extends ConsumerStatefulWidget {
  const AdvisorDashboardScreen({super.key});

  @override
  ConsumerState<AdvisorDashboardScreen> createState() =>
      _AdvisorDashboardScreenState();
}

class _AdvisorDashboardScreenState
    extends ConsumerState<AdvisorDashboardScreen> {
  int _currentIndex = 0;
  String? _clinicianLogicalId; // e.g. "c001" — matches notifications.clinicianId
  
  // ✅ GlobalKey to access AssignedMembersTabState
  final GlobalKey<AssignedMembersTabState> _assignedMembersKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _resolveClinicianId();
  }

  // ── Resolve clinicianId from the logged-in user ──────────
  Future<void> _resolveClinicianId() async {
    final appUser = ref.read(authStateProvider); // AppUser?
    if (appUser == null) return;

    final query = await FirebaseFirestore.instance
        .collection('clinicians')
        .where('userId', isEqualTo: appUser.userId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final doc = query.docs.first;
    setState(() {
      // notifications.clinicianId stores the logical ID (e.g. "c001"),
      // not the Firestore doc ID — fall back to doc.id only if the field
      // is missing, same resolution pattern used in AssignedMembersTab.
      _clinicianLogicalId = doc.data()['clinicianId'] as String? ?? doc.id;
    });
  }

  Widget _getTab(int index) {
    switch (index) {
      case 0:
        return AssignedMembersTab(
          key: _assignedMembersKey, // ✅ Pass the key
          onNotificationsTap: () {
            // Switch to notifications tab
            setState(() {
              _currentIndex = 1;
            });
          },
        );
      case 1:
        return NotificationsTab(
          onPendingRequestsTap: () {
            // Switch to Assigned Members tab and show pending requests
            setState(() {
              _currentIndex = 0;
            });
            // Call showPendingRequests on the AssignedMembersTab
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _assignedMembersKey.currentState?.showPendingRequests();
            });
          },
        );
      case 2:
        return const AdvisorProfileTab();
      default:
        return AssignedMembersTab(
          key: _assignedMembersKey,
          onNotificationsTap: () {
            setState(() {
              _currentIndex = 1;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: _getTab(_currentIndex),

      // ── Bottom Navigation ─────────────────────────
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.people_outline,
                label: 'Patients',
              ),
              _buildNavItemWithRedDot(
                index: 1,
                icon: Icons.notifications_outlined,
                label: 'Notifications',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Normal Nav Item ──────────────────────────────

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryMid
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondaryLight,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Nav Item with RED DOT (like patient version) ─────────

  Widget _buildNavItemWithRedDot({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    if (_clinicianLogicalId == null) {
      return _buildNavItem(
        index: index,
        icon: icon,
        label: label,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: _clinicianLogicalId)
          .where('recipientType', isEqualTo: 'clinician')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 14 : 10,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryMid
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondaryLight,
                    ),
                    // ✅ RED DOT only (no number)
                    if (count > 0)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}