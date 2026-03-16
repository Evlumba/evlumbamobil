class Conversation {
  final String id;
  final String homeownerId;
  final String designerId;
  final DateTime createdAt;
  final String? otherPartyName;
  final String? otherPartyAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.homeownerId,
    required this.designerId,
    required this.createdAt,
    this.otherPartyName,
    this.otherPartyAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      homeownerId: (json['homeowner_id'] as String?) ?? '',
      designerId: (json['designer_id'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Conversation copyWith({
    String? otherPartyName,
    String? otherPartyAvatarUrl,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      homeownerId: homeownerId,
      designerId: designerId,
      createdAt: createdAt,
      otherPartyName: otherPartyName ?? this.otherPartyName,
      otherPartyAvatarUrl: otherPartyAvatarUrl ?? this.otherPartyAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
