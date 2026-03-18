import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/message.dart';
import '../../widgets/smart_image.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherPartyName;
  final String? otherPartyAvatarUrl;
  final String? otherPartySpecialty;
  final String? otherPartyId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherPartyName,
    this.otherPartyAvatarUrl,
    this.otherPartySpecialty,
    this.otherPartyId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('messages')
          .select('id, conversation_id, sender_id, body, read_at, created_at')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);
      setState(() {
        _messages = (data as List).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    _subscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: true)
        .listen((data) {
          setState(() => _messages = data.map((e) => Message.fromJson(e)).toList());
          _scrollToBottom();
          _markMessagesAsRead();
        });
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    try {
      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', widget.conversationId)
          .neq('sender_id', currentUser.id)
          .isFilter('read_at', null);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) return;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      await supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': currentUser.id,
        'body': body,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj gönderilemedi.')),
        );
        _messageController.text = body;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (msgDay == today) return 'Bugün $timeStr';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Dün $timeStr';
    return '${date.day}/${date.month} $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Henüz mesaj yok. Merhaba deyin!',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == currentUserId;
                          final showDate = index == 0 ||
                              _messages[index].createdAt
                                      .difference(_messages[index - 1].createdAt)
                                      .inMinutes >
                                  30;
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    _formatDate(message.createdAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              _MessageBubble(message: message, isMe: isMe),
                            ],
                          );
                        },
                      ),
          ),
          _MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            isSending: _sending,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final avatarUrl = widget.otherPartyAvatarUrl;
    final specialty = widget.otherPartySpecialty;
    final designerId = widget.otherPartyId;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 40,
      leading: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 28),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.hardEdge,
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? SmartImage(url: avatarUrl, fit: BoxFit.cover)
                : Container(
                    color: AppColors.primary.withOpacity(0.1),
                    child: Center(
                      child: Text(
                        widget.otherPartyName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 18),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherPartyName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (specialty != null && specialty.isNotEmpty)
                  Text(
                    specialty,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                  ),
                if (designerId != null && designerId.isNotEmpty)
                  GestureDetector(
                    onTap: () => context.push('/designers/$designerId'),
                    child: const Text(
                      'Profilini Gör',
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_outlined, color: AppColors.textPrimary),
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textSecondary,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 12,
                    color: message.isRead ? Colors.white : Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    message.isRead ? 'Okundu' : '',
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message input bar ─────────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Attachment
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.add, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Bir mesaj yaz...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSending ? AppColors.primary.withOpacity(0.5) : AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Gönder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 6),

          // Mic
          const Icon(Icons.mic_none_outlined, color: AppColors.textSecondary, size: 24),
        ],
      ),
    );
  }
}
