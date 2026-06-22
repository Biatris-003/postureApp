import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/assigned_member.dart';
import '../screens/member_details_screen.dart';
import '../screens/chat_screen.dart';

class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<NotificationsTab> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _clinicianId;   // logical ID e.g. "c001"
  bool _showUnreadOnly = false;

  final _typeConfig = {
    'exercise_assigned': {
      'icon': Icons.fitness_center_outlined,
      'accentColor': const Color(0xFF00ACC1),
      'label': 'Exercise Assigned',
    },
    'report_generated': {
      'icon': Icons.description_outlined,
      'accentColor': const Color(0xFF4CAF50),
      'label': 'Report Generated',
    },
    'patient_message': {
      'icon': Icons.mail_outline,
      'accentColor': const Color(0xFF1E88E5),
      'label': 'Patient Message',
    },
    'join_request': {
      'icon': Icons.person_add_outlined,
      'accentColor': const Color(0xFF7E57C2),
      'label': 'Join Request',
    },
  };

  @override
  void initState() {
    super.initState();
    _resolveClinicianAndLoad();
  }

  Future<void> _resolveClinicianAndLoad() async {
    setState(() => _isLoading = true);
    try {
      final appUser = ref.read(authStateProvider);
      if (appUser == null) { setState(() => _isLoading = false); return; }

      final query = await FirebaseFirestore.instance
          .collection('clinicians')
          .where('userId', isEqualTo: appUser.userId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) { setState(() => _isLoading = false); return; }

      _clinicianId = query.docs.first.data()['clinicianId'] as String?
          ?? query.docs.first.id;

      await _seedNotificationsIfEmpty();
      await _loadNotifications();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seedNotificationsIfEmpty() async {
    if (_clinicianId == null) return;
    final existing = await FirebaseFirestore.instance
        .collection('notifications')
        .where('clinicianId', isEqualTo: _clinicianId)
        .where('type', whereIn: ['exercise_assigned', 'report_generated', 'patient_message'])
        .get();
    if (existing.docs.isNotEmpty) return;

    // Get a real patient to seed with
    final clinicianDocQuery = await FirebaseFirestore.instance
        .collection('clinicians')
        .where('clinicianId', isEqualTo: _clinicianId)
        .limit(1)
        .get();
    final clinicianDocId = clinicianDocQuery.docs.isNotEmpty
        ? clinicianDocQuery.docs.first.id
        : '';

    final patientsSnapshot = await FirebaseFirestore.instance
        .collection('patients')
        .where('clinicianId', isEqualTo: clinicianDocId)
        .limit(1)
        .get();

    String patientId = 'p001';
    String patientName = 'Sara Ahmed';
    if (patientsSnapshot.docs.isNotEmpty) {
      final doc = patientsSnapshot.docs.first;
      patientId = doc.data()['patientId'] ?? doc.id;
      patientName = doc.data()['fullName'] ?? 'Sara Ahmed';
    }

    final now = DateTime.now();
    final seeds = [
      {
        'clinicianId': _clinicianId,
        'patientId': patientId,
        'patientName': patientName,
        'type': 'exercise_assigned',
        'title': 'Exercises Assigned',
        'message': 'New exercises have been assigned for $patientName.',
        'timestamp': now.subtract(const Duration(minutes: 15)).toIso8601String(),
        'isRead': false,
      },
      {
        'clinicianId': _clinicianId,
        'patientId': patientId,
        'patientName': patientName,
        'type': 'report_generated',
        'title': 'Report Generated',
        'message': 'A new posture report has been generated for $patientName.',
        'timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'isRead': false,
      },
      {
        'clinicianId': _clinicianId,
        'patientId': patientId,
        'patientName': patientName,
        'type': 'patient_message',
        'title': 'New Message',
        'message': '$patientName sent you a message.',
        'timestamp': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'isRead': true,
      },
    ];

    for (final n in seeds) {
      await FirebaseFirestore.instance.collection('notifications').add(n);
    }
  }

  Future<void> _loadNotifications() async {
    if (_clinicianId == null) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('clinicianId', isEqualTo: _clinicianId)
          .orderBy('timestamp', descending: true)
          .get();
      setState(() {
        _notifications = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
    // Update locally without full reload for instant UI feedback
    setState(() {
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) _notifications[idx]['isRead'] = true;
    });
  }

  Future<void> _markAllAsRead() async {
    final unread = _notifications.where((n) => n['isRead'] == false).toList();
    for (final n in unread) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(n['id'])
          .update({'isRead': true});
    }
    setState(() {
      for (final n in _notifications) n['isRead'] = true;
    });
  }

  Future<void> _deleteNotification(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .delete();
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
  }

  // ── Deep navigation ────────────────────────────────────────

  Future<void> _handleTap(Map<String, dynamic> notification) async {
    // Mark as read first
    if (notification['isRead'] == false) {
      await _markAsRead(notification['id']);
    }

    final type = notification['type'] ?? '';
    final patientId = notification['patientId'] ?? '';
    final patientName = notification['patientName'] ?? 'Patient';

    if (!mounted) return;

    switch (type) {
      case 'exercise_assigned':
        await _navigateToPatientTab(patientId, patientName, tabIndex: 1);
        break;

      case 'report_generated':
        await _navigateToPatientTab(patientId, patientName, tabIndex: 2);
        break;

      case 'patient_message':
        await _navigateToChat(patientId, patientName);
        break;

      case 'join_request':
        // Not implemented yet — show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request management coming soon.'),
            ),
          );
        }
        break;
    }
  }

  Future<void> _navigateToPatientTab(
      String patientId, String patientName, {required int tabIndex}) async {
    // Fetch full patient data so we can build AssignedMember properly
    Map<String, dynamic>? patientData;
    try {
      // Try by logical patientId field first
      final q = await FirebaseFirestore.instance
          .collection('patients')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        patientData = {...q.docs.first.data(), 'id': q.docs.first.id};
      } else {
        // Fallback: try by Firestore doc ID
        final doc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .get();
        if (doc.exists) patientData = {...doc.data()!, 'id': doc.id};
      }
    } catch (_) {}

    final member = AssignedMember(
      uid: patientData?['id'] ?? patientId,
      name: patientData?['fullName'] ?? patientName,
      email: patientData?['contactEmail'] ?? '',
      status: 'Active',
      complianceRate: 0.75,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailsScreen(
          member: member,
          initialTabIndex: tabIndex, // ← pass the tab to open
        ),
      ),
    );
  }

  Future<void> _navigateToChat(String patientId, String patientName) async {
    if (_clinicianId == null) return;

    // chatId convention: c001_p001
    final chatId = '${_clinicianId}_$patientId';

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          recipientId: patientId,
          recipientName: patientName,
        ),
      ),
    );

    // After returning from chat, mark all patient_message notifications
    // for this patient as read (they saw the conversation)
    final toMark = _notifications.where((n) =>
        n['type'] == 'patient_message' &&
        n['patientId'] == patientId &&
        n['isRead'] == false).toList();
    for (final n in toMark) {
      await _markAsRead(n['id']);
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  String _timeAgo(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  String _dateGroup(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(nDay).inDays;
      if (diff == 0) return 'Today, ${_fmtDate(dt)}';
      if (diff == 1) return 'Yesterday, ${_fmtDate(dt)}';
      return _fmtDate(dt);
    } catch (_) { return ''; }
  }

  String _fmtDate(DateTime dt) {
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month]} ${dt.year.toString().substring(2)}';
  }

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] == false).length;

  List<Map<String, dynamic>> get _filtered => _showUnreadOnly
      ? _notifications.where((n) => n['isRead'] == false).toList()
      : _notifications;

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final n in _filtered) {
      final group = _dateGroup(n['timestamp'] ?? '');
      grouped.putIfAbsent(group, () => []).add(n);
    }
    final groupKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          color: AppColors.primaryDeep,
          child: CustomScrollView(
            slivers: [

              // Nav bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      if (_unreadCount > 0)
                        IconButton(
                          onPressed: _markAllAsRead,
                          tooltip: 'Mark all as read',
                          icon: const Icon(Icons.done_all,
                              color: AppColors.primaryDeep, size: 22),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),

              // Tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _pillTab('All', !_showUnreadOnly,
                            () => setState(() => _showUnreadOnly = false)),
                        _pillTab(
                          _unreadCount > 0 ? 'Unread  $_unreadCount' : 'Unread',
                          _showUnreadOnly,
                          () => setState(() => _showUnreadOnly = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Loading
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primaryDeep)),
                )

              // Empty
              else if (_filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 56,
                            color: AppColors.primaryDeep.withValues(alpha: 0.25)),
                        const SizedBox(height: 12),
                        const Text('No notifications here',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                )

              // List
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groupKeys[index];
                        final items = grouped[group]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 16, bottom: 10, left: 4),
                              child: Text(group,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondaryLight,
                                    letterSpacing: 0.3,
                                  )),
                            ),
                            ...items.map((n) => _buildCard(n)),
                          ],
                        );
                      },
                      childCount: groupKeys.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryMid : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> notification) {
    final type = notification['type'] ?? 'general';
    final config = _typeConfig[type] ?? {
      'icon': Icons.notifications_outlined,
      'accentColor': const Color(0xFF7E57C2),
      'label': 'Notification',
    };
    final isRead = notification['isRead'] == true;
    final accentColor = config['accentColor'] as Color;
    final icon = config['icon'] as IconData;
    final title = notification['title'] ?? (config['label'] as String);
    final message = notification['message'] ?? '';
    final time = _timeAgo(notification['timestamp'] ?? '');

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => _deleteNotification(notification['id']),
      child: GestureDetector(
        onTap: () => _handleTap(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Accent bar
                  Container(width: 4, color: accentColor),

                  // Icon
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                  ),

                  // Text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(time,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryLight,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isRead
                                        ? AppColors.textSecondaryLight
                                        : AppColors.textPrimaryLight
                                            .withValues(alpha: 0.75),
                                    height: 1.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}