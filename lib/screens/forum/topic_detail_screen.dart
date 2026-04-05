import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/forum.dart';

String _formatDate(DateTime dt) {
  const months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class TopicDetailScreen extends StatefulWidget {
  final String topicId;

  const TopicDetailScreen({super.key, required this.topicId});

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  bool _loading = true;
  ForumTopic? _topic;
  List<ForumPost> _posts = [];

  String? _userId;
  ForumMember? _member;
  bool _canParticipate = false;

  ForumPost? _replyToPost;
  final _replyController = TextEditingController();
  bool _sendingReply = false;

  String? _editingPostId;
  final _editController = TextEditingController();
  bool _savingEdit = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
    });
    await Future.wait([_loadAuth(), _loadTopic(), _loadPosts()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAuth() async {
    final user = supabase.auth.currentUser;
    _userId = user?.id;
    if (_userId == null) return;

    final profileFuture = supabase
        .from('profiles')
        .select('role')
        .eq('id', _userId!)
        .maybeSingle();
    final memberFuture = supabase
        .from('forum_members')
        .select('user_id, lumba_name')
        .eq('user_id', _userId!)
        .maybeSingle();
    final adminFuture =
        supabase.rpc('get_admin_role', params: {'user_uuid': _userId!});

    final results = await Future.wait<dynamic>(
        [profileFuture, memberFuture, adminFuture]);

    final profile = results[0] as Map<String, dynamic>?;
    final memberData = results[1] as Map<String, dynamic>?;
    final adminRoleData = results[2];

    final role = profile?['role'] as String? ??
        user?.userMetadata?['role'] as String?;
    final adminRole =
        (adminRoleData == 'admin' || adminRoleData == 'super_admin')
            ? adminRoleData as String
            : null;
    _member = memberData != null ? ForumMember.fromJson(memberData) : null;

    final isProfessional = role == 'designer' || role == 'designer_pending';
    final isAdmin = adminRole == 'admin' || adminRole == 'super_admin';
    _canParticipate =
        _userId != null && _member != null && (isProfessional || isAdmin);
  }

  Future<void> _loadTopic() async {
    final data = await supabase
        .from('forum_topics')
        .select(
            'id, slug, title, is_pinned, starter_body, created_at, last_post_at')
        .eq('id', widget.topicId)
        .maybeSingle();

    _topic = data != null ? ForumTopic.fromJson(data) : null;
  }

  Future<void> _loadPosts() async {
    final data = await supabase
        .from('forum_posts')
        .select(
          'id, topic_id, author_id, parent_post_id, body, created_at, updated_at, '
          'author:forum_members!forum_posts_author_id_fkey(lumba_name)',
        )
        .eq('topic_id', widget.topicId)
        .order('created_at', ascending: true);

    final posts =
        (data as List).map((j) => ForumPost.fromJson(j)).toList();

    // Fetch admin roles for all unique authors
    final authorIds = posts.map((p) => p.authorId).toSet().toList();
    final adminRoles = await _fetchAdminRoles(authorIds);

    _posts = posts
        .map((p) => p.copyWith(authorAdminRole: adminRoles[p.authorId]))
        .toList();
  }

  Future<Map<String, String>> _fetchAdminRoles(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final results = <String, String>{};
      // Check profiles for admin roles
      final data = await supabase
          .from('profiles')
          .select('id, role')
          .inFilter('id', userIds);
      for (final row in (data as List)) {
        final role = row['role'] as String?;
        if (role == 'admin' || role == 'super_admin') {
          results[row['id'] as String] = role!;
        }
      }
      return results;
    } catch (_) {
      return {};
    }
  }

  Map<String, ForumPost> get _postsById {
    final map = <String, ForumPost>{};
    for (final p in _posts) {
      map[p.id] = p;
    }
    return map;
  }

  // ──────────── Reply ────────────
  Future<void> _sendReply() async {
    if (!_canParticipate) return;
    final body = _replyController.text.trim();
    if (body.isEmpty) return;

    final parentId = _replyToPost != null &&
            _replyToPost!.topicId == widget.topicId &&
            _postsById.containsKey(_replyToPost!.id)
        ? _replyToPost!.id
        : null;

    setState(() => _sendingReply = true);

    try {
      await supabase.from('forum_posts').insert({
        'topic_id': widget.topicId,
        'author_id': _userId!,
        'parent_post_id': parentId,
        'body': body,
      });

      _replyController.clear();
      _replyToPost = null;
      await _loadPosts();
      if (mounted) setState(() => _sendingReply = false);
    } catch (e) {
      if (mounted) {
        setState(() => _sendingReply = false);
        _showSnack('Yanıt gönderilemedi: $e');
      }
    }
  }

  // ──────────── Edit ────────────
  void _beginEdit(ForumPost post) {
    setState(() {
      _editingPostId = post.id;
      _editController.text = post.body;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingPostId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(ForumPost post) async {
    final body = _editController.text.trim();
    if (body.isEmpty) {
      _showSnack('Mesaj boş olamaz.');
      return;
    }

    setState(() => _savingEdit = true);

    try {
      await supabase
          .from('forum_posts')
          .update({'body': body})
          .eq('id', post.id)
          .eq('author_id', _userId!);

      _editingPostId = null;
      _editController.clear();
      await _loadPosts();
      if (mounted) {
        setState(() => _savingEdit = false);
        _showSnack('Mesaj güncellendi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingEdit = false);
        final msg = e.toString().toLowerCase();
        if (msg.contains('row-level security') || msg.contains('violates')) {
          _showSnack(
              'Düzenleme süresi doldu. Mesajlar yalnızca ilk 5 dakika içinde düzenlenebilir.');
        } else {
          _showSnack('Hata: $e');
        }
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ──────────── Build ────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/forum');
            }
          },
        ),
        title: Text(
          _topic?.title ?? 'Konu',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _topic == null
              ? const Center(child: Text('Konu bulunamadı.'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAll,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            // Topic info
                            Text(
                              '${_formatDate(_topic!.createdAt)} tarihinde açıldı',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                            // Starter body
                            if (_topic!.starterBody?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 12),
                              _StarterBodyCard(
                                  body: _topic!.starterBody!),
                            ],
                            const SizedBox(height: 16),
                            // Posts
                            if (_posts.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'Bu başlıkta henüz mesaj yok. İlk mesajı yazabilirsin.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ..._posts.map((post) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: _PostCard(
                                      post: post,
                                      parentPost:
                                          post.parentPostId != null
                                              ? _postsById[
                                                  post.parentPostId!]
                                              : null,
                                      isEditing:
                                          _editingPostId == post.id,
                                      editController: _editController,
                                      savingEdit: _savingEdit,
                                      canEdit:
                                          post.canEdit(_userId),
                                      canParticipate: _canParticipate,
                                      onReply: () => setState(
                                          () => _replyToPost = post),
                                      onBeginEdit: () =>
                                          _beginEdit(post),
                                      onCancelEdit: _cancelEdit,
                                      onSaveEdit: () =>
                                          _saveEdit(post),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ),
                    // Reply input
                    _ReplyBar(
                      canParticipate: _canParticipate,
                      replyToPost: _replyToPost,
                      controller: _replyController,
                      sending: _sendingReply,
                      onClearReply: () =>
                          setState(() => _replyToPost = null),
                      onSend: _sendReply,
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Starter body card
// ─────────────────────────────────────────────────────────────────────────────

class _StarterBodyCard extends StatelessWidget {
  final String body;

  const _StarterBodyCard({required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Evlumba',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sabit bilgilendirme',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RichBody(text: body),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post card
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final ForumPost post;
  final ForumPost? parentPost;
  final bool isEditing;
  final TextEditingController editController;
  final bool savingEdit;
  final bool canEdit;
  final bool canParticipate;
  final VoidCallback onReply;
  final VoidCallback onBeginEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;

  const _PostCard({
    required this.post,
    this.parentPost,
    required this.isEditing,
    required this.editController,
    required this.savingEdit,
    required this.canEdit,
    required this.canParticipate,
    required this.onReply,
    required this.onBeginEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = post.isAdmin;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: isAdmin
                      ? Border.all(color: const Color(0xFFBBF7D0))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.authorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAdmin
                            ? const Color(0xFF166534)
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          post.authorAdminRole == 'super_admin'
                              ? 'Super Admin'
                              : 'Admin',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(post.createdAt),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),

          // Parent reference
          if (parentPost != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '@${parentPost!.authorName} mesajına yanıt',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Body or edit field
          if (isEditing) ...[
            TextField(
              controller: editController,
              maxLines: 4,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: savingEdit ? null : onSaveEdit,
                  child: savingEdit
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Kaydet'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: savingEdit ? null : onCancelEdit,
                  child: const Text('İptal'),
                ),
              ],
            ),
          ] else
            _RichBody(text: post.body),

          // Action buttons
          if (!isEditing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (canEdit)
                  _SmallButton(
                    label: 'Düzenle',
                    onTap: onBeginEdit,
                  ),
                if (canEdit && canParticipate) const SizedBox(width: 8),
                if (canParticipate)
                  _SmallButton(
                    label: 'Yanıtla',
                    onTap: onReply,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reply bar
// ─────────────────────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  final bool canParticipate;
  final ForumPost? replyToPost;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onClearReply;
  final VoidCallback onSend;

  const _ReplyBar({
    required this.canParticipate,
    this.replyToPost,
    required this.controller,
    required this.sending,
    required this.onClearReply,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    if (!canParticipate) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Text(
          'Yazışmaya katılmak için foruma katılman gerekiyor.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyToPost != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '@${replyToPost!.authorName} mesajına yanıt yazıyorsun',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearReply,
                    child: Icon(Icons.close,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Mesajını yaz...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small action button
// ─────────────────────────────────────────────────────────────────────────────

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rich body renderer (**bold** support + newlines)
// ─────────────────────────────────────────────────────────────────────────────

class _RichBody extends StatelessWidget {
  final String text;

  const _RichBody({required this.text});

  @override
  Widget build(BuildContext context) {
    final segments = text.split(RegExp(r'(\*\*[^*]+\*\*)'));
    final spans = <InlineSpan>[];

    for (final seg in segments) {
      if (seg.startsWith('**') && seg.endsWith('**')) {
        spans.add(TextSpan(
          text: seg.substring(2, seg.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ));
      } else {
        spans.add(TextSpan(text: seg));
      }
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        children: spans,
      ),
    );
  }
}
