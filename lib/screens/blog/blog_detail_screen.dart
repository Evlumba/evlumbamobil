import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/blog.dart';
import '../../widgets/smart_image.dart';
import 'html_content_widget.dart';

String _formatDate(DateTime dt) {
  const months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class BlogDetailScreen extends StatefulWidget {
  final String slug;

  const BlogDetailScreen({super.key, required this.slug});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  bool _loading = true;
  BlogPost? _post;
  List<BlogComment> _comments = [];

  String? _userId;
  bool _liked = false;
  int _likeCount = 0;
  bool _likeLoading = false;

  final _commentController = TextEditingController();
  bool _commentSending = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _userId = supabase.auth.currentUser?.id;

    try {
      await _loadPost();
      if (_post != null) {
        await Future.wait([
          _loadCommentsForPost(_post!.id),
          if (_userId != null) _checkLiked(),
        ]);
      }
    } catch (e) {
      debugPrint('Blog loadAll error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPost() async {
    final data = await supabase
        .from('blog_posts')
        .select(
            'id, author_id, slug, title, excerpt, cover_image_url, content, status, published_at, created_at')
        .eq('slug', widget.slug)
        .maybeSingle();

    if (data == null) {
      _post = null;
      return;
    }

    _post = BlogPost.fromJson(data);

    // Fetch author profile + like count in parallel
    final profileFuture = supabase
        .from('profiles')
        .select('id, full_name, avatar_url, business_name')
        .eq('id', _post!.authorId)
        .maybeSingle();
    final likesFuture = supabase
        .from('blog_post_likes')
        .select('post_id')
        .eq('post_id', _post!.id);

    final results =
        await Future.wait<dynamic>([profileFuture, likesFuture]);

    final profile = results[0] as Map<String, dynamic>?;
    final likesData = results[1] as List;

    final name = (profile?['full_name'] as String?)?.trim() ??
        (profile?['business_name'] as String?)?.trim() ??
        'Profesyonel';
    final avatar = profile?['avatar_url'] as String?;

    _post = BlogPost(
      id: _post!.id,
      authorId: _post!.authorId,
      slug: _post!.slug,
      title: _post!.title,
      excerpt: _post!.excerpt,
      coverImageUrl: _post!.coverImageUrl,
      content: _post!.content,
      status: _post!.status,
      publishedAt: _post!.publishedAt,
      createdAt: _post!.createdAt,
      authorName: name,
      authorAvatarUrl: avatar,
    );
    _likeCount = likesData.length;
  }

  Future<void> _loadCommentsForPost(String postId) async {
    final data = await supabase
        .from('blog_post_comments')
        .select('id, post_id, user_id, body, created_at')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final rawComments =
        (data as List).map((j) => BlogComment.fromJson(j)).toList();

    // Fetch profiles for comment authors
    final userIds = rawComments.map((c) => c.userId).toSet().toList();
    if (userIds.isEmpty) {
      _comments = rawComments;
      return;
    }

    final profilesFuture = supabase
        .from('profiles')
        .select('id, full_name, avatar_url, business_name, role')
        .inFilter('id', userIds);

    final profiles = (await profilesFuture) as List;
    final profileMap = <String, Map<String, dynamic>>{};
    for (final p in profiles) {
      profileMap[p['id'] as String] = p;
    }

    _comments = rawComments.map((c) {
      final p = profileMap[c.userId];
      final name = (p?['full_name'] as String?)?.trim() ??
          (p?['business_name'] as String?)?.trim() ??
          'Kullanıcı';
      final avatar = p?['avatar_url'] as String?;
      final role = p?['role'] as String?;
      final adminRole =
          (role == 'admin' || role == 'super_admin') ? role : null;
      return c.withProfile(
        authorName: name,
        authorAvatarUrl: avatar,
        adminRole: adminRole,
      );
    }).toList();
  }

  Future<void> _checkLiked() async {
    if (_userId == null || _post == null) return;
    final data = await supabase
        .from('blog_post_likes')
        .select('post_id')
        .eq('post_id', _post!.id)
        .eq('user_id', _userId!)
        .maybeSingle();
    _liked = data != null;
  }

  // ──────────── Like toggle ────────────
  Future<void> _toggleLike() async {
    if (_userId == null) {
      context.push('/login');
      return;
    }
    if (_likeLoading || _post == null) return;

    setState(() => _likeLoading = true);

    try {
      if (_liked) {
        await supabase
            .from('blog_post_likes')
            .delete()
            .eq('post_id', _post!.id)
            .eq('user_id', _userId!);
        _liked = false;
        _likeCount = (_likeCount - 1).clamp(0, 999999);
      } else {
        await supabase.from('blog_post_likes').insert({
          'post_id': _post!.id,
          'user_id': _userId!,
        });
        _liked = true;
        _likeCount++;
      }
    } catch (e) {
      _showSnack('Hata: $e');
    }
    if (mounted) setState(() => _likeLoading = false);
  }

  // ──────────── Comment ────────────
  Future<void> _submitComment() async {
    if (_userId == null) {
      context.push('/login');
      return;
    }
    if (_commentSending || _post == null) return;
    final body = _commentController.text.trim();
    if (body.isEmpty) {
      _showSnack('Yorum boş olamaz.');
      return;
    }

    setState(() => _commentSending = true);

    try {
      await supabase.from('blog_post_comments').insert({
        'post_id': _post!.id,
        'user_id': _userId!,
        'body': body,
      });

      _commentController.clear();
      await _loadCommentsForPost(_post!.id);
      if (mounted) setState(() => _commentSending = false);
    } catch (e) {
      if (mounted) {
        setState(() => _commentSending = false);
        _showSnack('Hata: $e');
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
              context.go('/blog');
            }
          },
        ),
        title: Text(
          _post?.title ?? 'Blog',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('Yazı bulunamadı.'))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Cover image
                    if (_post!.coverImageUrl != null &&
                        _post!.coverImageUrl!.isNotEmpty)
                      SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: SmartImage(
                          url: _post!.coverImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            _post!.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          // Excerpt
                          if (_post!.excerpt?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              _post!.excerpt!,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Author bar
                          _AuthorBar(
                            post: _post!,
                            liked: _liked,
                            likeCount: _likeCount,
                            likeLoading: _likeLoading,
                            onToggleLike: _toggleLike,
                          ),
                          const SizedBox(height: 20),
                          // Content
                          if (_post!.content != null &&
                              _post!.content!.isNotEmpty)
                            HtmlContentWidget(html: _post!.content!),
                        ],
                      ),
                    ),

                    // Divider
                    const Divider(height: 1),

                    // Comments section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yorumlar (${_comments.length})',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          if (_comments.isEmpty)
                            Text(
                              'Henüz yorum yok. İlk yorumu sen bırak.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            )
                          else
                            ..._comments.map((c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CommentCard(comment: c),
                                )),
                          const SizedBox(height: 12),
                          // Comment input
                          TextField(
                            controller: _commentController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Yorumunu yaz...',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed:
                                  _commentSending ? null : _submitComment,
                              child: _commentSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Yorum Gönder'),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Author bar with like button
// ─────────────────────────────────────────────────────────────────────────────

class _AuthorBar extends StatelessWidget {
  final BlogPost post;
  final bool liked;
  final int likeCount;
  final bool likeLoading;
  final VoidCallback onToggleLike;

  const _AuthorBar({
    required this.post,
    required this.liked,
    required this.likeCount,
    required this.likeLoading,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              color: const Color(0xFFE2E8F0),
            ),
            clipBehavior: Clip.hardEdge,
            child: post.authorAvatarUrl != null &&
                    post.authorAvatarUrl!.isNotEmpty
                ? SmartImage(url: post.authorAvatarUrl, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      _initials(post.authorName),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
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
                  post.authorName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(post.publishedAt ?? post.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Like button
          GestureDetector(
            onTap: likeLoading ? null : onToggleLike,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: liked
                    ? const Color(0xFFFFF1F2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: liked
                      ? const Color(0xFFFDA4AF)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color:
                        liked ? const Color(0xFFE11D48) : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$likeCount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: liked
                          ? const Color(0xFFE11D48)
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comment card
// ─────────────────────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final BlogComment comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE2E8F0),
                ),
                clipBehavior: Clip.hardEdge,
                child: comment.authorAvatarUrl != null &&
                        comment.authorAvatarUrl!.isNotEmpty
                    ? SmartImage(
                        url: comment.authorAvatarUrl, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          _initials(comment.authorName),
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: comment.isAdmin
                              ? const Color(0xFF166534)
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          comment.adminRole == 'super_admin'
                              ? 'Super Admin'
                              : 'Admin',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _formatDate(comment.createdAt),
                style: TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.body,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();
  }
}
