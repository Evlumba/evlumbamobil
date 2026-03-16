import '../../widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  DesignerProject? _project;
  bool _loading = true;
  String? _error;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProject();
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

      setState(() {
        _project = DesignerProject.fromJson(data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      // Try without shop links if table missing
      try {
        final data = await supabase
            .from('designer_projects')
            .select(
              'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
            )
            .eq('id', widget.projectId)
            .single();

        setState(() {
          _project = DesignerProject.fromJson(data as Map<String, dynamic>);
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Proje bulunamadı.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProject,
                child: const Text('Tekrar Dene'),
              ),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image gallery header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: allImages.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          itemCount: allImages.length,
                          onPageChanged: (i) =>
                              setState(() => _currentImageIndex = i),
                          itemBuilder: (context, index) {
                            return SmartImage(
                              url: allImages[index],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
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
                      ],
                    )
                  : Container(color: AppColors.border),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (project.projectType != null)
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: project.projectType!,
                        ),
                      if (project.location != null)
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: project.location!,
                        ),
                      if (project.budgetLabel.isNotEmpty)
                        _InfoChip(
                          icon: Icons.attach_money_outlined,
                          label: project.budgetLabel,
                        ),
                    ],
                  ),
                  if (project.description != null &&
                      project.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Proje Hakkında',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (project.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Etiketler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: project.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Shop links
                  if (project.shopLinks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Ürünler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: project.shopLinks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final link = project.shopLinks[index];
                        return _ShopLinkCard(
                          link: link,
                          onTap: () => _launchUrl(link.productUrl),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),
                  // View designer button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/designers/${project.designerId}'),
                      icon: const Icon(Icons.person_outlined, size: 18),
                      label: const Text('Tasarımcı Profilini Görüntüle'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ShopLinkCard extends StatelessWidget {
  final dynamic link;
  final VoidCallback onTap;

  const _ShopLinkCard({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (link.productImageUrl != null &&
                (link.productImageUrl as String).isNotEmpty)
              SmartImage(
                url: link.productImageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
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
                children: [
                  if (link.productTitle != null &&
                      (link.productTitle as String).isNotEmpty)
                    Text(
                      link.productTitle as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (link.productPrice != null &&
                      (link.productPrice as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      link.productPrice as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
