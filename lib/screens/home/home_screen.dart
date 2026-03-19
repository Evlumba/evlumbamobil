import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';
import '../../models/profile.dart';
import '../../widgets/smart_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inline preview models (home screen only)
// ─────────────────────────────────────────────────────────────────────────────

class _ListingPreview {
  final String id, title, city;
  final bool isUrgent;
  final int? budgetMin, budgetMax;
  final List<String> neededProfessions;

  const _ListingPreview({
    required this.id,
    required this.title,
    required this.city,
    this.isUrgent = false,
    this.budgetMin,
    this.budgetMax,
    this.neededProfessions = const [],
  });

  factory _ListingPreview.fromJson(Map<String, dynamic> j) {
    final profs = (j['needed_professions'] as List<dynamic>?)?.cast<String>() ?? [];
    return _ListingPreview(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      city: (j['city'] as String?) ?? '',
      isUrgent: (j['is_urgent'] as bool?) ?? false,
      budgetMin: (j['budget_min'] as num?)?.toInt(),
      budgetMax: (j['budget_max'] as num?)?.toInt(),
      neededProfessions: profs,
    );
  }
}

class _BlogPreview {
  final String id, slug, title;
  final String? excerpt, coverImageUrl, authorName, authorAvatarUrl;

  const _BlogPreview({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.coverImageUrl,
    this.authorName,
    this.authorAvatarUrl,
  });

