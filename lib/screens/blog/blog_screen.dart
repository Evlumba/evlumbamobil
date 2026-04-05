import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/blog.dart';
import '../../widgets/smart_image.dart';

String _formatDate(DateTime dt) {
  const months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  bool _loading = true;
  List<BlogPost> _posts = [];
  String _search = '';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _userId = supabase.auth.currentUser?.id;
    await _loadPosts();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPosts() async {
    try {
      final data = await supabase
          .from('blog_posts')
          .select(
              'id, author_id, slug, title, excerpt, cover_image_url, status, published_at, created_at')
          .eq('status', 'published')
          .order('published_at', ascending: false)
          .limit(50);

      var posts =
          (data as List).map((j) => BlogPost.fromJson(j)).toList();

      if (posts.isEmpty) {
        _posts = posts;
        return;
      }

      final authorIds = posts.map((p) => p.authorId).toSet().toList();

      // Fetch author profiles
      final profiles = await supabase
          .from('profiles')
          .select('id, full_name, avatar_url, business_name')
          .inFilter('id', authorIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in (profiles as List)) {
        profileMap[p['id'] as String] = p;
      }

      // Merge author info into posts (skip like/comment counts on list for speed)
      _posts = posts.map((p) {
        final profile = profileMap[p.authorId];
        final name = (profile?['full_name'] as String?)?.trim() ??
            (profile?['business_name'] as String?)?.trim() ??
            'Profesyonel';
        final avatar = profile?['avatar_url'] as String?;
        return BlogPost(
          id: p.id,
          authorId: p.authorId,
          slug: p.slug,
          title: p.title,
          excerpt: p.excerpt,
          coverImageUrl: p.coverImageUrl,
          status: p.status,
          publishedAt: p.publishedAt,
          createdAt: p.createdAt,
          authorName: name,
          authorAvatarUrl: avatar,
        );
      }).toList();
    } catch (e) {
      debugPrint('_loadPosts error: $e');
      _posts = [];
    }
  }

  List<BlogPost> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _posts;
    return _posts.where((p) {
      final haystack = '${p.title} ${p.excerpt ?? ''}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Blog yazılarında ara...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Text(
                      'Profesyonellerin paylaştığı yazılar.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  // Post list
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _search.isNotEmpty
                                  ? 'Aramanıza uygun yazı bulunamadı.'
                                  : 'Henüz blog yazısı yok.',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (_, i) => _BlogCard(
                              post: _filtered[i],
                              userId: _userId,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blog post card
// ─────────────────────────────────────────────────────────────────────────────

class _BlogCard extends StatelessWidget {
  final BlogPost post;
  final String? userId;

  const _BlogCard({required this.post, this.userId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/blog/${post.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (post.coverImageUrl != null &&
                post.coverImageUrl!.isNotEmpty)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: SmartImage(
                  url: post.coverImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                color: const Color(0xFFF1F5F9),
                child: const Center(
                  child: Icon(Icons.article_outlined,
                      size: 36, color: AppColors.textSecondary),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.excerpt != null &&
                      post.excerpt!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Author row + stats
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                          color: const Color(0xFFF1F5F9),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: post.authorAvatarUrl != null &&
                                post.authorAvatarUrl!.isNotEmpty
                            ? SmartImage(
                                url: post.authorAvatarUrl,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Text(
                                  _initials(post.authorName),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.authorName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Date
                      Text(
                        _formatDate(post.publishedAt ?? post.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Like + comment counts
                  Row(
                    children: [
                      Icon(Icons.favorite_border,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${post.likeCount}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(width: 14),
                      Icon(Icons.chat_bubble_outline,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${post.commentCount}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();
  }
}
