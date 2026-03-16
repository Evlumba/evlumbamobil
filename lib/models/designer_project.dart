class ProjectImage {
  final String imageUrl;
  final int sortOrder;

  const ProjectImage({required this.imageUrl, required this.sortOrder});

  factory ProjectImage.fromJson(Map<String, dynamic> json) {
    return ProjectImage(
      imageUrl: (json['image_url'] as String?) ?? '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }
}

class ShopLink {
  final String id;
  final String imageUrl;
  final double posX;
  final double posY;
  final String productUrl;
  final String? productTitle;
  final String? productImageUrl;
  final String? productPrice;

  const ShopLink({
    required this.id,
    required this.imageUrl,
    required this.posX,
    required this.posY,
    required this.productUrl,
    this.productTitle,
    this.productImageUrl,
    this.productPrice,
  });

  factory ShopLink.fromJson(Map<String, dynamic> json) {
    return ShopLink(
      id: json['id'] as String,
      imageUrl: (json['image_url'] as String?) ?? '',
      posX: ((json['pos_x'] as num?) ?? 50).toDouble(),
      posY: ((json['pos_y'] as num?) ?? 50).toDouble(),
      productUrl: (json['product_url'] as String?) ?? '',
      productTitle: json['product_title'] as String?,
      productImageUrl: json['product_image_url'] as String?,
      productPrice: json['product_price'] as String?,
    );
  }
}

class DesignerProject {
  final String id;
  final String designerId;
  final String title;
  final String? projectType;
  final String? location;
  final String? description;
  final List<String> tags;
  final String? budgetLevel;
  final String? coverImageUrl;
  final bool isPublished;
  final DateTime createdAt;
  final List<ProjectImage> images;
  final List<ShopLink> shopLinks;

  const DesignerProject({
    required this.id,
    required this.designerId,
    required this.title,
    this.projectType,
    this.location,
    this.description,
    this.tags = const [],
    this.budgetLevel,
    this.coverImageUrl,
    this.isPublished = false,
    required this.createdAt,
    this.images = const [],
    this.shopLinks = const [],
  });

  factory DesignerProject.fromJson(Map<String, dynamic> json) {
    final imageList = (json['designer_project_images'] as List<dynamic>?)
            ?.map((e) => ProjectImage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    imageList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final shopLinkList =
        (json['designer_project_shop_links'] as List<dynamic>?)
            ?.map((e) => ShopLink.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return DesignerProject(
      id: json['id'] as String,
      designerId: (json['designer_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      projectType: json['project_type'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      budgetLevel: json['budget_level'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isPublished: (json['is_published'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      images: imageList,
      shopLinks: shopLinkList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'designer_id': designerId,
      'title': title,
      'project_type': projectType,
      'location': location,
      'description': description,
      'tags': tags,
      'budget_level': budgetLevel,
      'cover_image_url': coverImageUrl,
      'is_published': isPublished,
    };
  }

  String get displayCoverUrl {
    if (images.isNotEmpty && images.first.imageUrl.isNotEmpty) {
      return images.first.imageUrl;
    }
    return coverImageUrl ?? '';
  }

  String get budgetLabel {
    switch (budgetLevel) {
      case 'low':
        return '₺';
      case 'medium':
        return '₺₺';
      case 'high':
        return '₺₺₺';
      case 'pro':
        return 'Pro';
      default:
        return '';
    }
  }

  DesignerProject copyWith({
    String? title,
    String? projectType,
    String? location,
    String? description,
    List<String>? tags,
    String? budgetLevel,
    String? coverImageUrl,
    bool? isPublished,
  }) {
    return DesignerProject(
      id: id,
      designerId: designerId,
      title: title ?? this.title,
      projectType: projectType ?? this.projectType,
      location: location ?? this.location,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      budgetLevel: budgetLevel ?? this.budgetLevel,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt,
      images: images,
      shopLinks: shopLinks,
    );
  }
}
