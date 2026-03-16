import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../widgets/designer_card.dart';
import '../../widgets/shimmer_card.dart';

class DesignersScreen extends StatefulWidget {
  const DesignersScreen({super.key});

  @override
  State<DesignersScreen> createState() => _DesignersScreenState();
}

class _DesignersScreenState extends State<DesignersScreen> {
  List<_DesignerData> _designers = [];
  List<_DesignerData> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDesigners();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = _designers);
      return;
    }
    setState(() {
      _filtered = _designers.where((d) {
        final name = d.profile.displayName.toLowerCase();
        final specialty = (d.profile.specialty ?? '').toLowerCase();
        final city = (d.profile.city ?? '').toLowerCase();
        return name.contains(query) ||
            specialty.contains(query) ||
            city.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchDesigners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profilesData = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, about, cover_photo_url, tags, starting_from, created_at',
          )
          .inFilter('role', ['designer', 'designer_pending'])
          .order('created_at', ascending: false);

      final profiles = (profilesData as List)
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();

      // Fetch review counts and project counts in parallel
      final designerDataList = await Future.wait(
        profiles.map((profile) async {
          try {
            final reviewsResult = await supabase
                .from('designer_reviews')
                .select('id, rating')
                .eq('designer_id', profile.id);

            final reviews = reviewsResult as List;
            final reviewCount = reviews.length;
            final avgRating = reviewCount > 0
                ? reviews
                        .map((r) =>
                            (r as Map<String, dynamic>)['rating'] as num? ?? 0)
                        .reduce((a, b) => a + b) /
                    reviewCount
                : 0.0;

            final projectsResult = await supabase
                .from('designer_projects')
                .select('id')
                .eq('designer_id', profile.id)
                .eq('is_published', true);

            final projectCount = (projectsResult as List).length;

            return _DesignerData(
              profile: profile,
              rating: avgRating.toDouble(),
              reviewCount: reviewCount,
              projectCount: projectCount as int,
            );
          } catch (_) {
            return _DesignerData(profile: profile);
          }
        }),
      );

      setState(() {
        _designers = designerDataList;
        _filtered = designerDataList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Tasarımcılar yüklenirken hata oluştu.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tasarımcılar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'İsim, uzmanlık veya şehir ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
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
          : _loading
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
                    style: const TextStyle(color: AppColors.textSecondary),
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
    );
  }
}

class _DesignerData {
  final Profile profile;
  final double rating;
  final int reviewCount;
  final int projectCount;

  _DesignerData({
    required this.profile,
    this.rating = 0,
    this.reviewCount = 0,
    this.projectCount = 0,
  });
}
