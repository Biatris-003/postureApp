import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../data/datasources/chat_service_mock.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _recipientImageBase64;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the chat
    Future.microtask(() {
      final user = ref.read(authStateProvider);
      if (user != null) {
        ref.read(chatServiceProvider).markAsRead(widget.chatId, user.uid);
      }
    });
    _loadRecipientImage();
  }

  Future<void> _loadRecipientImage() async {
    try {
      // Recipient could be a patient or a clinician depending on who's
      // viewing this chat — try both collections by their logical ID field.
      final patientQuery = await FirebaseFirestore.instance
          .collection('patients')
          .where('patientId', isEqualTo: widget.recipientId)
          .limit(1)
          .get();

      if (patientQuery.docs.isNotEmpty) {
        final img = patientQuery.docs.first.data()['profileImageBase64'] as String?;
        if (img != null && mounted) setState(() => _recipientImageBase64 = img);
        return;
      }

      final clinicianQuery = await FirebaseFirestore.instance
          .collection('clinicians')
          .where('clinicianId', isEqualTo: widget.recipientId)
          .limit(1)
          .get();

      if (clinicianQuery.docs.isNotEmpty) {
        final img = clinicianQuery.docs.first.data()['profileImageBase64'] as String?;
        if (img != null && mounted) setState(() => _recipientImageBase64 = img);
      }
    } catch (e) {
      debugPrint('Error loading recipient image: $e');
    }
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(day);
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final user = ref.read(authStateProvider);
    if (user == null) return;

    _messageController.clear();

    try {
      await ref.read(chatServiceProvider).sendMessage(
            chatId: widget.chatId,
            senderId: user.uid,
            receiverId: widget.recipientId,
            content: content,
          );
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Failed to send message: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryDeep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryDeep.withValues(alpha: 0.10),
              ),
              clipBehavior: Clip.antiAlias,
              child: _recipientImageBase64 != null
                  ? Image.memory(
                      base64Decode(_recipientImageBase64!),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    )
                  : Center(
                      child: Text(
                        widget.recipientName.isNotEmpty
                            ? widget.recipientName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: AppColors.textPrimaryLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // const Text(
                  //   'Online',
                  //   style: TextStyle(
                  //     color: AppColors.success,
                  //     fontSize: 11,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ref.read(chatServiceProvider).getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryDeep),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 64, color: AppColors.primaryDeep.withValues(alpha: 0.18)),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet.\nSay hello!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  );
                }

final messages = snapshot.data!;

                // `messages` arrives newest-first (matches reverse: true).
                // Walk it oldest-first to decide where day boundaries fall,
                // then flip the combined (message + date marker) list back
                // so it lines up with the reversed ListView.
                final chronological = messages.reversed.toList();
                final items = <Object>[];
                DateTime? lastDay;

                for (final message in chronological) {
                  final day = DateTime(
                    message.timestamp.year,
                    message.timestamp.month,
                    message.timestamp.day,
                  );
                  if (lastDay == null || day != lastDay) {
                    items.add(day);
                    lastDay = day;
                  }
                  items.add(message);
                }

                final displayItems = items.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    if (item is DateTime) {
                      return _buildDateDivider(item);
                    }
                    final message = item as ChatMessage;
                    final isMe = message.senderId == user?.uid;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime day) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _dayLabel(day),
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryDeep : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primaryDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}