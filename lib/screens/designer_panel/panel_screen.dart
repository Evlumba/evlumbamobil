import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';

class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  Profile? _profile;
  int _projectCount = 0;
  int _reviewCount = 0;
  double _avgRating = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() => _loading = true);

    try {
      final profileData = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, cover_photo_url, tags, created_at',
          )
          .eq('id', currentUser.id)
          .maybeSingle();

      Profile? profile;
      if (profileData != null) {
        profile = Profile.fromJson(profileData as Map<String, dynamic>);
      }

      final projectsData = await supabase
          .from('designer_projects')
          .select('id')
          .eq('designer_id', currentUser.id);

      final reviewsData = await supabase
          .from('designer_reviews')
          .select('id, rating')
          .eq('designer_id', currentUser.id);

      final reviews = reviewsData as List;
      final reviewCount = reviews.length;
      final avgRating = reviewCount > 0
          ? reviews
                  .map((r) =>
                      (r as Map<String, dynamic>)['rating'] as num? ?? 0)
                  .reduce((a, b) => a + b) /
              reviewCount
          : 0.0;

      setState(() {
        _profile = profile;
        _projectCount = projectsData.length;
        _reviewCount = reviewCount;
        _avgRating = avgRating.toDouble();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tasarımcı Paneli'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Profile summary
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: _profile?.avatarUrl != null &&
                                    _profile!.avatarUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _profile!.avatarUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppColors.primary.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                      size: 32,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.displayName ?? 'Tasarımcı',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                if (_profile?.specialty != null)
                                  Text(
                                    _profile!.specialty!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                if (_profile?.city != null)
                                  Text(
                                    _profile!.city!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push('/panel/edit-profile'),
                            child: const Text('Düzenle'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Proje',
                              value: '$_projectCount',
                              icon: Icons.grid_view_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Değerlendirme',
                              value: '$_reviewCount',
                              icon: Icons.star_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Puan',
                              value: _reviewCount > 0
                                  ? _avgRating.toStringAsFixed(1)
                                  : '–',
                              icon: Icons.trending_up_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Actions
                    Container(
                      color: AppColors.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Yönetim',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          _PanelItem(
                            icon: Icons.grid_view_outlined,
                            title: 'Projelerim',
                            subtitle: '$_projectCount proje',
                            onTap: () => context.push('/panel/projects'),
                          ),
                          const Divider(height: 1),
                          _PanelItem(
                            icon: Icons.person_outlined,
                            title: 'Profilimi Düzenle',
                            subtitle: 'Ad, uzmanlık, biyografi',
                            onTap: () => context.push('/panel/edit-profile'),
                          ),
                          const Divider(height: 1),
                          _PanelItem(
                            icon: Icons.visibility_outlined,
                            title: 'Profilimi Görüntüle',
                            subtitle: 'Herkese açık profilin',
                            onTap: () {
                              final uid = supabase.auth.currentUser?.id;
                              if (uid != null) {
                                context.push('/designers/$uid');
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      color: AppColors.surface,
                      child: _PanelItem(
                        icon: Icons.add_circle_outline,
                        title: 'Yeni Proje Ekle',
                        subtitle: 'Portfolyona yeni bir proje ekle',
                        color: AppColors.primary,
                        onTap: () => context.push('/panel/projects/new'),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _PanelItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: itemColor,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
