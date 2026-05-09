class SearchFilters {
  final List<String> rooms;
  final List<String> styles;
  final List<String> budgetLevels;
  final List<String> cities;
  final List<String> professionals;
  final List<String> services;
  final List<String> projectTypes;
  final List<String> serviceRegions;
  final bool onlyProfessionals;
  final bool onlyProjects;
  final bool hasProjects;
  final String sortBy;

  const SearchFilters({
    this.rooms = const [],
    this.styles = const [],
    this.budgetLevels = const [],
    this.cities = const [],
    this.professionals = const [],
    this.services = const [],
    this.projectTypes = const [],
    this.serviceRegions = const [],
    this.onlyProfessionals = false,
    this.onlyProjects = false,
    this.hasProjects = false,
    this.sortBy = '',
  });

  factory SearchFilters.fromQuery(Map<String, String> params) {
    return SearchFilters(
      rooms: _cleanList(params['room'] ?? params['area']),
      styles: _cleanList(params['style']),
      budgetLevels: _cleanList(params['budget']),
      cities: _cleanList(params['city']),
      professionals:
          _cleanList(params['professional'] ?? params['professionalType']),
      services: _cleanList(params['service']),
      projectTypes: _cleanList(params['project'] ?? params['projectType']),
      serviceRegions: _cleanList(params['serviceRegion']),
      onlyProfessionals: params['onlyProfessionals'] == '1',
      onlyProjects: params['onlyProjects'] == '1',
      hasProjects: params['hasProjects'] == '1',
      sortBy: _cleanSort(params['sort']),
    );
  }

  SearchFilters copyWith({
    List<String>? rooms,
    List<String>? styles,
    List<String>? budgetLevels,
    List<String>? cities,
    List<String>? professionals,
    List<String>? services,
    List<String>? projectTypes,
    List<String>? serviceRegions,
    bool? onlyProfessionals,
    bool? onlyProjects,
    bool? hasProjects,
    String? sortBy,
    bool clearRooms = false,
    bool clearStyles = false,
    bool clearBudgets = false,
    bool clearCities = false,
    bool clearProfessionals = false,
    bool clearServices = false,
    bool clearProjectTypes = false,
    bool clearServiceRegions = false,
    bool clearSort = false,
  }) {
    return SearchFilters(
      rooms: clearRooms ? const [] : _normalizeList(rooms ?? this.rooms),
      styles: clearStyles ? const [] : _normalizeList(styles ?? this.styles),
      budgetLevels: clearBudgets
          ? const []
          : _normalizeList(budgetLevels ?? this.budgetLevels),
      cities: clearCities ? const [] : _normalizeList(cities ?? this.cities),
      professionals: clearProfessionals
          ? const []
          : _normalizeList(professionals ?? this.professionals),
      services:
          clearServices ? const [] : _normalizeList(services ?? this.services),
      projectTypes: clearProjectTypes
          ? const []
          : _normalizeList(projectTypes ?? this.projectTypes),
      serviceRegions: clearServiceRegions
          ? const []
          : _normalizeList(serviceRegions ?? this.serviceRegions),
      onlyProfessionals: onlyProfessionals ?? this.onlyProfessionals,
      onlyProjects: onlyProjects ?? this.onlyProjects,
      hasProjects: hasProjects ?? this.hasProjects,
      sortBy: clearSort ? '' : _cleanSort(sortBy ?? this.sortBy),
    );
  }

  SearchFilters toggleValue(String key, String value) {
    return switch (key) {
      'room' => copyWith(rooms: _toggle(rooms, value)),
      'area' => copyWith(rooms: _toggle(rooms, value)),
      'style' => copyWith(styles: _toggle(styles, value)),
      'budget' => copyWith(budgetLevels: _toggle(budgetLevels, value)),
      'city' => copyWith(cities: _toggle(cities, value)),
      'professional' => copyWith(professionals: _toggle(professionals, value)),
      'professionalType' =>
        copyWith(professionals: _toggle(professionals, value)),
      'service' => copyWith(services: _toggle(services, value)),
      'project' => copyWith(projectTypes: _toggle(projectTypes, value)),
      'projectType' => copyWith(projectTypes: _toggle(projectTypes, value)),
      'serviceRegion' =>
        copyWith(serviceRegions: _toggle(serviceRegions, value)),
      _ => this,
    };
  }

  SearchFilters removeValue(String key, String value) {
    return switch (key) {
      'room' => copyWith(rooms: _remove(rooms, value)),
      'area' => copyWith(rooms: _remove(rooms, value)),
      'style' => copyWith(styles: _remove(styles, value)),
      'budget' => copyWith(budgetLevels: _remove(budgetLevels, value)),
      'city' => copyWith(cities: _remove(cities, value)),
      'professional' => copyWith(professionals: _remove(professionals, value)),
      'professionalType' =>
        copyWith(professionals: _remove(professionals, value)),
      'service' => copyWith(services: _remove(services, value)),
      'project' => copyWith(projectTypes: _remove(projectTypes, value)),
      'projectType' => copyWith(projectTypes: _remove(projectTypes, value)),
      'serviceRegion' =>
        copyWith(serviceRegions: _remove(serviceRegions, value)),
      'onlyProfessionals' => copyWith(onlyProfessionals: false),
      'onlyProjects' => copyWith(onlyProjects: false),
      'hasProjects' => copyWith(hasProjects: false),
      'sort' => copyWith(clearSort: true),
      _ => this,
    };
  }

  bool get hasAny =>
      rooms.isNotEmpty ||
      styles.isNotEmpty ||
      budgetLevels.isNotEmpty ||
      cities.isNotEmpty ||
      professionals.isNotEmpty ||
      services.isNotEmpty ||
      projectTypes.isNotEmpty ||
      serviceRegions.isNotEmpty ||
      onlyProfessionals ||
      onlyProjects ||
      hasProjects ||
      sortBy.isNotEmpty;

  bool get hasProjectFilters =>
      rooms.isNotEmpty ||
      styles.isNotEmpty ||
      budgetLevels.isNotEmpty ||
      cities.isNotEmpty ||
      onlyProjects ||
      sortBy.isNotEmpty;

  bool get hasProfessionalFilters =>
      cities.isNotEmpty ||
      professionals.isNotEmpty ||
      services.isNotEmpty ||
      projectTypes.isNotEmpty ||
      rooms.isNotEmpty ||
      serviceRegions.isNotEmpty ||
      hasProjects ||
      onlyProfessionals ||
      sortBy.isNotEmpty;

  bool get hasProfessionalSort =>
      sortBy == sortProjectCount || sortBy == sortRating;

  int get activeCount =>
      rooms.length +
      styles.length +
      budgetLevels.length +
      cities.length +
      professionals.length +
      services.length +
      projectTypes.length +
      serviceRegions.length +
      (onlyProfessionals ? 1 : 0) +
      (onlyProjects ? 1 : 0) +
      (hasProjects ? 1 : 0) +
      (sortBy.isNotEmpty ? 1 : 0);

  List<String> get budgetNames =>
      budgetLevels.map((level) => budgetLabels[level] ?? level).toList();

  String projectQueryText(String query) {
    return [query.trim(), ...styles]
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .trim();
  }

  String designerQueryText(String query) {
    return [query.trim(), ...professionals, ...services, ...projectTypes]
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .trim();
  }

  Map<String, String> projectParams(String query) {
    return _params(query: query, includeProfessional: false);
  }

  Map<String, String> designerParams(String query) {
    return _params(
      query: query,
      includeProjectFilters: false,
      includeStyleBudgetFilters: false,
    );
  }

  Map<String, String> _params({
    required String query,
    bool includeProjectFilters = true,
    bool includeProfessional = true,
    bool includeStyleBudgetFilters = true,
  }) {
    return {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (includeProjectFilters && rooms.isNotEmpty) 'room': _joinValues(rooms),
      if (includeStyleBudgetFilters && styles.isNotEmpty)
        'style': _joinValues(styles),
      if (includeStyleBudgetFilters && budgetLevels.isNotEmpty)
        'budget': _joinValues(budgetLevels),
      if (cities.isNotEmpty) 'city': _joinValues(cities),
      if (includeProfessional && professionals.isNotEmpty)
        'professionalType': _joinValues(professionals),
      if (includeProfessional && services.isNotEmpty)
        'service': _joinValues(services),
      if (includeProfessional && projectTypes.isNotEmpty)
        'project': _joinValues(projectTypes),
      if (includeProfessional && rooms.isNotEmpty) 'area': _joinValues(rooms),
      if (includeProfessional && serviceRegions.isNotEmpty)
        'serviceRegion': _joinValues(serviceRegions),
      if (onlyProfessionals) 'onlyProfessionals': '1',
      if (onlyProjects) 'onlyProjects': '1',
      if (includeProfessional && hasProjects) 'hasProjects': '1',
      if (sortBy.isNotEmpty) 'sort': sortBy,
    };
  }

  static String routeQuery(Map<String, String> params) {
    if (params.isEmpty) return '';
    return Uri(queryParameters: params).query;
  }

  static String? labelForBudget(String value) => budgetLabels[value];

  static String? labelForSort(String value) => sortLabels[value];

  static List<String> _cleanList(String? value) {
    if (value == null) return const [];
    return _normalizeList(value.split(','));
  }

  static String _cleanSort(String? value) {
    final sort = value?.trim() ?? '';
    return sortLabels.containsKey(sort) ? sort : '';
  }

  static List<String> _normalizeList(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      result.add(trimmed);
    }
    return List.unmodifiable(result);
  }

  static List<String> _toggle(List<String> values, String value) {
    return values.contains(value) ? _remove(values, value) : [...values, value];
  }

  static List<String> _remove(List<String> values, String value) {
    return values.where((item) => item != value).toList();
  }

  static String _joinValues(List<String> values) {
    return values.join(',');
  }

  static bool listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is SearchFilters &&
        listEquals(other.rooms, rooms) &&
        listEquals(other.styles, styles) &&
        listEquals(other.budgetLevels, budgetLevels) &&
        listEquals(other.cities, cities) &&
        listEquals(other.professionals, professionals) &&
        listEquals(other.services, services) &&
        listEquals(other.projectTypes, projectTypes) &&
        listEquals(other.serviceRegions, serviceRegions) &&
        other.onlyProfessionals == onlyProfessionals &&
        other.onlyProjects == onlyProjects &&
        other.hasProjects == hasProjects &&
        other.sortBy == sortBy;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(rooms),
        Object.hashAll(styles),
        Object.hashAll(budgetLevels),
        Object.hashAll(cities),
        Object.hashAll(professionals),
        Object.hashAll(services),
        Object.hashAll(projectTypes),
        Object.hashAll(serviceRegions),
        onlyProfessionals,
        onlyProjects,
        hasProjects,
        sortBy,
      );

  static const sortName = 'name';
  static const sortBudget = 'budget';
  static const sortProjectCount = 'project_count';
  static const sortRating = 'rating';
  static const sortDate = 'date';

  static const sortOptions = [
    sortName,
    sortBudget,
    sortProjectCount,
    sortRating,
  ];

  static const exploreSortOptions = [
    sortBudget,
    sortDate,
  ];

  static const designerSortOptions = [
    sortName,
    sortBudget,
    sortProjectCount,
    sortRating,
  ];

  static const sortLabels = {
    sortName: 'İsme göre',
    sortBudget: 'Bütçeye göre',
    sortProjectCount: 'Proje sayısına göre',
    sortRating: 'En yüksek puana göre',
    sortDate: 'Eklenme tarihine göre',
  };

  static int budgetRank(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return 999;

    const projectBudgetRanks = {
      'low': 0,
      'medium': 1,
      'high': 2,
      'pro': 3,
    };
    final projectRank = projectBudgetRanks[normalized];
    if (projectRank != null) return projectRank;

    for (var i = 0; i < startingBudgetOptions.length; i++) {
      if (startingBudgetOptions[i].toLowerCase() == normalized) return i;
    }
    if (normalized.contains('proje bazlı')) return 998;
    return 999;
  }

  static const roomOptions = [
    'Salon',
    'Oturma Odası',
    'Mutfak',
    'Banyo',
    'Yatak Odası',
    'Çocuk Odası',
    'Bebek Odası',
    'Giyinme Odası',
    'Antre / Hol',
    'Koridor',
    'Çalışma Odası',
    'Ev Ofis',
    'Çamaşır Odası',
    'Kiler / Depolama',
    'Bahçe',
    'Balkon',
    'Teras',
    'Veranda',
    'Havuz',
    'Dış Cephe',
    'Garaj / Otopark',
    'Kış Bahçesi',
    'Ofis',
    'Mağaza',
    'Kafe / Restoran',
    'Otel',
    'Klinik',
    'Güzellik Salonu',
    'Showroom',
    'Stüdyo',
  ];

  static const styleOptions = [
    'Modern',
    'Minimalist',
    'Klasik',
    'Lüks',
    'İskandinav',
    'Rustik',
    'Endüstriyel',
    'Bohem',
    'Akdeniz',
    'Japandi',
    'Country',
    'Retro',
    'Eklektik',
    'Çağdaş',
    'Doğal / Organik',
    'Sahil / Coastal',
    'Geleneksel',
  ];

  static const budgetLabels = {
    'low': 'Ekonomik',
    'medium': 'Orta',
    'high': 'Yüksek',
    'pro': 'Pro',
  };

  static const professionalOptions = [
    'Mimar',
    'İç Mimar',
    'İç Dekoratör',
    'Peyzaj Mimarı',
    'Tasarım Ofisi',
    'Mimarlık Firması',
    'İç Mimarlık Ofisi',
    'İç Mimarlık Bürosu',
    'Mimari Tasarımcı',
    'Konsept Tasarımcı',
    '3D Görselleştirme Uzmanı',
    'Mimari Maket Hizmeti',
    'Aydınlatma Tasarımcısı',
    'Tadilat Firması',
    'Ev Tadilatı Firması',
    'Anahtar Teslim Firma',
    'Banyo & Mutfak Uygulamacısı',
    'Usta / Uygulamacı',
    'Marangoz / Özel Mobilya',
    'Mobilya Üreticisi',
    'Mobilya İmalatçısı',
    'İnşaat Şirketi',
    'İnşaat Firması',
    'İnşaat Mühendisi',
    'İnşaat Danışmanı',
    'Yapı Denetçisi',
    'Peyzaj Uygulama Firması',
    'Mobilya Mağazası',
    'Mutfak Mobilyası Mağazası',
    'Yapı Malzemeleri Mağazası',
    'İnşaat Malzemesi Toptancısı',
    'Peyzaj Malzemeleri Satıcısı',
    'Malzeme / Ürün Tedarikçisi',
    'Alüminyum Pencere Sistemleri',
    'Kurumsal Ofis',
  ];

  static const serviceOptions = [
    'İç Mimari Tasarım',
    'Mimari Proje',
    'Dekorasyon Danışmanlığı',
    'Konsept Tasarım',
    '3D Render / Görselleştirme',
    'Moodboard Hazırlama',
    'Mobilya Yerleşim Planı',
    'Renk & Malzeme Danışmanlığı',
    'Aydınlatma Planı',
    'Mimari Maket',
    'Grafik Tasarım / Sunum Tasarımı',
    'Tadilat',
    'Renovasyon',
    'Anahtar Teslim Uygulama',
    'Mutfak Yenileme',
    'Banyo Yenileme',
    'Özel Mobilya Üretimi',
    'Mobilya Üretimi',
    'Mutfak Mobilyası Üretimi',
    'Marangozluk',
    'Boya / Duvar Uygulaması',
    'Zemin / Parke Uygulaması',
    'Seramik / Fayans Uygulaması',
    'Elektrik Uygulaması',
    'Tesisat Uygulaması',
    'Alüminyum Pencere Uygulaması',
    'Peyzaj Tasarımı',
    'Bahçe Düzenleme',
    'Balkon / Teras Tasarımı',
    'Dış Cephe Tasarımı',
    'Havuz Tasarımı',
    'Kış Bahçesi',
    'İnşaat Danışmanlığı',
    'Yapı Denetimi',
    'Teknik Proje Danışmanlığı',
    'Yapı Malzemesi Tedariği',
    'İnşaat Malzemesi Tedariği',
    'Peyzaj Malzemesi Tedariği',
    'Mobilya Satışı',
  ];

  static const projectTypeOptions = [
    'İç Mimari Proje',
    'Mimari Proje',
    'Dekorasyon',
    'Tadilat / Renovasyon',
    'Anahtar Teslim',
    'Mobilya Tasarımı',
    '3D Tasarım / Render',
    'Peyzaj / Bahçe',
    'Banyo Yenileme',
    'Mutfak Yenileme',
    'Ofis Tasarımı',
    'Mağaza / Ticari Alan Tasarımı',
    'Danışmanlık',
  ];

  static const serviceRegionOptions = [
    'Sadece bulunduğum şehir',
    'Bulunduğum şehir + çevre iller',
    'Türkiye geneli',
    'Online hizmet veriyorum',
    'Yurt dışı hizmet veriyorum',
  ];

  static const startingBudgetOptions = [
    '₺0 - ₺25.000',
    '₺25.000 - ₺50.000',
    '₺50.000 - ₺100.000',
    '₺100.000 - ₺250.000',
    '₺250.000 - ₺500.000',
    '₺500.000 - ₺1.000.000',
    '₺1.000.000+',
    'Proje bazlı değişir',
  ];

  static const cityOptions = [
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Amasya',
    'Ankara',
    'Antalya',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkari',
    'Hatay',
    'Isparta',
    'Mersin',
    'İstanbul',
    'İzmir',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırklareli',
    'Kırşehir',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Kahramanmaraş',
    'Mardin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Şanlıurfa',
    'Uşak',
    'Van',
    'Yozgat',
    'Zonguldak',
    'Aksaray',
    'Bayburt',
    'Karaman',
    'Kırıkkale',
    'Batman',
    'Şırnak',
    'Bartın',
    'Ardahan',
    'Iğdır',
    'Yalova',
    'Karabük',
    'Kilis',
    'Osmaniye',
    'Düzce',
  ];
}
