class Profile {
  final String id;
  final String? slug;
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
  final List<String> professionalTypes;
  final List<String> services;
  final List<String> projectTypes;
  final List<String> serviceAreas;
  final List<String> styleExpertise;
  final List<String> cities;
  final String? district;
  final List<String> serviceRegions;
  final String? startingBudget;
  final List<String> workingModels;
  final Map<String, dynamic> profileGeneral;
  final String? responseTime;
  final String? startingFrom;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.slug,
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
    this.professionalTypes = const [],
    this.services = const [],
    this.projectTypes = const [],
    this.serviceAreas = const [],
    this.styleExpertise = const [],
    this.cities = const [],
    this.district,
    this.serviceRegions = const [],
    this.startingBudget,
    this.workingModels = const [],
    this.profileGeneral = const {},
    this.responseTime,
    this.startingFrom,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final aboutDetails = _asMap(json['about_details']);
    final profileGeneral = _asMap(aboutDetails['profileGeneral']);
    final professionalTypes = _stringList(profileGeneral['professionalTypes']);
    final city = _firstString([
      profileGeneral['city'],
      json['city'],
    ]);
    final cities = _stringList(profileGeneral['cities']);
    final businessName = _firstString([
      profileGeneral['businessName'],
      json['business_name'],
    ]);
    final fullName = _firstString([
      profileGeneral['displayName'],
      json['full_name'],
    ]);
    final profileImageUrl = _firstString([
      profileGeneral['profileImageUrl'],
      json['avatar_url'],
    ]);
    final startingBudget = _firstString([
      profileGeneral['startingBudget'],
      json['starting_from'],
    ]);

    return Profile(
      id: json['id'] as String,
      slug: json['slug'] as String?,
      fullName: fullName,
      role: (json['role'] as String?) ?? 'homeowner',
      avatarUrl: profileImageUrl,
      businessName: businessName,
      specialty: professionalTypes.isNotEmpty
          ? professionalTypes.take(2).join(' • ')
          : json['specialty'] as String?,
      city: cities.isNotEmpty ? cities.first : city,
      about: json['about'] as String?,
      phone: json['phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      instagram: json['instagram'] as String?,
      facebook: json['facebook'] as String?,
      linkedin: json['linkedin'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      tags: _stringList(profileGeneral['tags']).isNotEmpty
          ? _stringList(profileGeneral['tags'])
          : _stringList(json['tags']),
      professionalTypes: professionalTypes,
      services: _stringList(profileGeneral['services']),
      projectTypes: _stringList(profileGeneral['projectTypes']),
      serviceAreas: _stringList(profileGeneral['serviceAreas']),
      styleExpertise: _stringList(profileGeneral['styleExpertise']),
      cities: cities.isNotEmpty
          ? cities
          : city != null
              ? [city]
              : const [],
      district: profileGeneral['district'] as String?,
      serviceRegions: _stringList(profileGeneral['serviceRegions']),
      startingBudget: startingBudget,
      workingModels: _stringList(profileGeneral['workingModels']),
      profileGeneral: profileGeneral,
      responseTime: json['response_time'] as String?,
      startingFrom: startingBudget,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
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
      'about_details': {
        'profileGeneral': profileGeneral,
      },
      'response_time': responseTime,
      'starting_from': startingFrom,
    };
  }

  String get displayName => fullName?.trim().isNotEmpty == true
      ? fullName!.trim()
      : businessName?.trim().isNotEmpty == true
          ? businessName!.trim()
          : 'Kullanıcı';

  bool get isDesigner => role == 'designer' || role == 'designer_pending';

  bool get isAdmin => role == 'admin' || role == 'super_admin';

  Profile copyWith({
    String? fullName,
    String? slug,
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
    List<String>? professionalTypes,
    List<String>? services,
    List<String>? projectTypes,
    List<String>? serviceAreas,
    List<String>? styleExpertise,
    List<String>? cities,
    String? district,
    List<String>? serviceRegions,
    String? startingBudget,
    List<String>? workingModels,
    Map<String, dynamic>? profileGeneral,
    String? responseTime,
    String? startingFrom,
  }) {
    return Profile(
      id: id,
      slug: slug ?? this.slug,
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
      professionalTypes: professionalTypes ?? this.professionalTypes,
      services: services ?? this.services,
      projectTypes: projectTypes ?? this.projectTypes,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      styleExpertise: styleExpertise ?? this.styleExpertise,
      cities: cities ?? this.cities,
      district: district ?? this.district,
      serviceRegions: serviceRegions ?? this.serviceRegions,
      startingBudget: startingBudget ?? this.startingBudget,
      workingModels: workingModels ?? this.workingModels,
      profileGeneral: profileGeneral ?? this.profileGeneral,
      responseTime: responseTime ?? this.responseTime,
      startingFrom: startingFrom ?? this.startingFrom,
      createdAt: createdAt,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _firstString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
