import '../../widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';
import '../../models/designer_review.dart';
import '../../models/profile.dart';
import '../../widgets/project_card.dart';
import '../../widgets/review_card.dart';
import '../../widgets/star_rating.dart';

class DesignerProfileScreen extends StatefulWidget {
  final String designerId;

  const DesignerProfileScreen({super.key, required this.designerId});

  @override
  State<DesignerProfileScreen> createState() => _DesignerProfileScreenState();
}

class _DesignerProfileScreenState extends State<DesignerProfileScreen>
    with SingleTickerProviderStateMixin {
  Profile? _profile;
  List<DesignerProject> _projects = [];
  List<DesignerReview> _reviews = [];
  double _avgRating = 0;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profileData = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, about, phone, contact_email, address, website, instagram, facebook, linkedin, cover_photo_url, tags, starting_from, response_time, created_at',
          )
          .eq('id', widget.designerId)
          .maybeSingle();

      if (profileData == null) {
        setState(() {
          _error = 'Tasarımcı bulunamadı.';
          _loading = false;
        });
        return;
      }

      final profile = Profile.fromJson(profileData as Map<String, dynamic>);

      final projectsData = await supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .eq('designer_id', widget.designerId)
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final projects = (projectsData as List)
          .map((e) => DesignerProject.fromJson(e as Map<String, dynamic>))
          .toList();

      final reviewsData = await supabase
          .from('designer_reviews')
          .select(
            'id, designer_id, homeowner_id, project_id, rating, work_quality_rating, communication_rating, value_rating, review_text, reply_text, helpful_count, is_pinned, created_at',
          )
          .eq('designer_id', widget.designerId)
          .order('created_at', ascending: false);

      final reviewsList =
          (reviewsData as List).map((e) => DesignerReview.fromJson(e as Map<String, dynamic>)).toList();

      // Fetch reviewer names
      final reviewerIds = reviewsList.map((r) => r.homeownerId).toSet().toList();
      Map<String, String> reviewerNames = {};
      if (reviewerIds.isNotEmpty) {
        final reviewersData = await supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', reviewerIds);
        reviewerNames = {
          for (final r in reviewersData as List)
            (r as Map<String, dynamic>)['id'] as String:
                ((r['full_name'] as String?) ?? 'Kullanıcı')
                    .split(' ')
                    .first,
        };
      }

      final reviewsWithNames = reviewsList.map((r) {
        return DesignerReview(
          id: r.id,
          designerId: r.designerId,
          homeownerId: r.homeownerId,
          projectId: r.projectId,
          rating: r.rating,
          workQualityRating: r.workQualityRating,
          communicationRating: r.communicationRating,
          valueRating: r.valueRating,
          reviewText: r.reviewText,
          replyText: r.replyText,
          helpfulCount: r.helpfulCount,
          isPinned: r.isPinned,
          createdAt: r.createdAt,
          reviewerName: reviewerNames[r.homeownerId] ?? 'Kullanıcı',
        );
      }).toList();

      final avgRating = reviewsWithNames.isNotEmpty
          ? reviewsWithNames
                  .map((r) => r.rating)
                  .reduce((a, b) => a + b) /
              reviewsWithNames.length
          : 0.0;

      setState(() {
        _profile = profile;
        _projects = projects;
        _reviews = reviewsWithNames;
        _avgRating = avgRating;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Profil yüklenirken hata oluştu.';
        _loading = false;
      });
    }
  }

  Future<void> _startConversation() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      context.push('/login');
      return;
    }
    if (currentUser.id == widget.designerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendinize mesaj gönderemezsiniz.')),
      );
      return;
    }

    try {
      // Check if conversation already exists
      final existingData = await supabase
          .from('conversations')
          .select('id')
          .eq('homeowner_id', currentUser.id)
          .eq('designer_id', widget.designerId)
          .maybeSingle();

      String conversationId;
      if (existingData != null) {
        conversationId = (existingData as Map<String, dynamic>)['id'] as String;
      } else {
        final newConv = await supabase
            .from('conversations')
            .insert({
              'homeowner_id': currentUser.id,
              'designer_id': widget.designerId,
            })
            .select('id')
            .single();
        conversationId = (newConv as Map<String, dynamic>)['id'] as String;
      }

      if (mounted) {
        context.push(
          '/chat/$conversationId?name=${Uri.encodeComponent(_profile?.displayName ?? 'Tasarımcı')}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konuşma başlatılamadı.')),
        );
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

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Profil bulunamadı.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: profile.coverPhotoUrl != null &&
                      profile.coverPhotoUrl!.isNotEmpty
                  ? SmartImage(url: profile.coverPhotoUrl, fit: BoxFit.cover)
                  : Container(color: AppColors.primary.withOpacity(0.15)),
            ),
          ),
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: profile,
              avgRating: _avgRating,
              reviewCount: _reviews.length,
              projectCount: _projects.length,
              onMessage: _startConversation,
              onLaunchUrl: _launchUrl,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Projeler'),
                  Tab(text: 'Hakkında'),
                  Tab(text: 'Değerlendirmeler'),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Projects tab
            _projects.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz yayınlanmış proje yok.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) =>
                        ProjectCard(project: _projects[index]),
                  ),

            // About tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _AboutSection(
                profile: profile,
                onLaunchUrl: _launchUrl,
              ),
            ),

            // Reviews tab
            _reviews.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz değerlendirme yok.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) =>
                        ReviewCard(review: _reviews[index]),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: ElevatedButton.icon(
          onPressed: _startConversation,
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Mesaj Gönder'),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Profile profile;
  final double avgRating;
  final int reviewCount;
  final int projectCount;
  final VoidCallback onMessage;
  final Future<void> Function(String) onLaunchUrl;

  const _ProfileHeader({
    required this.profile,
    required this.avgRating,
    required this.reviewCount,
    required this.projectCount,
    required this.onMessage,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? SmartImage(url: profile.avatarUrl, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (profile.specialty != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.specialty!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (profile.city != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            profile.city!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              RatingBadge(rating: avgRating, reviewCount: reviewCount),
              const SizedBox(width: 16),
              const Icon(
                Icons.grid_view_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '$projectCount Proje',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (profile.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: profile.tags.map((tag) {
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final Profile profile;
  final Future<void> Function(String) onLaunchUrl;

  const _AboutSection({required this.profile, required this.onLaunchUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.about != null && profile.about!.isNotEmpty) ...[
          const Text(
            'Hakkında',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.about!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'İletişim',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (profile.phone != null && profile.phone!.isNotEmpty)
          _ContactItem(
            icon: Icons.phone_outlined,
            label: profile.phone!,
            onTap: () => onLaunchUrl('tel:${profile.phone}'),
          ),
        if (profile.contactEmail != null && profile.contactEmail!.isNotEmpty)
          _ContactItem(
            icon: Icons.email_outlined,
            label: profile.contactEmail!,
            onTap: () => onLaunchUrl('mailto:${profile.contactEmail}'),
          ),
        if (profile.website != null && profile.website!.isNotEmpty)
          _ContactItem(
            icon: Icons.language_outlined,
            label: profile.website!,
            onTap: () => onLaunchUrl(profile.website!),
          ),
        if (profile.instagram != null && profile.instagram!.isNotEmpty)
          _ContactItem(
            icon: Icons.camera_alt_outlined,
            label: '@${profile.instagram}',
            onTap: () =>
                onLaunchUrl('https://instagram.com/${profile.instagram}'),
          ),
        if (profile.address != null && profile.address!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Adres',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _ContactItem(
            icon: Icons.location_on_outlined,
            label: profile.address!,
          ),
        ],
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ContactItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      onTap != null ? AppColors.primary : AppColors.textPrimary,
                  decoration:
                      onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
