import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/conversation.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/smart_image.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> _conversations = [];
  List<Conversation> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _conversations
          : _conversations
              .where((c) =>
                  (c.otherPartyName ?? '').toLowerCase().contains(q) ||
                  (c.lastMessage ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _fetchConversations() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) context.go('/login');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
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

      final enrichedConvs = await Future.wait(
        conversations.map((conv) async {
          final otherPartyId = conv.homeownerId == currentUser.id
              ? conv.designerId
              : conv.homeownerId;
          try {
            final profileData = await supabase
                .from('profiles')
                .select('id, full_name, avatar_url, specialty')
                .eq('id', otherPartyId)
                .maybeSingle();

            String? name;
            String? avatarUrl;
            String? specialty;
            if (profileData != null) {
              final p = profileData as Map<String, dynamic>;
              name = (p['full_name'] as String?)?.split(' ').first ?? 'Kullanıcı';
              avatarUrl = p['avatar_url'] as String?;
              specialty = p['specialty'] as String?;
            }

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

      enrichedConvs.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _conversations = enrichedConvs;
        _filtered = enrichedConvs;
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
    if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Evlumba',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.border,
                child: Icon(Icons.person, size: 18, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Mesajlar',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.chat_bubble_outline, color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text('Yeni Mesaj', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Mesaj veya kişi ara...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // List
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.textSecondary, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchConversations, child: const Text('Tekrar Dene')),
                      ],
                    ),
                  )
                : _loading
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: 5,
                        itemBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: ShimmerListItem(),
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
                                SizedBox(height: 16),
                                Text('Henüz mesajınız yok.', style: TextStyle(color: AppColors.textSecondary)),
                                SizedBox(height: 8),
                                Text(
                                  'Bir tasarımcıya mesaj göndererek başlayın.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchConversations,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final conv = _filtered[index];
                                return _ConversationCard(
                                  conv: conv,
                                  timeLabel: _formatTime(conv.lastMessageAt ?? conv.createdAt),
                                  onTap: () => context.push(
                                    '/chat/${conv.id}'
                                    '?name=${Uri.encodeComponent(conv.otherPartyName ?? 'Kullanıcı')}'
                                    '&avatar=${Uri.encodeComponent(conv.otherPartyAvatarUrl ?? '')}'
                                    '&userId=${Uri.encodeComponent(conv.designerId)}',
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final Conversation conv;
  final String timeLabel;
  final VoidCallback onTap;

  const _ConversationCard({required this.conv, required this.timeLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread ? AppColors.primary.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread ? AppColors.primary.withOpacity(0.15) : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.hardEdge,
              child: conv.otherPartyAvatarUrl != null && conv.otherPartyAvatarUrl!.isNotEmpty
                  ? SmartImage(url: conv.otherPartyAvatarUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: Center(
                        child: Text(
                          (conv.otherPartyName ?? 'K').substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 18),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.otherPartyName ?? 'Kullanıcı',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage ?? 'Konuşma başladı',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
