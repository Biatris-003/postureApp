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
// @override
// void initState() {
//   super.initState();
//   _resolveClinicianId();
// }

// Future<void> _resolveClinicianId() async {
//   final appUser = ref.read(authStateProvider);
//   debugPrint('🔴 BADGE DEBUG — appUser: $appUser');
//   if (appUser == null) {
//     debugPrint('🔴 BADGE DEBUG — STOPPED: appUser is null');
//     return;
//   }

//   final query = await FirebaseFirestore.instance
//       .collection('clinicians')
//       .where('userId', isEqualTo: appUser.userId)
//       .limit(1)
//       .get();

//   debugPrint('🔴 BADGE DEBUG — clinician docs found: ${query.docs.length}');
//   if (query.docs.isEmpty) {
//     debugPrint('🔴 BADGE DEBUG — STOPPED: no clinician doc for userId=${appUser.userId}');
//     return;
//   }

//   final doc = query.docs.first;
//   final resolvedId = doc.data()['clinicianId'] as String? ?? doc.id;
//   debugPrint('🔴 BADGE DEBUG — resolved clinicianLogicalId: $resolvedId');

//   if (!mounted) return;
//   setState(() {
//     _clinicianLogicalId = resolvedId;
//   });
// }
  Widget _getTab(int index) {
    switch (index) {
      case 0:
        return const AssignedMembersTab();
      case 1:
        return const NotificationsTab();
      case 2:
        return const AdvisorProfileTab();
      default:
        return const AssignedMembersTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: _getTab(_currentIndex),

      // ── Bottom Navigation ─────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.people_outline, Icons.people, 'Patients'),
                _buildNavItemWithLiveBadge(
                  1,
                  Icons.notifications_outlined,
                  Icons.notifications,
                  'Alerts',
                ),
                _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Normal Nav Item ──────────────────────────────

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryDeep.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primaryDeep : AppColors.textSecondaryLight,
              size: 23,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryDeep : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Badge Nav Item (REAL-TIME) ─────────────

  Widget _buildNavItemWithLiveBadge(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;

    // If clinicianId not resolved yet, show badge with 0 (no crash)
    if (_clinicianLogicalId == null) {
      return _buildNavItem(index, icon, activeIcon, label);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('clinicianId', isEqualTo: _clinicianLogicalId) // logical ID, matches doc field
          .where('isRead', isEqualTo: false) // unread only
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryDeep.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected
                          ? AppColors.primaryDeep
                          : AppColors.textSecondaryLight,
                      size: 23,
                    ),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryDeep : AppColors.textSecondaryLight,
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