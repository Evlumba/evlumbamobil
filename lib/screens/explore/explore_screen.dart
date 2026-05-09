import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';
import '../../services/search_filters.dart';
import '../../services/semantic_search_service.dart';
import '../../widgets/search_active_filter_chips.dart';
import '../../widgets/search_filter_sheet.dart';
import '../../widgets/project_card.dart';
import '../../widgets/shimmer_card.dart';

const List<String> _roomCategories = [
  'Tümü',
  'Oturma Odası',
  'Mutfak',
  'Banyo',
  'Yatak Odası',
  'Çocuk Odası',
  'Ofis',
  'Antre',
  'Bahçe',
];

class ExploreScreen extends StatefulWidget {
  final String? initialQuery;
  final SearchFilters initialFilters;

  const ExploreScreen({
    super.key,
    this.initialQuery,
    this.initialFilters = const SearchFilters(),
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _searchHints = [
    'mutfak yenileme...',
    'modern banyo...',
    'küçük salon çözümü...',
    'istanbul mutfak...',
    'minimalist yatak odası...',
    'bahçe peyzaj...',
  ];

  String _selectedCategory = 'Tümü';
  List<DesignerProject> _projects = [];
  bool _loading = true;
  String? _error;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 20;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _placeholderTimer;
  String _animatedPlaceholder = '';
  int _placeholderHintIndex = 0;
  int _placeholderCharIndex = 0;
  bool _placeholderDeleting = false;
  int _searchRequestId = 0;
  bool _leaveConfirmed = false;
  Set<String> _nonEmptyCategories = {};
  late SearchFilters _filters;
  String get _searchQuery => _searchController.text.trim();
  String get _effectiveSearchQuery => _filters.projectQueryText(_searchQuery);
  int get _activeFilterCount => _filters.activeCount;
  int get _filterBadgeCount {
    final count = _activeFilterCount - (_filters.sortBy.isNotEmpty ? 1 : 0);
    return count < 0 ? 0 : count;
  }

  bool get _shouldConfirmLeaving => _filters.hasAny || _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }
    _filters = widget.initialFilters.copyWith(clearProfessionals: true);
    if (_filters.rooms.length == 1) {
      _selectedCategory = _filters.rooms.first;
    }
    _searchController.addListener(_onSearchChanged);
    _tickSearchPlaceholder();
    _fetchCategoryCounts();
    _fetchProjects();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery?.trim() ?? '';
    final oldQuery = oldWidget.initialQuery?.trim() ?? '';
    if (nextQuery != oldQuery && nextQuery != _searchController.text.trim()) {
      _searchController.text = nextQuery;
    }
    final nextFilters =
        widget.initialFilters.copyWith(clearProfessionals: true);
    if (nextFilters != _filters) {
      _filters = nextFilters;
      _selectedCategory =
          _filters.rooms.length == 1 ? _filters.rooms.first : 'Tümü';
      _fetchProjects(refresh: true);
    }
  }

