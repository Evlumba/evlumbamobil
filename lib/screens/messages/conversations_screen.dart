import '../../widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/conversation.dart';
import '../../widgets/shimmer_card.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Get conversations where user is homeowner or designer
      final homeownerConvs = await supabase
          .from('conversations')
          .select('id, homeowner_id, designer_id, created_at')
          .eq('homeowner_id', currentUser.id)
          .order('created_at', ascending: false);

      final designerConvs = await supabase
          .from('conversations')
          .select('id, homeowner_id, designer_id, created_at')
          .eq('designer_id', currentUser.id)
          .order('created_at', ascending: false);

      final allConvs = [
        ...(homeownerConvs as List),
        ...(designerConvs as List),
      ];

      final conversations = allConvs
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();

      // Fetch other party info for each conversation
      final enrichedConvs = await Future.wait(
        conversations.map((conv) async {
          final otherPartyId = conv.homeownerId == currentUser.id
              ? conv.designerId
              : conv.homeownerId;

          try {
            final profileData = await supabase
                .from('profiles')
                .select('id, full_name, avatar_url')
                .eq('id', otherPartyId)
                .maybeSingle();

            String? name;
            String? avatarUrl;
            if (profileData != null) {
              final p = profileData as Map<String, dynamic>;
              name = (p['full_name'] as String?)?.split(' ').first ?? 'Kullanıcı';
              avatarUrl = p['avatar_url'] as String?;
            }

            // Fetch last message
            final lastMsgData = await supabase
                .from('messages')
                .select('body, created_at')
                .eq('conversation_id', conv.id)
                .order('created_at', ascending: false)
                .limit(1);

            String? lastMsg;
            DateTime? lastMsgAt;
            if ((lastMsgData as List).isNotEmpty) {
              final msg = lastMsgData.first as Map<String, dynamic>;
              lastMsg = msg['body'] as String?;
              lastMsgAt = msg['created_at'] != null
                  ? DateTime.parse(msg['created_at'] as String)
                  : null;
            }

            // Count unread messages
            final unreadData = await supabase
                .from('messages')
                .select('id')
                .eq('conversation_id', conv.id)
                .neq('sender_id', currentUser.id)
                .isFilter('read_at', null);

            final unreadCount = (unreadData as List).length;

            return conv.copyWith(
              otherPartyName: name,
              otherPartyAvatarUrl: avatarUrl,
              lastMessage: lastMsg,
              lastMessageAt: lastMsgAt,
              unreadCount: unreadCount,
            );
          } catch (_) {
            return conv;
          }
        }),
      );

      // Sort by last message time
      enrichedConvs.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _conversations = enrichedConvs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Mesajlar yüklenirken hata oluştu.';
        _loading = false;
      });
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk';
    if (diff.inDays < 1) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mesajlar')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchConversations,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : _loading
          ? ListView.builder(
              itemCount: 6,
              itemBuilder: (_, __) => const ShimmerListItem(),
            )
          : _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz mesajınız yok.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bir tasarımcıya mesaj göndererek başlayın.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchConversations,
              child: ListView.separated(
                itemCount: _conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      clipBehavior: Clip.hardEdge,
                      child: conv.otherPartyAvatarUrl != null &&
                              conv.otherPartyAvatarUrl!.isNotEmpty
                          ? SmartImage(
                              url: conv.otherPartyAvatarUrl,
                              fit: BoxFit.cover,
                            )
                          : _AvatarPlaceholder(
                              name: conv.otherPartyName ?? 'K',
                            ),
                    ),
                    title: Text(
                      conv.otherPartyName ?? 'Kullanıcı',
                      style: TextStyle(
                        fontWeight: conv.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      conv.lastMessage ?? 'Konuşma başladı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: conv.unreadCount > 0
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: conv.unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(conv.lastMessageAt ?? conv.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: conv.unreadCount > 0
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (conv.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${conv.unreadCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () => context.push(
                      '/chat/${conv.id}?name=${Uri.encodeComponent(conv.otherPartyName ?? 'Kullanıcı')}',
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final String name;

  const _AvatarPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
