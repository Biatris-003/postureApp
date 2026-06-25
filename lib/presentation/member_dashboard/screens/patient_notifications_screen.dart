import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class PatientNotificationsScreen extends StatefulWidget {
  final String patientLogicalId;
  final VoidCallback? onGoToExercises;

  const PatientNotificationsScreen({
    super.key,
    required this.patientLogicalId,
    this.onGoToExercises,
  });

  @override
  State<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends State<PatientNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
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
      'label': 'Message',
    },
    'doctor_message': {
      'icon': Icons.mail_outline,
      'accentColor': const Color(0xFF1E88E5),
      'label': 'Doctor Message',
    },
    'join_response': {
      'icon': Icons.notifications_outlined,
      'accentColor': const Color(0xFF7E57C2),
      'label': 'Request Response',
    },
    'bad_posture_streak': {
      'icon': Icons.warning_amber_outlined,
      'accentColor': const Color(0xFFE08A00),
      'label': 'Posture Alert',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (widget.patientLogicalId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ FIXED: Use recipientId + recipientType for patient
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: widget.patientLogicalId)
          .where('recipientType', isEqualTo: 'patient')
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
      for (final n in _notifications) {
        n['isRead'] = true;
      }
    });
  }

  Future<void> _deleteNotification(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .delete();
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
  }

  void _handleTap(Map<String, dynamic> notification) async {
    if (notification['isRead'] == false) {
      await _markAsRead(notification['id']);
    }

    final type = notification['type'] ?? '';

    if (!mounted) return;

    switch (type) {
      case 'exercise_assigned':
        widget.onGoToExercises?.call();
        Navigator.pop(context);
        break;
      case 'join_response':
        // Just show the status - already displayed in the card
        break;
      case 'doctor_message':
      case 'patient_message':
        // Navigate to chat with doctor
        final senderId = notification['senderId'] ?? '';
        final senderName = notification['senderName'] ?? 'Doctor';
        if (senderId.isNotEmpty) {
          // You can navigate to chat here if you have a chat screen
          // For now, just show a snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Open chat with $senderName'),
              backgroundColor: AppColors.primaryDeep,
            ),
          );
        }
        break;
      case 'report_generated':
        // Navigate to report
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('View your report'),
            backgroundColor: AppColors.primaryDeep,
          ),
        );
        break;
    }
  }

  String _timeAgo(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _dateGroup(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(nDay).inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return DateFormat('d MMMM yyyy').format(nDay);
    } catch (_) {
      return '';
    }
  }

  int get _unreadCount => _notifications.where((n) => n['isRead'] == false).length;

  List<Map<String, dynamic>> get _filtered =>
      _showUnreadOnly
          ? _notifications.where((n) => n['isRead'] == false).toList()
          : _notifications;

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primaryDeep),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
              icon: const Icon(
                Icons.done_all,
                color: AppColors.primaryDeep,
                size: 22,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.primaryDeep,
        child: CustomScrollView(
          slivers: [
            // Filter tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
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
                        _unreadCount > 0 ? 'Unread $_unreadCount' : 'Unread',
                        _showUnreadOnly,
                        () => setState(() => _showUnreadOnly = true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryDeep)),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 56,
                        color: AppColors.primaryDeep.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No notifications here',
                        style: TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
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
                              top: 16,
                              bottom: 10,
                              left: 4,
                            ),
                            child: Text(
                              group,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight,
                                letterSpacing: 0.3,
                              ),
                            ),
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
    final decision = notification['decision'] as String?;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: accentColor),
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
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
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
                                      maxLines: 2,
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
                // ✅ Show decision status for join_response
                if (type == 'join_response' && decision != null) ...[
                  const Divider(height: 1, color: AppColors.borderLight),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          decision == 'accepted'
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 16,
                          color: decision == 'accepted'
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          decision == 'accepted'
                              ? ' Request Accepted'
                              : ' Request Declined',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: decision == 'accepted'
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}