import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/forum.dart';

/// Slugify helper (Turkish-aware)
String _slugify(String value) {
  return value
      .toLowerCase()
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
}

String _formatDate(DateTime dt) {
  const months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  bool _loading = true;
  List<ForumTopic> _topics = [];
  String _search = '';
  String? _error;

  // Auth & membership
  String? _userId;
  String? _role;
  String? _adminRole;
  ForumMember? _member;

  bool get _isProfessional =>
      _role == 'designer' || _role == 'designer_pending';
  bool get _isAdmin =>
      _adminRole == 'admin' || _adminRole == 'super_admin';
  bool get _canJoinForum => _isProfessional || _isAdmin;
  bool get _canParticipate =>
      _userId != null && _member != null && _canJoinForum;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.wait([_loadAuth(), _loadTopics()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAuth() async {
    final user = supabase.auth.currentUser;
    _userId = user?.id;
    if (_userId == null) return;

    final profileFuture = supabase
        .from('profiles')
        .select('role')
        .eq('id', _userId!)
        .maybeSingle();
    final memberFuture = supabase
        .from('forum_members')
        .select('user_id, lumba_name')
        .eq('user_id', _userId!)
        .maybeSingle();
    final adminFuture =
        supabase.rpc('get_admin_role', params: {'user_uuid': _userId!});

    final results = await Future.wait<dynamic>(
        [profileFuture, memberFuture, adminFuture]);

    final profile = results[0] as Map<String, dynamic>?;
    final memberData = results[1] as Map<String, dynamic>?;
    final adminRoleData = results[2];

    _role = profile?['role'] as String? ??
        user?.userMetadata?['role'] as String?;
    _adminRole = (adminRoleData == 'admin' || adminRoleData == 'super_admin')
        ? adminRoleData as String
        : null;
    _member = memberData != null ? ForumMember.fromJson(memberData) : null;
  }

  Future<void> _loadTopics() async {
    final resp = await supabase
        .from('forum_topics')
        .select('id, slug, title, is_pinned, starter_body, created_at, last_post_at')
        .order('is_pinned', ascending: false)
        .order('last_post_at', ascending: false);

    _topics = (resp as List).map((j) => ForumTopic.fromJson(j)).toList();
  }

  List<ForumTopic> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _topics;
    return _topics
        .where((t) => t.title.toLowerCase().contains(q))
        .toList();
  }

  // ──────────── Join forum ────────────
  Future<void> _showJoinDialog() async {
    if (_userId == null) {
      context.push('/login');
      return;
    }
    if (!_canJoinForum) {
      _showSnack('Foruma sadece profesyoneller katılabilir.');
      return;
    }

    final controller = TextEditingController(text: _member?.lumbaName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foruma Katıl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu isim forum paylaşımlarınızda görünecek isminizdir.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: 'LumbaName',
                hintText: 'En az 3 karakter',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    if (result.length < 3) {
      _showSnack('LumbaName en az 3 karakter olmalı.');
      return;
    }

    try {
      final data = await supabase
          .from('forum_members')
          .upsert(
            {'user_id': _userId!, 'lumba_name': result},
            onConflict: 'user_id',
          )
          .select('user_id, lumba_name')
          .single();

      setState(() => _member = ForumMember.fromJson(data));
      _showSnack('Foruma başarıyla katıldın!');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate key')) {
        _showSnack('Bu LumbaName kullanılıyor. Başka bir isim dene.');
      } else {
        _showSnack('Hata: $msg');
      }
    }
  }

  // ──────────── Create topic ────────────
  Future<void> _showCreateTopicSheet() async {
    if (!_canParticipate) {
      _showSnack('Konu açmak için foruma katılman gerekiyor.');
      return;
    }

    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool creating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Yeni Konu Başlat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Konu başlığı',
                  hintText: 'En az 5 karakter',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'İlk mesajın',
                  hintText: 'En az 5 karakter',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: creating
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        final body = bodyCtrl.text.trim();
                        if (title.length < 5) {
                          _showSnack('Başlık en az 5 karakter olmalı.');
                          return;
                        }
                        if (body.length < 5) {
                          _showSnack('Mesaj en az 5 karakter olmalı.');
                          return;
                        }

                        setSheetState(() => creating = true);

                        final usedSlugs =
                            _topics.map((t) => t.slug).toSet();
                        final base =
                            _slugify(title).isNotEmpty ? _slugify(title) : 'konu-${DateTime.now().millisecondsSinceEpoch}';
                        var slug = base;
                        var counter = 2;
                        while (usedSlugs.contains(slug)) {
                          slug = '$base-$counter';
                          counter++;
                        }

                        try {
                          final topicData = await supabase
                              .from('forum_topics')
                              .insert({
                                'title': title,
                                'slug': slug,
                                'created_by': _userId!,
                                'is_pinned': false,
                              })
                              .select('id, slug, title, is_pinned, starter_body, created_at, last_post_at')
                              .single();

                          await supabase.from('forum_posts').insert({
                            'topic_id': topicData['id'],
                            'author_id': _userId!,
                            'body': body,
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadTopics();
                          if (mounted) {
                            setState(() {});
                            context.push('/forum/${topicData['id']}');
                          }
                        } catch (e) {
                          _showSnack('Hata: $e');
                          setSheetState(() => creating = false);
                        }
                      },
                child: creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Konu Aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ──────────── Build ────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          if (_userId != null && _canJoinForum)
            TextButton.icon(
              onPressed: _showJoinDialog,
              icon: const Icon(Icons.person, size: 18),
              label: Text(
                _member?.lumbaName ?? 'Katıl',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (_userId == null)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Giriş Yap'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Forumda ara...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // Info banner
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Herkes okuyabilir; konu açmak ve yanıt yazmak için foruma katılman gerekir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ),
                  // Topic list
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _search.isNotEmpty
                                  ? 'Aramanıza uygun konu bulunamadı.'
                                  : 'Henüz konu yok.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _TopicCard(topic: _filtered[i]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _canParticipate
          ? FloatingActionButton.extended(
              onPressed: _showCreateTopicSheet,
              icon: const Icon(Icons.add),
              label: const Text('Konu Aç'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _TopicCard extends StatelessWidget {
  final ForumTopic topic;

  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/forum/${topic.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (topic.isPinned) ...[
                  Icon(Icons.push_pin, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    topic.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Son hareket: ${_formatDate(topic.lastPostAt)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