  factory _BlogPreview.fromJson(Map<String, dynamic> j) {
    return _BlogPreview(
      id: j['id'] as String,
      slug: (j['slug'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      excerpt: j['excerpt'] as String?,
      coverImageUrl: j['cover_image_url'] as String?,
    );
  }
}

class _ForumPreview {
  final String id, slug, title;
  final String? starterBody;

  const _ForumPreview({required this.id, required this.slug, required this.title, this.starterBody});

  factory _ForumPreview.fromJson(Map<String, dynamic> j) {
    return _ForumPreview(
      id: j['id'] as String,
      slug: (j['slug'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      starterBody: j['starter_body'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DesignerProject> _projects = [];
  List<Profile> _designers = [];
  List<_ListingPreview> _listings = [];
  List<_BlogPreview> _blogs = [];
  List<_ForumPreview> _forums = [];

  bool _loadingProjects = true;
  bool _loadingDesigners = true;
  bool _loadingListings = true;
  bool _loadingBlogs = true;
  bool _loadingForums = true;

  String? _banner1Url;
  String? _banner2Url;

  bool get _isLoggedIn => supabase.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    _fetchProjects();
    _fetchDesigners();
    _fetchListings();
    _fetchBlogs();
    _fetchForums();
  }

  Future<void> _fetchBanners() async {
    try {
      final data = await supabase.from('app_banners').select('slot, image_url');
      for (final row in (data as List)) {
        final slot = row['slot'] as int?;
        final url = row['image_url'] as String?;
        if (url != null && url.isNotEmpty) {
          if (slot == 1 && mounted) setState(() => _banner1Url = url);
          if (slot == 2 && mounted) setState(() => _banner2Url = url);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchProjects() async {
    try {
      final data = await supabase
          .from('designer_projects')
          .select('id, designer_id, title, project_type, cover_image_url, budget_level, tags, is_published, created_at, designer_project_images(image_url, sort_order)')
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(12);

      final projects = (data as List)
          .map((e) => DesignerProject.fromJson(e as Map<String, dynamic>))
          .toList();

      // Fetch designer names separately
      final designerIds = projects.map((p) => p.designerId).where((id) => id.isNotEmpty).toSet().toList();
      Map<String, String> nameMap = {};
      if (designerIds.isNotEmpty) {
        try {
          final profiles = await supabase
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', designerIds);
          for (final p in (profiles as List)) {
            final id = p['id'] as String?;
            final name = p['full_name'] as String?;
            if (id != null && name != null) nameMap[id] = name;
          }
        } catch (_) {}
      }

      // Attach designer names via copyWith is not available — build enriched list
      final enriched = projects.map((p) {
        final name = nameMap[p.designerId];
        if (name == null) return p;
        return DesignerProject(
          id: p.id, designerId: p.designerId, title: p.title, projectType: p.projectType,
          location: p.location, description: p.description, tags: p.tags, budgetLevel: p.budgetLevel,
          coverImageUrl: p.coverImageUrl, isPublished: p.isPublished, createdAt: p.createdAt,
          images: p.images, shopLinks: p.shopLinks, designerName: name,
        );
      }).toList();

      enriched.shuffle();
      if (mounted) setState(() { _projects = enriched.take(6).toList(); _loadingProjects = false; });
    } catch (e) {
      debugPrint('_fetchProjects error: $e');
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _fetchDesigners() async {
    try {
      // Only fetch profiles that have an avatar photo
      final data = await supabase
          .from('profiles')
          .select('id, full_name, business_name, avatar_url, specialty, city, cover_photo_url, tags, starting_from')
          .eq('role', 'designer')
          .not('avatar_url', 'is', null)
          .neq('avatar_url', '')
          .limit(80);

      final profiles = (data as List).map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
      if (profiles.isEmpty) {
        if (mounted) setState(() => _loadingDesigners = false);
        return;
      }

      // Fetch published project counts for these designers
      final ids = profiles.map((p) => p.id).toList();
      final projectData = await supabase
          .from('designer_projects')
          .select('designer_id')
          .inFilter('designer_id', ids)
          .eq('is_published', true);

      final designerIdsWithProjects = (projectData as List)
          .map((e) => e['designer_id'] as String)
          .toSet();

      // Keep only designers with ≥1 project
      final qualified = profiles.where((p) => designerIdsWithProjects.contains(p.id)).toList();
      qualified.shuffle();

      if (mounted) setState(() { _designers = qualified.take(6).toList(); _loadingDesigners = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingDesigners = false);
    }
  }

  Future<void> _fetchListings() async {
    try {
      final data = await supabase
          .from('listings')
          .select('id, title, city, is_urgent, budget_min, budget_max, needed_professions, status')
          .eq('status', 'published')
          .order('is_urgent', ascending: false)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _listings = (data as List).map((e) => _ListingPreview.fromJson(e as Map<String, dynamic>)).toList();
          _loadingListings = false;
        });
      }
    } catch (e) {
      debugPrint('_fetchListings error: $e');
      if (mounted) setState(() => _loadingListings = false);
    }
  }

  Future<void> _fetchBlogs() async {
    try {
      final data = await supabase
          .from('blog_posts')
          .select('id, author_id, slug, title, excerpt, cover_image_url, published_at')
          .eq('status', 'published')
          .order('published_at', ascending: false)
          .limit(2);

      final posts = (data as List).cast<Map<String, dynamic>>();

      // Fetch author profiles separately
      final authorIds = posts.map((p) => p['author_id'] as String?).whereType<String>().toSet().toList();
      Map<String, Map<String, dynamic>> authorMap = {};
      if (authorIds.isNotEmpty) {
        try {
          final profiles = await supabase.from('profiles').select('id, full_name, avatar_url').inFilter('id', authorIds);
          for (final p in (profiles as List)) {
            final id = p['id'] as String?;
            if (id != null) authorMap[id] = p as Map<String, dynamic>;
          }
        } catch (_) {}
      }

      final blogs = posts.map((p) {
        final authorId = p['author_id'] as String?;
        final profile = authorId != null ? authorMap[authorId] : null;
        return _BlogPreview(
          id: p['id'] as String,
          slug: (p['slug'] as String?) ?? '',
          title: (p['title'] as String?) ?? '',
          excerpt: p['excerpt'] as String?,
          coverImageUrl: p['cover_image_url'] as String?,
          authorName: profile?['full_name'] as String?,
          authorAvatarUrl: profile?['avatar_url'] as String?,
        );
      }).toList();

      if (mounted) setState(() { _blogs = blogs; _loadingBlogs = false; });
    } catch (e) {
      debugPrint('_fetchBlogs error: $e');
      if (mounted) setState(() => _loadingBlogs = false);
    }
  }

  Future<void> _fetchForums() async {
    try {
      final data = await supabase
          .from('forum_topics')
          .select('id, slug, title, starter_body, last_post_at')
          .order('last_post_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _forums = (data as List).map((e) => _ForumPreview.fromJson(e as Map<String, dynamic>)).toList();
          _loadingForums = false;
        });
      }
    } catch (e) {
      debugPrint('_fetchForums error: $e');
      if (mounted) setState(() => _loadingForums = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSearchBar()),
          if (_banner1Url != null) SliverToBoxAdapter(child: _buildHeroBanner()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildIlhamAl()),
          SliverToBoxAdapter(child: _buildProfessionals()),
          if (_banner2Url != null) SliverToBoxAdapter(child: _buildSecondBanner()),
          SliverToBoxAdapter(child: _buildIlanlar()),
          SliverToBoxAdapter(child: _buildBlog()),
          SliverToBoxAdapter(child: _buildForum()),
          SliverToBoxAdapter(child: _buildFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 60,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
      title: Row(
        children: [
          Image.asset('assets/web_icon2.png', width: 32, height: 32, fit: BoxFit.contain),
          const SizedBox(width: 8),
          const Text('evlumba', style: TextStyle(color: Color(0xFF0E5A3A), fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          _AppBarIcon(icon: Icons.notifications_none_rounded, onTap: () {}),
          const SizedBox(width: 6),
          _AppBarIcon(icon: Icons.chat_bubble_outline_rounded, onTap: () => context.go('/messages')),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _isLoggedIn ? context.go('/profile') : context.go('/login'),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5), color: AppColors.background),
              child: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GestureDetector(
        onTap: () => context.go('/explore'),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Proje, ürün, mimar ara...', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFF0F0EC), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.tune_rounded, size: 15, color: AppColors.textSecondary),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Hero Banner ──────────────────────────────────────────────

  Widget _buildHeroBanner() {
    return _FullWidthBanner(imageUrl: _banner1Url!, topPadding: 16);
  }

  // ── Quick Actions ────────────────────────────────────────────

  Widget _buildQuickActions() {
    final items = [
      (Icons.forum_outlined, 'Forum', () => context.go('/forum')),
      (Icons.auto_awesome_outlined, 'AI Tasarla', () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çok yakında!'), duration: Duration(seconds: 1)));
      }),
      (Icons.article_outlined, 'Blog', () => context.go('/blog')),
      (Icons.work_outline_rounded, 'İlanlar', () => context.go('/ilanlar')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: items[i].$3,
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(items[i].$1, size: 24, color: const Color(0xFF0E5A3A)),
                    const SizedBox(height: 5),
                    Text(items[i].$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
            ),
            if (i < items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // ── İlham Al ─────────────────────────────────────────────────

  Widget _buildIlhamAl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('İlham', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Text('✦', style: TextStyle(fontSize: 12, color: Color(0xFF0E5A3A))),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF0E5A3A), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tümünü gör', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 15, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _loadingProjects
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: 4,
                  itemBuilder: (_, __) => const SizedBox(width: 150, child: _SkeletonBox(height: 200)),
                )
              : _projects.isEmpty
                  ? const Center(child: Text('Henüz proje yok', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: _projects.length,
                      itemBuilder: (context, i) => SizedBox(
                        width: 150,
                        child: _DiscoverCard(
                          project: _projects[i],
                          height: 200,
                          onTap: () {
                            if (!_isLoggedIn) { context.go('/login'); return; }
                            context.push('/projects/${_projects[i].id}');
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  // ── Profesyoneller ────────────────────────────────────────────

  Widget _buildProfessionals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Profesyoneller', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Text('✦', style: TextStyle(fontSize: 12, color: Color(0xFF0E5A3A))),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/designers-list'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF0E5A3A), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tümünü gör', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 15, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: _loadingDesigners
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemCount: 5,
                  itemBuilder: (_, __) => const _SkeletonAvatar(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemCount: _designers.length,
                  itemBuilder: (context, i) {
                    final d = _designers[i];
                    return _DesignerChip(designer: d, onTap: () {
                      if (!_isLoggedIn) { context.go('/login'); return; }
                      context.push('/designers/${d.id}');
                    });
                  },
                ),
        ),
      ],
    );
  }

  // ── Second Banner ─────────────────────────────────────────────

  Widget _buildSecondBanner() {
    return _FullWidthBanner(imageUrl: _banner2Url!, topPadding: 28);
  }

  // ── İlanlar ───────────────────────────────────────────────────

  Widget _buildIlanlar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('İlanlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/ilanlar'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF0E5A3A), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tümünü gör', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 15, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_loadingListings)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: List.generate(2, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _SkeletonBox(height: 70)))),
          )
        else if (_listings.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Aktif ilan yok.', style: TextStyle(color: AppColors.textSecondary)))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _listings.map((l) => GestureDetector(
                onTap: () => context.go('/ilanlar'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: const Color(0xFF0E5A3A).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.work_outline_rounded, color: Color(0xFF0E5A3A), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (l.isUrgent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Acil', style: TextStyle(fontSize: 9, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(child: Text(l.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(l.city, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        if (l.budgetMin != null) ...[
                          const SizedBox(width: 8),
                          Text('₺${l.budgetMin} – ₺${l.budgetMax ?? '?'}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ]),
                    ])),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  // ── Blog ──────────────────────────────────────────────────────

  Widget _buildBlog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Blog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/blog'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF0E5A3A), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tümünü gör', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 15, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_loadingBlogs)
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const SizedBox(width: 240, child: _SkeletonBox(height: 280)),
            ),
          )
        else if (_blogs.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Henüz blog yazısı yok.', style: TextStyle(color: AppColors.textSecondary)))
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _blogs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final b = _blogs[i];
                return GestureDetector(
                  onTap: () => context.go('/blog'),
                  child: SizedBox(
                    width: 240,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (b.coverImageUrl != null && b.coverImageUrl!.isNotEmpty)
                          SizedBox(
                            height: 130,
                            width: double.infinity,
                            child: SmartImage(url: b.coverImageUrl, fit: BoxFit.cover, width: double.infinity),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (b.excerpt != null && b.excerpt!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(b.excerpt!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                                clipBehavior: Clip.hardEdge,
                                child: b.authorAvatarUrl != null && b.authorAvatarUrl!.isNotEmpty
                                    ? SmartImage(url: b.authorAvatarUrl, fit: BoxFit.cover)
                                    : Container(color: const Color(0xFF0E5A3A).withOpacity(0.1),
                                        child: Center(child: Text((b.authorName ?? 'P').substring(0, 1).toUpperCase(),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0E5A3A))))),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: Text(b.authorName ?? 'Yazar', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Forum ─────────────────────────────────────────────────────

  Widget _buildForum() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Forum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/forum'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF0E5A3A), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tümünü gör', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 15, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_loadingForums)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _SkeletonBox(height: 60)))),
          )
        else if (_forums.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Henüz forum yazısı yok.', style: TextStyle(color: AppColors.textSecondary)))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _forums.map((f) => GestureDetector(
                onTap: () => context.go('/forum'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: const Color(0xFF0E5A3A).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.forum_outlined, color: Color(0xFF0E5A3A), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (f.starterBody != null && f.starterBody!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(f.starterBody!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ])),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Column(children: [
      const SizedBox(height: 32),
      Container(height: 1, color: AppColors.border),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(onTap: () {}, child: const Text('SSS', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('·', style: TextStyle(color: AppColors.textSecondary))),
        GestureDetector(onTap: () {}, child: const Text('İletişim', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('·', style: TextStyle(color: AppColors.textSecondary))),
        GestureDetector(onTap: () {}, child: const Text('Gizlilik', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
      ]),
      const SizedBox(height: 10),
      const Text('© 2025 Evlumba', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Banner Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FullWidthBanner extends StatelessWidget {
  final String imageUrl;
  final double topPadding;

  const _FullWidthBanner({required this.imageUrl, this.topPadding = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, __) => Container(height: 160, color: AppColors.border.withOpacity(0.4)),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discover Grid
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverGrid extends StatelessWidget {
  final List<DesignerProject> projects;
  final void Function(DesignerProject) onTap;
  const _DiscoverGrid({required this.projects, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final left = <DesignerProject>[], right = <DesignerProject>[];
    for (int i = 0; i < projects.length; i++) {
      (i % 2 == 0 ? left : right).add(projects[i]);
    }

    Widget col(List<DesignerProject> items) => Column(
      children: items.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 10 : 0),
        child: _DiscoverCard(project: e.value, height: 200, onTap: () => onTap(e.value)),
      )).toList(),
    );

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: col(left)), const SizedBox(width: 10), Expanded(child: col(right)),
    ]);
  }
}

class _DiscoverCard extends StatelessWidget {
  final DesignerProject project;
  final double height;
  final VoidCallback onTap;
  const _DiscoverCard({required this.project, required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imgUrl = project.displayCoverUrl;
    final name = project.designerName ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: imgUrl.isNotEmpty
              ? SmartImage(url: imgUrl, fit: BoxFit.cover, width: double.infinity)
              : Container(color: AppColors.border, child: const Icon(Icons.image_outlined, color: AppColors.textSecondary))),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(project.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text(name.isNotEmpty ? name.split(' ').first : (project.projectType ?? ''),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.favorite_border_rounded, size: 12, color: AppColors.textSecondary),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5), color: AppColors.background),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _DesignerChip extends StatelessWidget {
  final Profile designer;
  final VoidCallback onTap;
  const _DesignerChip({required this.designer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 72, child: Column(children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0E5A3A).withOpacity(0.3), width: 2)),
          clipBehavior: Clip.hardEdge,
          child: designer.avatarUrl != null && designer.avatarUrl!.isNotEmpty
              ? SmartImage(url: designer.avatarUrl, fit: BoxFit.cover)
              : Container(color: const Color(0xFF0E5A3A).withOpacity(0.1),
                  child: Center(child: Text(designer.displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0E5A3A), fontSize: 22)))),
        ),
        const SizedBox(height: 6),
        Text(designer.displayName.split(' ').first, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (designer.specialty != null) ...[
          const SizedBox(height: 1),
          Text(designer.specialty!, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ])),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _SkeletonAvatar extends StatelessWidget {
  const _SkeletonAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 72, child: Column(children: [
      Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.border.withOpacity(0.5))),
      const SizedBox(height: 6),
      Container(width: 48, height: 10, decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(4))),
    ]));
  }
}
