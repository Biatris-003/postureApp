import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/datasources/auth_service_mock.dart';
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
  String? _clinicianId; // ✅ resolved dynamically, no longer hardcoded

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

    setState(() {
      _clinicianId = query.docs.first.id; // e.g. 'c001'
    });
  }

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
      backgroundColor: const Color(0xFFF8FAFD),
      body: _getTab(_currentIndex),

      // ── Bottom Navigation ─────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                    0, Icons.people_outline, Icons.people, 'Patients'),

                _buildNavItemWithLiveBadge(
                  1,
                  Icons.notifications_outlined,
                  Icons.notifications,
                  'Alerts',
                ),

                _buildNavItem(
                    2, Icons.person_outline, Icons.person, 'Profile'),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1565C0).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color:
                  isSelected ? const Color(0xFF1565C0) : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : Colors.grey.shade400,
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

    // ✅ If clinicianId not resolved yet, show badge with 0 (no crash)
    if (_clinicianId == null) {
      return _buildNavItem(index, icon, activeIcon, label);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('clinicianId', isEqualTo: _clinicianId) // ✅ dynamic
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
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1565C0).withOpacity(0.1)
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
                          ? const Color(0xFF1565C0)
                          : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade400,
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