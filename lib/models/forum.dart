class ForumMember {
  final String userId;
  final String lumbaName;

  const ForumMember({required this.userId, required this.lumbaName});

  factory ForumMember.fromJson(Map<String, dynamic> json) => ForumMember(
        userId: json['user_id'] as String,
        lumbaName: (json['lumba_name'] as String?) ?? '',
      );
}

class ForumTopic {
  final String id;
  final String slug;
  final String title;
  final bool isPinned;
  final String? starterBody;
  final DateTime createdAt;
  final DateTime lastPostAt;

  const ForumTopic({
    required this.id,
    required this.slug,
    required this.title,
    this.isPinned = false,
    this.starterBody,
    required this.createdAt,
    required this.lastPostAt,
  });

  factory ForumTopic.fromJson(Map<String, dynamic> json) => ForumTopic(
        id: json['id'] as String,
        slug: (json['slug'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        isPinned: (json['is_pinned'] as bool?) ?? false,
        starterBody: json['starter_body'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastPostAt: DateTime.parse(json['last_post_at'] as String),
      );
}

class ForumPost {
  final String id;
  final String topicId;
  final String authorId;
  final String? parentPostId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorName;
  final String? authorAdminRole;

  const ForumPost({
    required this.id,
    required this.topicId,
    required this.authorId,
    this.parentPostId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAdminRole,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    // author comes as relation: { lumba_name: ... } or [{ lumba_name: ... }]
    final authorRaw = json['author'];
    String authorName = 'Lumba';
    if (authorRaw is Map) {
      authorName = (authorRaw['lumba_name'] as String?)?.trim() ?? 'Lumba';
    } else if (authorRaw is List && authorRaw.isNotEmpty) {
      authorName =
          (authorRaw[0]['lumba_name'] as String?)?.trim() ?? 'Lumba';
    }

    return ForumPost(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      authorId: json['author_id'] as String,
      parentPostId: json['parent_post_id'] as String?,
      body: (json['body'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      authorName: authorName,
      authorAdminRole: null, // set separately
    );
  }

  ForumPost copyWith({String? authorAdminRole, String? body}) => ForumPost(
        id: id,
        topicId: topicId,
        authorId: authorId,
        parentPostId: parentPostId,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt,
        authorName: authorName,
        authorAdminRole: authorAdminRole ?? this.authorAdminRole,
      );

  bool get isAdmin =>
      authorAdminRole == 'admin' || authorAdminRole == 'super_admin';

  static const editWindowMs = 5 * 60 * 1000;

  bool canEdit(String? currentUserId) {
    if (currentUserId == null || authorId != currentUserId) return false;
    return DateTime.now().difference(createdAt).inMilliseconds <= editWindowMs;
  }
}
