import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/search_filters.dart';
import '../../services/search_intent_service.dart';
import '../../services/semantic_search_service.dart';
import '../../widgets/search_active_filter_chips.dart';
import '../../widgets/search_filter_sheet.dart';
import '../../widgets/designer_card.dart';
import '../../widgets/shimmer_card.dart';

class DesignersScreen extends StatefulWidget {
  final String? initialQuery;
  final SearchFilters initialFilters;

  const DesignersScreen({
    super.key,
    this.initialQuery,
    this.initialFilters = const SearchFilters(),
  });

  @override
  State<DesignersScreen> createState() => _DesignersScreenState();
}

class _DesignersScreenState extends State<DesignersScreen> {
  static const _searchHints = [
    'istanbul iç mimar...',
    'ankara boya ustası...',
    'elektrikçi...',
    'antalya mimar...',
    'mutfak yenileme yapan...',
    'banyo tadilat ustası...',
  ];

  List<_DesignerData> _designers = [];
  List<_DesignerData> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _placeholderTimer;
  String _animatedPlaceholder = '';
  int _placeholderHintIndex = 0;
  int _placeholderCharIndex = 0;
  bool _placeholderDeleting = false;
  int _searchRequestId = 0;
  List<String>? _semanticDesignerIds;
  bool _searching = false;
  bool _leaveConfirmed = false;

  SearchFilters _filters = const SearchFilters();

  int get _activeFilterCount => _filters.activeCount;
  int get _filterBadgeCount {
    final count = _activeFilterCount - (_filters.sortBy.isNotEmpty ? 1 : 0);
    return count < 0 ? 0 : count;
  }

