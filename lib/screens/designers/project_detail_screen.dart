import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';
import '../../models/profile.dart';
import '../../widgets/smart_image.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  DesignerProject? _project;
  Profile? _designer;
  Profile? _currentUserProfile;
  bool _loading = true;
  String? _error;
  int _currentImageIndex = 0;
  ShopLink? _activeShopLink;
  bool _descExpanded = false;
  final PageController _pageController = PageController();
  final ScrollController _thumbController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProject();
    _fetchCurrentUser();
  }

  Future<void> _fetchCurrentUser() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', uid)
          .single();
      if (mounted) setState(() => _currentUserProfile = Profile.fromJson(data as Map<String, dynamic>));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  Future<void> _fetchProject() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order), designer_project_shop_links(id, image_url, pos_x, pos_y, product_url, product_title, product_image_url, product_price)',
          )
          .eq('id', widget.projectId)
          .single();
      final project = DesignerProject.fromJson(data as Map<String, dynamic>);
      await _fetchDesigner(project.designerId);
      setState(() {
        _project = project;
        _loading = false;
      });
    } catch (_) {
      try {
        final data = await supabase
            .from('designer_projects')
            .select(
              'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
            )
            .eq('id', widget.projectId)
            .single();
        final project = DesignerProject.fromJson(data as Map<String, dynamic>);
        await _fetchDesigner(project.designerId);
        setState(() {
          _project = project;
          _loading = false;
        });
      } catch (e2) {
        setState(() {
          _error = 'Proje yüklenirken hata oluştu.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchDesigner(String designerId) async {
    try {
      final data = await supabase
          .from('profiles')
          .select(
            'id, full_name, business_name, avatar_url, specialty, city, role, created_at',
          )
          .eq('id', designerId)
          .single();
      _designer = Profile.fromJson(data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  AppBar _buildAppBar() {
    final avatarUrl = _currentUserProfile?.avatarUrl;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Evlumba',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
          onPressed: () => context.push('/messages'),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.border,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('data:')
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 18, color: AppColors.textSecondary)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: _buildAppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _project == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Proje bulunamadı.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchProject, child: const Text('Tekrar Dene')),
            ],
          ),
        ),
      );
    }

    final project = _project!;
    final allImages = project.images.isNotEmpty
        ? project.images.map((i) => i.imageUrl).where((u) => u.isNotEmpty).toList()
        : project.coverImageUrl != null
            ? [project.coverImageUrl!]
            : <String>[];
    final currentImageUrl = allImages.isNotEmpty ? allImages[_currentImageIndex] : null;
    final hotspots = project.shopLinks
        .where((l) => l.imageUrl == currentImageUrl)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () {
          if (_activeShopLink != null) setState(() => _activeShopLink = null);
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main image carousel with hotspots ──
              if (allImages.isNotEmpty)
                _buildCarousel(allImages, hotspots),

              // ── Thumbnail strip ──
              if (allImages.length > 1)
                _buildThumbnailStrip(allImages),

              // ── Content ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + budget
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (project.budgetLabel.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                project.budgetLevel == 'pro'
                                    ? '₺₺₺'
                                    : project.budgetLabel,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (project.budgetLevel == 'pro')
                                const Text(
                                  'Pro',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Location
                    if (project.location != null &&
                        project.location!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            project.location!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Tags
                    if (project.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: project.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // Created at
                    const SizedBox(height: 12),
                    Text(
                      _formatDate(project.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    // Description
                    if (project.description != null &&
                        project.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Proje Açıklaması',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project.description!,
                        maxLines: _descExpanded ? null : 4,
                        overflow: _descExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _descExpanded = !_descExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _descExpanded ? 'Daha az' : 'Daha fazla oku',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                _descExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Designer mini card
                    if (_designer != null) ...[
                      const SizedBox(height: 24),
                      _DesignerMiniCard(
                        designer: _designer!,
                        onTap: () =>
                            context.push('/designers/${_designer!.id}'),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(List<String> allImages, List<ShopLink> hotspots) {
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          // Images
          PageView.builder(
            controller: _pageController,
            itemCount: allImages.length,
            onPageChanged: (i) {
              setState(() {
                _currentImageIndex = i;
                _activeShopLink = null;
              });
              // Scroll thumbnail into view
              _thumbController.animateTo(
                i * 72.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            itemBuilder: (_, index) =>
                SmartImage(url: allImages[index], fit: BoxFit.cover),
          ),

          // Hotspot dots
          ...hotspots.map((link) {
            final screenWidth = MediaQuery.of(context).size.width;
            return Positioned(
              left: (link.posX / 100) * screenWidth - 14,
              top: (link.posY / 100) * 320 - 14,
              child: GestureDetector(
                onTap: () => setState(
                  () => _activeShopLink =
                      _activeShopLink?.id == link.id ? null : link,
                ),
                child: _HotspotDot(isActive: _activeShopLink?.id == link.id),
              ),
            );
          }),

          // Shop link overlay card
          if (_activeShopLink != null)
            Positioned(
              bottom: 44,
              left: 16,
              right: 16,
              child: _ShopLinkOverlay(
                link: _activeShopLink!,
                onBuy: () => _launchUrl(_activeShopLink!.productUrl),
                onDismiss: () => setState(() => _activeShopLink = null),
              ),
            ),

          // Pagination dots
          if (allImages.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  allImages.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImageIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentImageIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

          // Prev arrow
          if (_currentImageIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

          // Next arrow
          if (_currentImageIndex < allImages.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip(List<String> allImages) {
    return Container(
      height: 72,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        controller: _thumbController,
        scrollDirection: Axis.horizontal,
        itemCount: allImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final isSelected = index == _currentImageIndex;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SmartImage(url: allImages[index], fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Hotspot dot with pulse animation ──────────────────────────────────────────

class _HotspotDot extends StatefulWidget {
  final bool isActive;

  const _HotspotDot({required this.isActive});

  @override
  State<_HotspotDot> createState() => _HotspotDotState();
}

class _HotspotDotState extends State<_HotspotDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary
              .withOpacity(widget.isActive ? 0.95 : 0.65 * _anim.value),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.45 * _anim.value),
              blurRadius: 10,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 14),
      ),
    );
  }
}

// ── Shop link overlay card ────────────────────────────────────────────────────

class _ShopLinkOverlay extends StatelessWidget {
  final ShopLink link;
  final VoidCallback onBuy;
  final VoidCallback onDismiss;

  const _ShopLinkOverlay({
    required this.link,
    required this.onBuy,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (link.productImageUrl != null && link.productImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SmartImage(
                url: link.productImageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (link.productTitle != null && link.productTitle!.isNotEmpty)
                  Text(
                    link.productTitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (link.productPrice != null && link.productPrice!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    link.productPrice!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onBuy,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );
  }
}

// ── Designer mini card ────────────────────────────────────────────────────────

class _DesignerMiniCard extends StatelessWidget {
  final Profile designer;
  final VoidCallback onTap;

  const _DesignerMiniCard({required this.designer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: designer.avatarUrl != null && designer.avatarUrl!.isNotEmpty
                      ? SmartImage(url: designer.avatarUrl, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.person, color: AppColors.primary, size: 28),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        designer.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (designer.specialty != null && designer.specialty!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          designer.specialty!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (designer.city != null && designer.city!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          designer.city!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Sparkle icon top-right
            Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.auto_awesome, size: 16, color: AppColors.primary.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
