import '../core/supabase_client.dart';

class SemanticSearchResult {
  final List<String> projectIds;
  final List<String> designerIds;

  const SemanticSearchResult({
    this.projectIds = const [],
    this.designerIds = const [],
  });

  factory SemanticSearchResult.fromJson(Map<String, dynamic> json) {
    return SemanticSearchResult(
      projectIds: (json['projectIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      designerIds: (json['designerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }
}

class SemanticSearchService {
  const SemanticSearchService._();

  static Future<SemanticSearchResult> searchProjects({
    required String query,
    List<String> projectTypes = const [],
    List<String> budgetLevels = const [],
    List<String> cities = const [],
    int limit = 24,
  }) {
    return _search(
      query: query,
      mode: 'projects',
      projectTypes: projectTypes,
      budgetLevels: budgetLevels,
      cities: cities,
      limit: limit,
    );
  }

  static Future<SemanticSearchResult> searchDesigners({
    required String query,
    List<String> professionalTypes = const [],
    List<String> services = const [],
    List<String> projectTypes = const [],
    List<String> serviceAreas = const [],
    List<String> cities = const [],
    List<String> serviceRegions = const [],
    bool hasProjects = false,
    int limit = 80,
  }) {
    return _search(
      query: query,
      mode: 'designers',
      professionalTypes: professionalTypes,
      services: services,
      projectTypes: projectTypes,
      serviceAreas: serviceAreas,
      cities: cities,
      serviceRegions: serviceRegions,
      hasProjects: hasProjects,
      limit: limit,
    );
  }

  static Future<SemanticSearchResult> _search({
    required String query,
    required String mode,
    List<String> projectTypes = const [],
    List<String> budgetLevels = const [],
    List<String> cities = const [],
    List<String> professionalTypes = const [],
    List<String> services = const [],
    List<String> serviceAreas = const [],
    List<String> serviceRegions = const [],
    bool hasProjects = false,
    required int limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const SemanticSearchResult();

    final response = await supabase.functions.invoke(
      'semantic-search',
      body: {
        'query': trimmed,
        'mode': mode,
        'limit': limit,
        if (projectTypes.length == 1) 'projectType': projectTypes.first.trim(),
        if (budgetLevels.length == 1) 'budgetLevel': budgetLevels.first.trim(),
        if (cities.length == 1) 'city': cities.first.trim(),
        if (professionalTypes.isNotEmpty)
          'professionalTypes': professionalTypes,
        if (services.isNotEmpty) 'services': services,
        if (projectTypes.isNotEmpty) 'projectTypes': projectTypes,
        if (serviceAreas.isNotEmpty) 'serviceAreas': serviceAreas,
        if (serviceRegions.isNotEmpty) 'serviceRegions': serviceRegions,
        if (hasProjects) 'hasProjects': true,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Semantic search response is invalid.');
    }

    final json = Map<String, dynamic>.from(data);
    if (json['ok'] != true) {
      throw Exception(json['message'] ?? 'Semantic search failed.');
    }

    return SemanticSearchResult.fromJson(json);
  }
}
