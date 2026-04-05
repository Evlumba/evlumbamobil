class BlogPost {
  final String id;
  final String authorId;
  final String slug;
  final String title;
  final String? excerpt;
  final String? coverImageUrl;
  final String? content;
  final String status;
  final DateTime? publishedAt;
  final DateTime createdAt;

  // Joined author info
  final String authorName;
  final String? authorAvatarUrl;

  // Aggregated counts
  final int likeCount;
  final int commentCount;

  const BlogPost({
    required this.id,
    required this.authorId,
    required this.slug,
    required this.title,
    this.excerpt,
    this.coverImageUrl,
    this.content,
    this.status = 'published',
    this.publishedAt,
    required this.createdAt,
    this.authorName = 'Profesyonel',
    this.authorAvatarUrl,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    // Author comes as relation: { full_name, avatar_url, business_name }
    final authorRaw = json['author'];
    String authorName = 'Profesyonel';
    String? authorAvatarUrl;
    if (authorRaw is Map) {
      authorName = (authorRaw['full_name'] as String?)?.trim() ??
          (authorRaw['business_name'] as String?)?.trim() ??
          'Profesyonel';
      authorAvatarUrl = authorRaw['avatar_url'] as String?;
    } else if (authorRaw is List && authorRaw.isNotEmpty) {
      final a = authorRaw[0] as Map;
      authorName = (a['full_name'] as String?)?.trim() ??
          (a['business_name'] as String?)?.trim() ??
          'Profesyonel';
      authorAvatarUrl = a['avatar_url'] as String?;
    }

    return BlogPost(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      excerpt: json['excerpt'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      content: json['content'] as String?,
      status: (json['status'] as String?) ?? 'published',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
    );
  }

  BlogPost copyWith({int? likeCount, int? commentCount}) => BlogPost(
        id: id,
        authorId: authorId,
        slug: slug,
        title: title,
        excerpt: excerpt,
        coverImageUrl: coverImageUrl,
        content: content,
        status: status,
        publishedAt: publishedAt,
        createdAt: createdAt,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
      );
}

class BlogComment {
  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;

  // Joined
  final String authorName;
  final String? authorAvatarUrl;
  final String? adminRole;

  const BlogComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.authorName = 'Kullanıcı',
    this.authorAvatarUrl,
    this.adminRole,
  });

  factory BlogComment.fromJson(Map<String, dynamic> json) => BlogComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        body: (json['body'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  BlogComment withProfile({
    String? authorName,
    String? authorAvatarUrl,
    String? adminRole,
  }) =>
      BlogComment(
        id: id,
        postId: postId,
        userId: userId,
        body: body,
        createdAt: createdAt,
        authorName: authorName ?? this.authorName,
        authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
        adminRole: adminRole ?? this.adminRole,
      );

  bool get isAdmin => adminRole == 'admin' || adminRole == 'super_admin';
}
