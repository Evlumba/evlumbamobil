class DesignerReview {
  final String id;
  final String designerId;
  final String homeownerId;
  final String? projectId;
  final double rating;
  final double? workQualityRating;
  final double? communicationRating;
  final double? valueRating;
  final String reviewText;
  final String? replyText;
  final int helpfulCount;
  final bool isPinned;
  final DateTime createdAt;
  final String? reviewerName;

  const DesignerReview({
    required this.id,
    required this.designerId,
    required this.homeownerId,
    this.projectId,
    required this.rating,
    this.workQualityRating,
    this.communicationRating,
    this.valueRating,
    required this.reviewText,
    this.replyText,
    this.helpfulCount = 0,
    this.isPinned = false,
    required this.createdAt,
    this.reviewerName,
  });

  factory DesignerReview.fromJson(Map<String, dynamic> json) {
    return DesignerReview(
      id: json['id'] as String,
      designerId: (json['designer_id'] as String?) ?? '',
      homeownerId: (json['homeowner_id'] as String?) ?? '',
      projectId: json['project_id'] as String?,
      rating: ((json['rating'] as num?) ?? 0).toDouble(),
      workQualityRating:
          (json['work_quality_rating'] as num?)?.toDouble(),
      communicationRating:
          (json['communication_rating'] as num?)?.toDouble(),
      valueRating: (json['value_rating'] as num?)?.toDouble(),
      reviewText: (json['review_text'] as String?) ?? '',
      replyText: json['reply_text'] as String?,
      helpfulCount: (json['helpful_count'] as int?) ?? 0,
      isPinned: (json['is_pinned'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      reviewerName: json['reviewer_name'] as String?,
    );
  }

  String get formattedDate {
    final months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.year}';
  }
}