  bool get _hasSearchQuery => _searchController.text.trim().isNotEmpty;
  bool get _shouldConfirmLeaving => _filters.hasAny || _hasSearchQuery;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }
    _filters = widget.initialFilters;
    _tickSearchPlaceholder();
    _fetchDesigners();
  }

  @override
  void didUpdateWidget(covariant DesignersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery?.trim() ?? '';
    final oldQuery = oldWidget.initialQuery?.trim() ?? '';
    if (nextQuery != oldQuery && nextQuery != _searchController.text.trim()) {
      _searchController.text = nextQuery;
    }
    final nextFilters = widget.initialFilters;
    if (nextFilters != _filters) {
      setState(() {
        _filters = nextFilters;
        _filtered = _filterDesigners(_designers);
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _placeholderTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _tickSearchPlaceholder() {
    final current = _searchHints[_placeholderHintIndex];
    if (mounted) {
      setState(() {
        _animatedPlaceholder = current.substring(0, _placeholderCharIndex);
      });
    }

    Duration delay;
    if (!_placeholderDeleting && _placeholderCharIndex < current.length) {
      _placeholderCharIndex++;
      delay = const Duration(milliseconds: 70);
    } else if (!_placeholderDeleting) {
      _placeholderDeleting = true;
      delay = const Duration(milliseconds: 1200);
    } else if (_placeholderCharIndex > 0) {
      _placeholderCharIndex--;
      delay = const Duration(milliseconds: 34);
    } else {
      _placeholderDeleting = false;
      _placeholderHintIndex = (_placeholderHintIndex + 1) % _searchHints.length;
      delay = const Duration(milliseconds: 260);
    }

    _placeholderTimer = Timer(delay, _tickSearchPlaceholder);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    final requestId = ++_searchRequestId;

    setState(() {
      _semanticDesignerIds = null;
      _searching = query.length >= 2;
      _filtered = _filterDesigners(_designers);
    });

    if (query.length < 2) {
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      _runSemanticDesignerSearch(query, requestId);
    });
  }

  Future<void> _runSemanticDesignerSearch(String query, int requestId) async {
    try {
      final result = await SemanticSearchService.searchDesigners(
        query: query,
        professionalTypes: _filters.professionals,
        services: _filters.services,
        projectTypes: _filters.projectTypes,
        serviceAreas: _filters.rooms,
        cities: _filters.cities,
        serviceRegions: _filters.serviceRegions,
        hasProjects: _filters.hasProjects,
        limit: 100,
      );

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _semanticDesignerIds = result.designerIds;
        _searching = false;
        _filtered = _filterDesigners(_designers);
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _semanticDesignerIds = null;
        _searching = false;
        _filtered = _filterDesigners(_designers);
      });
    }
  }

  List<_DesignerData> _filterDesigners(List<_DesignerData> designers) {
    final query = _searchController.text.trim().toLowerCase();
    final ordered = _applySearchOrder(designers, query);

    final filtered = ordered.where((d) {
      if (_filters.cities.isNotEmpty) {
        final cities = d.profile.cities.isNotEmpty
            ? d.profile.cities
            : [if ((d.profile.city ?? '').trim().isNotEmpty) d.profile.city!];
        if (!_filters.cities.any(cities.contains)) return false;
      }

      if (_filters.professionals.isNotEmpty &&
          !_filters.professionals.any(
            (professional) => _matchesProfessionalFilter(d, professional),
          )) {
        return false;
      }

      if (_filters.services.isNotEmpty &&
          !_filters.services.any(d.profile.services.contains)) {
        return false;
      }

      if (_filters.projectTypes.isNotEmpty &&
          !_filters.projectTypes.any(d.profile.projectTypes.contains)) {
        return false;
      }

      if (_filters.rooms.isNotEmpty &&
          !_filters.rooms.any(d.profile.serviceAreas.contains)) {
        return false;
      }

      if (_filters.serviceRegions.isNotEmpty &&
          !_filters.serviceRegions.any(d.profile.serviceRegions.contains)) {
        return false;
      }

      if (_filters.hasProjects && d.projectCount < 1) {
        return false;
      }

      return true;
    }).toList();

    return _applySelectedSort(filtered);
  }

  List<_DesignerData> _applySelectedSort(List<_DesignerData> designers) {
    if (_filters.sortBy.isEmpty) return designers;

    final sorted = List<_DesignerData>.from(designers);
    switch (_filters.sortBy) {
      case SearchFilters.sortName:
        sorted.sort((a, b) {
          final compare = a.profile.displayName
              .toLowerCase()
              .compareTo(b.profile.displayName.toLowerCase());
          if (compare != 0) return compare;
          return _compareDesignerDefault(a, b);
        });
        break;
      case SearchFilters.sortBudget:
        sorted.sort((a, b) {
          final compare = SearchFilters.budgetRank(
            a.profile.startingBudget ?? a.profile.startingFrom,
          ).compareTo(
            SearchFilters.budgetRank(
              b.profile.startingBudget ?? b.profile.startingFrom,
            ),
          );
          if (compare != 0) return compare;
          return a.profile.displayName
              .toLowerCase()
              .compareTo(b.profile.displayName.toLowerCase());
        });
        break;
      case SearchFilters.sortProjectCount:
        sorted.sort((a, b) {
          final compare = b.projectCount.compareTo(a.projectCount);
          if (compare != 0) return compare;
          return _compareDesignerDefault(a, b);
        });
        break;
      case SearchFilters.sortRating:
        sorted.sort((a, b) {
          final compare = b.rating.compareTo(a.rating);
          if (compare != 0) return compare;
          final reviewCompare = b.reviewCount.compareTo(a.reviewCount);
          if (reviewCompare != 0) return reviewCompare;
          return _compareDesignerDefault(a, b);
        });
        break;
    }
    return sorted;
  }

  int _compareDesignerDefault(_DesignerData a, _DesignerData b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.profile.displayName
        .toLowerCase()
        .compareTo(b.profile.displayName.toLowerCase());
  }

  List<_DesignerData> _applySearchOrder(
    List<_DesignerData> designers,
    String query,
  ) {
    if (query.isEmpty) return List<_DesignerData>.from(designers);

    final localMatches =
        designers.where((d) => _matchesProfileText(d, query)).toList()
          ..sort((a, b) {
            final scoreCompare = _profileSearchScore(b, query)
                .compareTo(_profileSearchScore(a, query));
            if (scoreCompare != 0) return scoreCompare;
            return b.score.compareTo(a.score);
          });

    final semanticIds = _semanticDesignerIds;
    if (semanticIds == null) {
      return localMatches;
    }

    final order = {
      for (var i = 0; i < semanticIds.length; i++) semanticIds[i]: i,
    };
    final localOrder = {
      for (var i = 0; i < localMatches.length; i++)
        localMatches[i].profile.id: i,
    };
    final matchedIds = {...order.keys, ...localOrder.keys};

    final result =
        designers.where((d) => matchedIds.contains(d.profile.id)).toList();

    result.sort((a, b) {
      final aLocalScore = _profileSearchScore(a, query);
      final bLocalScore = _profileSearchScore(b, query);
      if (aLocalScore != bLocalScore) {
        return bLocalScore.compareTo(aLocalScore);
      }

      final aOrder = order[a.profile.id] ??
          100000 + (localOrder[a.profile.id] ?? designers.indexOf(a));
      final bOrder = order[b.profile.id] ??
          100000 + (localOrder[b.profile.id] ?? designers.indexOf(b));
      final semanticCompare = aOrder.compareTo(bOrder);
      if (semanticCompare != 0) return semanticCompare;

      return b.score.compareTo(a.score);
    });

    return result;
  }

  bool _matchesProfileText(_DesignerData d, String query) {
    final normalizedQuery = SearchIntentService.normalize(query);
    final tokens = SearchIntentService.queryTokens(query);
    final profileText = _profileSearchText(d);

    if (profileText.contains(normalizedQuery)) return true;
    if (tokens.isEmpty) return true;
    return tokens.every(profileText.contains);
  }

  int _profileSearchScore(_DesignerData d, String query) {
    final tokens = SearchIntentService.queryTokens(query);
    if (tokens.isEmpty) return 0;

    final name = SearchIntentService.normalize(d.profile.displayName);
    final specialty = SearchIntentService.normalize(d.profile.specialty ?? '');
    final city = SearchIntentService.normalize(d.profile.city ?? '');
    final profileText = _profileSearchText(d);
    var score = 0;

    for (final token in tokens) {
      if (city.contains(token)) score += 8;
      if (specialty.contains(token)) score += 7;
      if (name.contains(token)) score += 5;
      if (profileText.contains(token)) score += 2;
    }

    return score;
  }

  bool _matchesProfessionalFilter(_DesignerData d, String professional) {
    final normalized = SearchIntentService.normalize(professional);
    if (normalized == 'mimar' || normalized == 'tasarimci') {
      return d.profile.isDesigner;
    }

    final tokens = SearchIntentService.queryTokens(professional);
    if (d.profile.professionalTypes.contains(professional)) return true;
    final specialtyText = SearchIntentService.normalize([
      d.profile.specialty ?? '',
      d.profile.about ?? '',
      d.profile.tags.join(' '),
      d.profile.professionalTypes.join(' '),
    ].join(' '));

    return tokens.every(specialtyText.contains);
  }

  String _profileSearchText(_DesignerData d) {
    final roleWords = d.profile.isDesigner
        ? 'mimar ic mimar tasarimci dekorator profesyonel uzman'
        : '';

    return SearchIntentService.normalize([
      d.profile.displayName,
      d.profile.businessName ?? '',
      d.profile.specialty ?? '',
      d.profile.city ?? '',
      d.profile.about ?? '',
      d.profile.tags.join(' '),
      d.profile.professionalTypes.join(' '),
      d.profile.services.join(' '),
      d.profile.projectTypes.join(' '),
      d.profile.serviceAreas.join(' '),
      d.profile.styleExpertise.join(' '),
      d.profile.serviceRegions.join(' '),
      roleWords,
    ].join(' '));
  }

  Future<void> _showFilterSheet({bool expandSort = false}) async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SearchFilterSheet(
        filters: _filters,
        mode: SearchFilterSheetMode.designers,
        expandSort: expandSort,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _filters = result;
      _filtered = _filterDesigners(_designers);
    });
  }

  Future<bool> _confirmFilterExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtreler temizlenecek'),
        content: const Text(
          'Bu sayfadan çıkarsanız uyguladığınız filtreler temizlenecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Evet, çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleFilteredPop() async {
    final confirmed = await _confirmFilterExit();
    if (!mounted || !confirmed) return;
    _searchDebounce?.cancel();
    _semanticDesignerIds = null;
    _searching = false;
    _searchController.clear();
    setState(() {
      _leaveConfirmed = true;
      _filters = const SearchFilters();
      _filtered = _filterDesigners(_designers);
    });
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _fetchDesigners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch profiles and ranking (aggregates + score) in parallel
      final results = await Future.wait([
        supabase
            .from('profiles')
            .select(
              'id, full_name, role, avatar_url, business_name, specialty, city, about, cover_photo_url, tags, starting_from, about_details, created_at',
            )
            .inFilter('role', ['designer', 'designer_pending']),
        supabase.rpc('get_ranked_designers', params: {
          'p_limit': 10000,
          'p_offset': 0,
        }),
      ]);

      final profiles = (results[0] as List)
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();

      final rankingMap = <String, Map<String, dynamic>>{};
      for (final row in (results[1] as List)) {
        final map = row as Map<String, dynamic>;
        final id = map['designer_id'] as String?;
        if (id != null) rankingMap[id] = map;
      }

      final designerDataList = profiles.map((profile) {
        final r = rankingMap[profile.id];
        if (r == null) return _DesignerData(profile: profile);
        return _DesignerData(
          profile: profile,
          rating: (r['avg_rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: (r['review_count'] as num?)?.toInt() ?? 0,
          projectCount: (r['project_count'] as num?)?.toInt() ?? 0,
          score: (r['score'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      if (mounted) {
        setState(() {
          _designers = designerDataList;
          _filtered = _filterDesigners(designerDataList);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Tasarımcılar yüklenirken hata oluştu.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_shouldConfirmLeaving || _leaveConfirmed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_shouldConfirmLeaving || _leaveConfirmed) return;
        _handleFilteredPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Tasarımcılar'),
          actions: [
            _DesignerAppBarAction(
              icon: Icons.sort_rounded,
              tooltip: 'Sırala',
              active: _filters.sortBy.isNotEmpty,
              onTap: () => _showFilterSheet(expandSort: true),
            ),
            _DesignerAppBarAction(
              icon: Icons.tune_rounded,
              tooltip: 'Filtrele',
              active: _filterBadgeCount > 0,
              badgeCount: _filterBadgeCount > 0 ? _filterBadgeCount : null,
              onTap: () => _showFilterSheet(),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _animatedPlaceholder.isEmpty
                      ? 'istanbul iç mimar...'
                      : _animatedPlaceholder,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
        ),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.textSecondary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchDesigners,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_filters.hasProfessionalFilters)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SearchActiveFilterChips(
                        filters: _filters,
                        includeProjectFilters: false,
                        onRemove: _removeFilter,
                      ),
                    ),
                  Expanded(
                    child: _loading
                        ? ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: 5,
                            itemBuilder: (_, __) => const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: ShimmerCard(height: 180),
                            ),
                          )
                        : _filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.people_outline,
                                      color: AppColors.textSecondary,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'Arama sonucu bulunamadı.'
                                          : 'Henüz tasarımcı yok.',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchDesigners,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final data = _filtered[index];
                                    return DesignerCard(
                                      designer: data.profile,
                                      rating: data.rating,
                                      reviewCount: data.reviewCount,
                                      projectCount: data.projectCount,
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
      ),
    );
  }

  void _removeFilter(String key, String value) {
    setState(() {
      _filters = _filters.removeValue(key, value);
      _filtered = _filterDesigners(_designers);
    });
  }
}

class _DesignerAppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final int? badgeCount;
  final VoidCallback onTap;

  const _DesignerAppBarAction({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(
            icon,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DesignerData {
  final Profile profile;
  final double rating;
  final int reviewCount;
  final int projectCount;
  final double score;

  _DesignerData({
    required this.profile,
    this.rating = 0,
    this.reviewCount = 0,
    this.projectCount = 0,
    this.score = 0,
  });
}