  Future<void> _fetchCategoryCounts() async {
    try {
      final data = await supabase
          .from('designer_projects')
          .select('project_type')
          .eq('is_published', true);
      final types = (data as List)
          .map((e) => (e as Map<String, dynamic>)['project_type'] as String?)
          .whereType<String>()
          .toSet();
      if (mounted) setState(() => _nonEmptyCategories = types);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _placeholderTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      _fetchProjects(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _fetchMore();
    }
  }

  Future<void> _fetchProjects({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 0;
        _projects = [];
        _hasMore = true;
      });
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final requestId = ++_searchRequestId;
    try {
      final effectiveQuery = _effectiveSearchQuery;
      if (effectiveQuery.isNotEmpty) {
        await _fetchSemanticProjects(
          query: effectiveQuery,
          requestId: requestId,
        );
        return;
      }

      var baseQuery = supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .eq('is_published', true);

      if (_filters.rooms.isNotEmpty) {
        baseQuery = baseQuery.inFilter('project_type', _filters.rooms);
      }
      if (_filters.budgetLevels.isNotEmpty) {
        baseQuery = baseQuery.inFilter('budget_level', _filters.budgetLevels);
      }
      if (_filters.cities.isNotEmpty) {
        baseQuery = baseQuery.or(_cityLocationFilter(_filters.cities));
      }

      final data = await baseQuery
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
      final projects = _applySelectedSort((data as List)
          .map((e) => DesignerProject.fromJson(e as Map<String, dynamic>))
          .toList());

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        if (_page == 0) {
          _projects = projects;
        } else {
          _projects.addAll(projects);
        }
        _hasMore = projects.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _error = 'Projeler yüklenirken hata oluştu.';
        _loading = false;
      });
    }
  }

  Future<void> _fetchSemanticProjects({
    required String query,
    required int requestId,
  }) async {
    final requestedCount = (_page + 1) * _pageSize;
    final hasDbFilters = _filters.rooms.isNotEmpty ||
        _filters.budgetLevels.isNotEmpty ||
        _filters.cities.isNotEmpty;
    final searchLimit = hasDbFilters ? requestedCount * 4 : requestedCount;

    try {
      final result = await SemanticSearchService.searchProjects(
        query: query,
        projectTypes: _filters.rooms,
        budgetLevels: _filters.budgetLevels,
        cities: _filters.cities,
        limit: searchLimit,
      );

      if (!mounted || requestId != _searchRequestId) return;

      final candidateIds = result.projectIds;
      if (candidateIds.isEmpty) {
        setState(() {
          if (_page == 0) _projects = [];
          _hasMore = false;
          _loading = false;
        });
        return;
      }

      var queryBuilder = supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .inFilter('id', candidateIds)
          .eq('is_published', true);
      if (_filters.rooms.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('project_type', _filters.rooms);
      }
      if (_filters.budgetLevels.isNotEmpty) {
        queryBuilder =
            queryBuilder.inFilter('budget_level', _filters.budgetLevels);
      }
      if (_filters.cities.isNotEmpty) {
        queryBuilder = queryBuilder.or(_cityLocationFilter(_filters.cities));
      }

      final data = await queryBuilder;

      if (!mounted || requestId != _searchRequestId) return;

      final projectById = {
        for (final item in data as List)
          (item as Map<String, dynamic>)['id'] as String:
              DesignerProject.fromJson(item),
      };
      final orderedProjects = _applySelectedSort(candidateIds
          .map((id) => projectById[id])
          .whereType<DesignerProject>()
          .toList());
      final projects =
          orderedProjects.skip(_page * _pageSize).take(_pageSize).toList();

      setState(() {
        if (_page == 0) {
          _projects = projects;
        } else {
          _projects.addAll(projects);
        }
        _hasMore = orderedProjects.length > (_page + 1) * _pageSize ||
            candidateIds.length == searchLimit;
        _loading = false;
      });
    } catch (_) {
      await _fetchKeywordProjects(query: query, requestId: requestId);
    }
  }

  Future<void> _fetchKeywordProjects({
    required String query,
    required int requestId,
  }) async {
    try {
      var baseQuery = supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .eq('is_published', true);

      if (_filters.rooms.isNotEmpty) {
        baseQuery = baseQuery.inFilter('project_type', _filters.rooms);
      }
      if (_filters.budgetLevels.isNotEmpty) {
        baseQuery = baseQuery.inFilter('budget_level', _filters.budgetLevels);
      }
      if (_filters.cities.isNotEmpty) {
        baseQuery = baseQuery.or(_cityLocationFilter(_filters.cities));
      }

      final safeQuery = query.replaceAll(',', ' ').trim();
      final data = await baseQuery
          .or(
            'title.ilike.%$safeQuery%,project_type.ilike.%$safeQuery%,location.ilike.%$safeQuery%,description.ilike.%$safeQuery%',
          )
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      if (!mounted || requestId != _searchRequestId) return;

      final projects = _applySelectedSort((data as List)
          .map((e) => DesignerProject.fromJson(e as Map<String, dynamic>))
          .toList());

      setState(() {
        if (_page == 0) {
          _projects = projects;
        } else {
          _projects.addAll(projects);
        }
        _hasMore = projects.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _error = 'Arama yapılırken hata oluştu.';
        _loading = false;
      });
    }
  }

  Future<void> _fetchMore() async {
    if (_loading || !_hasMore) return;
    _page++;
    await _fetchProjects();
  }

  void _onCategoryChanged(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _filters = category == 'Tümü'
          ? _filters.copyWith(clearRooms: true)
          : _filters.copyWith(rooms: [category]);
    });
    _fetchProjects(refresh: true);
  }

  void _removeFilter(String key, String value) {
    setState(() {
      _filters = _filters.removeValue(key, value);
      _selectedCategory =
          _filters.rooms.length == 1 ? _filters.rooms.first : 'Tümü';
    });
    _fetchProjects(refresh: true);
  }

  Future<void> _showExploreFilterSheet({bool expandSort = false}) async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SearchFilterSheet(
        filters: _filters,
        mode: SearchFilterSheetMode.explore,
        expandSort: expandSort,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _filters = result.copyWith(clearProfessionals: true);
      _selectedCategory =
          _filters.rooms.length == 1 ? _filters.rooms.first : 'Tümü';
    });
    _fetchProjects(refresh: true);
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
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _leaveConfirmed = true;
      _filters = const SearchFilters();
      _selectedCategory = 'Tümü';
    });
    _fetchProjects(refresh: true);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  String _cityLocationFilter(List<String> cities) {
    return cities.map((city) => 'location.ilike.%${city.trim()}%').join(',');
  }

  List<DesignerProject> _applySelectedSort(List<DesignerProject> projects) {
    if (_filters.sortBy.isEmpty ||
        _filters.sortBy == SearchFilters.sortProjectCount ||
        _filters.sortBy == SearchFilters.sortRating) {
      return projects;
    }

    final sorted = List<DesignerProject>.from(projects);
    switch (_filters.sortBy) {
      case SearchFilters.sortName:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            ));
        break;
      case SearchFilters.sortBudget:
        sorted.sort((a, b) {
          final compare = SearchFilters.budgetRank(a.budgetLevel).compareTo(
            SearchFilters.budgetRank(b.budgetLevel),
          );
          if (compare != 0) return compare;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SearchFilters.sortDate:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  List<String> get _visibleCategories => _roomCategories
      .where((c) => c == 'Tümü' || _nonEmptyCategories.contains(c))
      .toList();

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
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text('Keşfet'),
              actions: [
                _ExploreAppBarAction(
                  icon: Icons.sort_rounded,
                  tooltip: 'Sırala',
                  active: _filters.sortBy.isNotEmpty,
                  onTap: () => _showExploreFilterSheet(expandSort: true),
                ),
                _ExploreAppBarAction(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filtrele',
                  active: _filterBadgeCount > 0,
                  badgeCount: _filterBadgeCount > 0 ? _filterBadgeCount : null,
                  onTap: () => _showExploreFilterSheet(),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: _animatedPlaceholder.isEmpty
                                  ? 'mutfak yenileme...'
                                  : _animatedPlaceholder,
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () =>
                                          _searchController.clear(),
                                      tooltip: 'Temizle',
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
                      SizedBox(
                        height: 52,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _visibleCategories.length,
                          itemBuilder: (context, index) {
                            final category = _visibleCategories[index];
                            final isSelected = _selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _onCategoryChanged(category),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_filters.hasProjectFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SearchActiveFilterChips(
                    filters: _filters,
                    includeProfessionalFilters: false,
                    onRemove: _removeFilter,
                  ),
                ),
              ),
            if (_error != null)
              SliverFillRemaining(
                child: Center(
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
                        onPressed: () => _fetchProjects(refresh: true),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loading && _projects.isEmpty)
              const SliverToBoxAdapter(child: ShimmerProjectGrid())
            else if (_projects.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.image_search_outlined,
                        color: AppColors.textSecondary,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Arama sonucu bulunamadı.'
                            : _selectedCategory == 'Tümü'
                                ? 'Henüz proje yok.'
                                : '$_selectedCategory için proje bulunamadı.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _projects.length) {
                        return _loading
                            ? const ShimmerCard()
                            : const SizedBox.shrink();
                      }
                      return ProjectCard(project: _projects[index]);
                    },
                    childCount: _projects.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExploreAppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final int? badgeCount;
  final VoidCallback onTap;

  const _ExploreAppBarAction({
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
