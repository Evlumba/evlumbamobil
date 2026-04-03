import '../../widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
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

  // Koleksiyon / beğen state
  bool _isSaved = false;
  List<Map<String, dynamic>> _collections = [];
  Set<String> _savedInCollectionIds = {};

  static const _proHavuzuName = 'Profesyonel Havuzum';

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
      _loadCollections();
    } catch (e) {
      setState(() {
        _error = 'Profil yüklenirken hata oluştu.';
        _loading = false;
      });
    }
  }

  Future<void> _loadCollections() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await supabase
          .from('collections')
          .select('id, title, collection_items(design_id)')
          .order('created_at', ascending: true);
      final list = List<Map<String, dynamic>>.from(rows as List);
      final savedIds = <String>{};
      for (final col in list) {
        final items = col['collection_items'] as List? ?? [];
        if (items.any((i) => i['design_id'] == widget.designerId)) {
          savedIds.add(col['id'] as String);
        }
      }
      if (mounted) {
        setState(() {
          _collections = list;
          _savedInCollectionIds = savedIds;
          _isSaved = savedIds.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<void> _showSaveSheet() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydetmek için giriş yapmalısın'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await _loadCollections();
    if (!mounted) return;

    // Filtre: sadece genel koleksiyonlar + "Profesyonel Havuzum"
    final designerCols = _collections
        .where((c) => (c['title'] as String?) == _proHavuzuName || true)
        .toList();

    if (designerCols.isEmpty) {
      await _toggleSaveInCollection(null, _proHavuzuName);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _CollectionPickerSheet(
        collections: designerCols,
        savedInIds: _savedInCollectionIds,
        defaultCollectionName: _proHavuzuName,
        onToggle: (colId, colName) async {
          await _toggleSaveInCollection(colId, colName);
          if (mounted) Navigator.pop(context);
        },
        onCreateNew: (name) async {
          await _toggleSaveInCollection(null, name);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _toggleSaveInCollection(String? existingColId, String colName) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      String colId;
      if (existingColId != null) {
        colId = existingColId;
        if (_savedInCollectionIds.contains(colId)) {
          final existing = await supabase
              .from('collection_items')
              .select('id')
              .eq('collection_id', colId)
              .eq('design_id', widget.designerId)
              .maybeSingle();
          if (existing != null) {
            await supabase.from('collection_items').delete().eq('id', existing['id']);
          }
          if (mounted) {
            setState(() {
              _savedInCollectionIds.remove(colId);
              _isSaved = _savedInCollectionIds.isNotEmpty;
            });
          }
          _showSnack('Koleksiyondan çıkarıldı');
          return;
        }
      } else {
        final created = await supabase
            .from('collections')
            .insert({'user_id': uid, 'title': colName, 'is_public': false})
            .select('id')
            .single();
        colId = created['id'] as String;
      }
      await supabase.from('collection_items').insert({
        'collection_id': colId,
        'design_id': widget.designerId,
      });
      await _loadCollections();
      _showSnack('"$colName" koleksiyonuna eklendi ✓');
    } catch (_) {
      _showSnack('Bir hata oluştu');
    }
  }

  void _showShareSheet() {
    final profile = _profile;
    if (profile == null) return;
    final link = 'https://www.evlumba.com/tasarimcilar/supa_${widget.designerId}';
    final text = '${profile.displayName} - Evlumba\'da bu tasarımcıya bak!\n$link';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareSheet(
        onWhatsApp: () async {
          Navigator.pop(context);
          final encoded = Uri.encodeComponent(text);
          final uri = Uri.parse('https://wa.me/?text=$encoded');
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        onInstagram: () async {
          Navigator.pop(context);
          await Share.share(text);
        },
        onCopyLink: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: link));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link kopyalandı'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
          );
        },
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
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
            actions: [
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.favorite : Icons.favorite_border,
                  color: _isSaved ? Colors.red : Colors.white,
                ),
                onPressed: _showSaveSheet,
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: _showShareSheet,
              ),
              const SizedBox(width: 4),
            ],
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

// ── Collection picker sheet ───────────────────────────────────────────────────

class _CollectionPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> collections;
  final Set<String> savedInIds;
  final String defaultCollectionName;
  final void Function(String colId, String colName) onToggle;
  final void Function(String name) onCreateNew;

  const _CollectionPickerSheet({
    required this.collections,
    required this.savedInIds,
    required this.defaultCollectionName,
    required this.onToggle,
    required this.onCreateNew,
  });

  @override
  State<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<_CollectionPickerSheet> {
  final _controller = TextEditingController();
  bool _showNew = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Profesyonel Havuzuna Ekle',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ...widget.collections.map((col) {
              final id = col['id'] as String;
              final title = col['title'] as String? ?? 'Koleksiyon';
              final isSaved = widget.savedInIds.contains(id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(title, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                trailing: isSaved
                    ? const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                    : const Icon(Icons.radio_button_unchecked, color: AppColors.border, size: 22),
                onTap: () => widget.onToggle(id, title),
              );
            }),
            const Divider(),
            if (_showNew) ...[
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Koleksiyon adı…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (v) { if (v.trim().isNotEmpty) widget.onCreateNew(v.trim()); },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) widget.onCreateNew(_controller.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Oluştur ve Ekle', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ] else
              TextButton.icon(
                onPressed: () => setState(() => _showNew = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Koleksiyon Oluştur'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Share sheet ───────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  final VoidCallback onWhatsApp;
  final VoidCallback onInstagram;
  final VoidCallback onCopyLink;

  const _ShareSheet({
    required this.onWhatsApp,
    required this.onInstagram,
    required this.onCopyLink,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Paylaş', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareOption(icon: Icons.chat_rounded, color: const Color(0xFF25D366), label: 'WhatsApp', onTap: onWhatsApp),
                _ShareOption(icon: Icons.camera_alt_rounded, color: const Color(0xFFE1306C), label: 'Instagram', onTap: onInstagram),
                _ShareOption(icon: Icons.link_rounded, color: AppColors.primary, label: 'Link Kopyala', onTap: onCopyLink),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
