import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';
import '../../models/profile.dart';
import '../../widgets/smart_image.dart';

// ────────────────────────────────────────────────────────────────
// Data
// ────────────────────────────────────────────────────────────────

class _Category {
  final String id;
  final String label;
  final String imageUrl;

  const _Category({required this.id, required this.label, required this.imageUrl});
}

const _categories = [
  _Category(id: 'salon', label: 'Salon', imageUrl: 'https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'mutfak', label: 'Mutfak', imageUrl: 'https://images.unsplash.com/photo-1556912167-f556f1f39faa?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'banyo', label: 'Banyo', imageUrl: 'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'yatak-odasi', label: 'Yatak', imageUrl: 'https://images.unsplash.com/photo-1540518614846-7eded433c457?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'ev-ofisi', label: 'Ofis', imageUrl: 'https://images.unsplash.com/photo-1524758631624-e2822e304c36?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'balkon', label: 'Balkon', imageUrl: 'https://images.unsplash.com/photo-1505692952047-1a78307da8f2?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'antre', label: 'Antre', imageUrl: 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=400&q=80'),
  _Category(id: 'cocuk', label: 'Çocuk', imageUrl: 'https://images.unsplash.com/photo-1566140967404-b8b3932483f5?auto=format&fit=crop&w=400&q=80'),
];

class _Service {
  final String label;
  final IconData icon;
  final Color color;
  final Color iconBg;
  final String route;

  const _Service({
    required this.label,
    required this.icon,
    required this.color,
    required this.iconBg,
    required this.route,
  });
}

const _services = [
  _Service(label: 'Forum', icon: Icons.forum_outlined, color: Color(0xFF0284C7), iconBg: Color(0xFFE0F2FE), route: '/forum'),
  _Service(label: 'Blog', icon: Icons.article_outlined, color: Color(0xFF7C3AED), iconBg: Color(0xFFEDE9FE), route: '/blog'),
  _Service(label: 'AI Tasarla', icon: Icons.auto_awesome_outlined, color: Color(0xFFDB2777), iconBg: Color(0xFFFCE7F3), route: '/ai-design'),
  _Service(label: 'Keşfet\nOyunu', icon: Icons.casino_outlined, color: Color(0xFF059669), iconBg: Color(0xFFD1FAE5), route: '/game'),
  _Service(label: 'İlanlar', icon: Icons.work_outline, color: Color(0xFFD97706), iconBg: Color(0xFFFEF3C7), route: '/ilanlar'),
];

// ────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DesignerProject> _featuredProjects = [];
  List<Profile> _featuredDesigners = [];
  bool _loadingProjects = true;
  bool _loadingDesigners = true;

  @override
  void initState() {
    super.initState();
    _fetchFeatured();
  }

  Future<void> _fetchFeatured() async {
    await Future.wait([_fetchProjects(), _fetchDesigners()]);
  }

  Future<void> _fetchProjects() async {
    try {
      final data = await supabase
          .from('designer_projects')
          .select('id, designer_id, title, project_type, cover_image_url, budget_level, tags, is_published, created_at, designer_project_images(image_url, sort_order)')
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(10);

      final all = (data as List).map((e) => DesignerProject.fromJson(e as Map<String, dynamic>)).toList();
      all.shuffle();
      if (mounted) {
        setState(() {
          _featuredProjects = all.take(5).toList();
          _loadingProjects = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _fetchDesigners() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('id, full_name, business_name, avatar_url, specialty, city, cover_photo_url, tags, starting_from')
          .inFilter('role', ['designer', 'designer_pending'])
          .limit(10);

      final all = (data as List).map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
      all.shuffle();
      if (mounted) {
        setState(() {
          _featuredDesigners = all.take(6).toList();
          _loadingDesigners = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDesigners = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildFeaturedProjects()),
          SliverToBoxAdapter(child: _buildDesigners()),
          SliverToBoxAdapter(child: _buildTagBanner()),
          SliverToBoxAdapter(child: _buildServices()),
          SliverToBoxAdapter(child: _buildFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 56,
      expandedHeight: 112,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Text('E', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Evlumba',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: GestureDetector(
                onTap: () => context.go('/explore'),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 12),
                      Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text(
                        'Proje, oda, tasarımcı ara...',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Categories ───────────────────────────────────────────────

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Kategoriler', style: _sectionTitle()),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final cat = _categories[i];
              return GestureDetector(
                onTap: () => context.go('/explore'),
                child: SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: CachedNetworkImage(
                          imageUrl: cat.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.border),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.border,
                            child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.label,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Featured Projects ─────────────────────────────────────────

  Widget _buildFeaturedProjects() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text('İlham Veren Tasarımlar', style: _sectionTitle())),
              TextButton(
                onPressed: () => context.go('/explore'),
                child: const Text('Tümü', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: _loadingProjects
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: 5,
                  itemBuilder: (_, __) => _ProjectSkeletonCard(),
                )
              : _featuredProjects.isEmpty
                  ? const Center(child: Text('Henüz proje yok', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: _featuredProjects.length,
                      itemBuilder: (context, i) => _FeaturedProjectCard(project: _featuredProjects[i]),
                    ),
        ),
      ],
    );
  }

  // ── Designers ─────────────────────────────────────────────────

  Widget _buildDesigners() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text('Profesyoneller', style: _sectionTitle())),
              TextButton(
                onPressed: () => context.go('/designers-list'),
                child: const Text('Tümü', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: _loadingDesigners
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: 5,
                  itemBuilder: (_, __) => _DesignerSkeletonCard(),
                )
              : _featuredDesigners.isEmpty
                  ? const Center(child: Text('Henüz tasarımcı yok', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: _featuredDesigners.length,
                      itemBuilder: (context, i) => _DesignerMiniCard(designer: _featuredDesigners[i]),
                    ),
        ),
      ],
    );
  }

  // ── Tag & Earn Banner ─────────────────────────────────────────

  Widget _buildTagBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Yeni Özellik ✨', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Etiketle ve Kazan',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Projelerine ürün etiketi ekle,\nhakiki gelir elde et.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hemen Başla →',
                        style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sell_outlined, color: Colors.white, size: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Services ──────────────────────────────────────────────────

  Widget _buildServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Hizmetler', style: _sectionTitle()),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: _services.map((s) => _ServiceTile(service: s)).toList(),
          ),
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterLink(label: 'SSS', onTap: () {}),
            _FooterDot(),
            _FooterLink(label: 'İletişim', onTap: () {}),
            _FooterDot(),
            _FooterLink(label: 'Gizlilik', onTap: () {}),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '© 2025 Evlumba',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  TextStyle _sectionTitle() => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
}

// ────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────

class _FeaturedProjectCard extends StatelessWidget {
  final DesignerProject project;
  const _FeaturedProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final imgUrl = project.displayCoverUrl;
    return GestureDetector(
      onTap: () => context.push('/projects/${project.id}'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: imgUrl.isNotEmpty
                  ? SmartImage(url: imgUrl, fit: BoxFit.cover, width: double.infinity)
                  : Container(color: AppColors.border, child: const Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 32)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (project.projectType != null) ...[
                    const SizedBox(height: 2),
                    Text(project.projectType!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignerMiniCard extends StatelessWidget {
  final Profile designer;
  const _DesignerMiniCard({required this.designer});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/designers/${designer.id}'),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 2)),
              clipBehavior: Clip.hardEdge,
              child: designer.avatarUrl != null && designer.avatarUrl!.isNotEmpty
                  ? SmartImage(url: designer.avatarUrl, fit: BoxFit.cover)
                  : Container(color: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.person, color: AppColors.primary, size: 28)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                designer.displayName.split(' ').first,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (designer.city != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(designer.city!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final _Service service;
  const _ServiceTile({required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Routes like /forum, /blog not yet implemented — show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${service.label} yakında!'), duration: const Duration(seconds: 1)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: service.iconBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(service.icon, color: service.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              service.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _DesignerSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    );
  }
}

class _FooterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('·', style: TextStyle(color: AppColors.textSecondary)),
    );
  }
}
