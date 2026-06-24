import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/rag_chat_service.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/auth_service_mock.dart';

class AssistantTab extends ConsumerStatefulWidget {
  const AssistantTab({super.key});

  @override
  ConsumerState<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends ConsumerState<AssistantTab>
    with SingleTickerProviderStateMixin {
  final List<Map<String, String>> _messages = [
    {
      "sender": "bot",
      "text":
          "Hello! I am your Posture AI. How can I assist you with your mobility and posture today?"
    }
  ];
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  
  String? _profileImageBase64;
  String _initials = '';

  @override
  void initState() {
    super.initState();
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    try {
      final appUser = ref.read(authStateProvider);
      if (appUser == null) return;

      // ✅ Same query used by ProfileTab, RagChatService, AnalyticsService
      // appUser.userId = "patient001" — matches patients.userId field
      final query = await FirebaseFirestore.instance
          .collection('patients')
          .where('userId', isEqualTo: appUser.userId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        debugPrint('⚠️ AssistantTab: no patient doc for userId=${appUser.userId}');
        return;
      }

      final data = query.docs.first.data();
      final name = data['fullName'] as String? ?? '';
      final image = data['profileImageBase64'] as String?;
      final initials = name
          .split(' ')
          .where((e) => e.isNotEmpty)
          .map((e) => e[0])
          .take(2)
          .join();

      debugPrint('✅ AssistantTab: profile loaded, hasImage=${image != null}');

      if (mounted) {
        setState(() {
          _profileImageBase64 = image;
          _initials = initials;
        });
      }
    } catch (e) {
      debugPrint('❌ AssistantTab: _loadPatientProfile error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    final reply = await ref.read(ragChatServiceProvider).sendMessage(text);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({"sender": "bot", "text": reply});
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Posture AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to assist',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator(context);
                }

                final msg = _messages[index];
                final isUser = msg["sender"] == "user";
                return _buildChatBubble(context, msg["text"]!, isUser);
              },
            ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).primaryColor,
                size: 18,
              ),
            ),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: isUser
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
          if (isUser)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _profileImageBase64 != null
                  ? Image.memory(
                      base64Decode(_profileImageBase64!),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                    )
                  : _buildInitialsAvatar(),
            ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Center(
      child: Text(
        _initials.isEmpty ? '?' : _initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDeep,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Theme.of(context).primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(context),
                const SizedBox(width: 6),
                _buildDot(context),
                const SizedBox(width: 6),
                _buildDot(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }

 Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask Posture AI...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                    // Override the global inputDecorationTheme which sets
                    // fillColor: AppColors.surfaceLight — that's the grey box
                    filled: true,
                    fillColor: AppColors.cardLight,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
