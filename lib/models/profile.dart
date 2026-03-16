class Profile {
  final String id;
  final String? fullName;
  final String role;
  final String? avatarUrl;
  final String? businessName;
  final String? specialty;
  final String? city;
  final String? about;
  final String? phone;
  final String? contactEmail;
  final String? address;
  final String? website;
  final String? instagram;
  final String? facebook;
  final String? linkedin;
  final String? coverPhotoUrl;
  final List<String> tags;
  final String? responseTime;
  final String? startingFrom;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.fullName,
    required this.role,
    this.avatarUrl,
    this.businessName,
    this.specialty,
    this.city,
    this.about,
    this.phone,
    this.contactEmail,
    this.address,
    this.website,
    this.instagram,
    this.facebook,
    this.linkedin,
    this.coverPhotoUrl,
    this.tags = const [],
    this.responseTime,
    this.startingFrom,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      role: (json['role'] as String?) ?? 'homeowner',
      avatarUrl: json['avatar_url'] as String?,
      businessName: json['business_name'] as String?,
      specialty: json['specialty'] as String?,
      city: json['city'] as String?,
      about: json['about'] as String?,
      phone: json['phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      instagram: json['instagram'] as String?,
      facebook: json['facebook'] as String?,
      linkedin: json['linkedin'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      responseTime: json['response_time'] as String?,
      startingFrom: json['starting_from'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'business_name': businessName,
      'specialty': specialty,
      'city': city,
      'about': about,
      'phone': phone,
      'contact_email': contactEmail,
      'address': address,
      'website': website,
      'instagram': instagram,
      'facebook': facebook,
      'linkedin': linkedin,
      'cover_photo_url': coverPhotoUrl,
      'tags': tags,
      'response_time': responseTime,
      'starting_from': startingFrom,
    };
  }

  String get displayName =>
      fullName?.trim().isNotEmpty == true
          ? fullName!.trim()
          : businessName?.trim().isNotEmpty == true
          ? businessName!.trim()
          : 'Kullanıcı';

  bool get isDesigner =>
      role == 'designer' || role == 'designer_pending';

  Profile copyWith({
    String? fullName,
    String? role,
    String? avatarUrl,
    String? businessName,
    String? specialty,
    String? city,
    String? about,
    String? phone,
    String? contactEmail,
    String? address,
    String? website,
    String? instagram,
    String? facebook,
    String? linkedin,
    String? coverPhotoUrl,
    List<String>? tags,
    String? responseTime,
    String? startingFrom,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      businessName: businessName ?? this.businessName,
      specialty: specialty ?? this.specialty,
      city: city ?? this.city,
      about: about ?? this.about,
      phone: phone ?? this.phone,
      contactEmail: contactEmail ?? this.contactEmail,
      address: address ?? this.address,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      linkedin: linkedin ?? this.linkedin,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      tags: tags ?? this.tags,
      responseTime: responseTime ?? this.responseTime,
      startingFrom: startingFrom ?? this.startingFrom,
      createdAt: createdAt,
    );
  }
}
