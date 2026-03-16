import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';
import '../../widgets/project_card.dart';
import '../../widgets/shimmer_card.dart';

const List<String> _roomCategories = [
  'Tümü',
  'Salon',
  'Mutfak',
  'Banyo',
  'Yatak Odası',
  'Çocuk Odası',
  'Ofis',
  'Koridor',
  'Bahçe',
];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedCategory = 'Tümü';
  List<DesignerProject> _projects = [];
  bool _loading = true;
  String? _error;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 20;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    try {
      var baseQuery = supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .eq('is_published', true);

      if (_selectedCategory != 'Tümü') {
        baseQuery = baseQuery.eq('project_type', _selectedCategory);
      }

      final data = await baseQuery
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
      final projects =
          (data as List).map((e) => DesignerProject.fromJson(e as Map<String, dynamic>)).toList();

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
      setState(() {
        _error = 'Projeler yüklenirken hata oluştu.';
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
    setState(() => _selectedCategory = category);
    _fetchProjects(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: SizedBox(
                  height: 52,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _roomCategories.length,
                    itemBuilder: (context, index) {
                      final category = _roomCategories[index];
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
                      _selectedCategory == 'Tümü'
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
    );
  }
}
