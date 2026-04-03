import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';

const _proHavuzuName = 'Profesyonel Havuzum';

class _CollectionItem {
  final String id;
  final String title;
  final String? imageUrl;
  final String? subtitle;
  final bool isDesigner;

  const _CollectionItem({
    required this.id,
    required this.title,
    this.imageUrl,
    this.subtitle,
    this.isDesigner = false,
  });
}

class _Collection {
  final String id;
  final String name;
  final List<String> itemIds;
  List<_CollectionItem> items;
  List<_CollectionItem> projectItems;
  List<_CollectionItem> designerItems;

  _Collection({
    required this.id,
    required this.name,
    required this.itemIds,
    this.items = const [],
    this.projectItems = const [],
    this.designerItems = const [],
  });
}

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<_Collection> _collections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() { _loading = false; _collections = []; });
        return;
      }

      final data = await supabase
          .from('collections')
          .select('id, title, created_at, collection_items(design_id)')
          .order('created_at', ascending: false);

      final cols = (data as List).map((row) {
        final itemIds = ((row['collection_items'] as List?) ?? [])
            .map((e) => e['design_id'] as String)
            .toList();
        return _Collection(id: row['id'], name: row['title'], itemIds: itemIds);
      }).toList();

      // Tüm ID'leri topla ve her ikisi için sorgula — koleksiyon adı yerine veri tipine bak
      final allIds = cols.expand((c) => c.itemIds).toSet().toList();

      Map<String, _CollectionItem> projectMap = {};
      Map<String, _CollectionItem> designerMap = {};

      if (allIds.isNotEmpty) {
        // Paralel sorgular
        final results = await Future.wait([
          supabase
              .from('designer_projects')
              .select('id, title, cover_image_url')
              .inFilter('id', allIds),
          supabase
              .from('profiles')
              .select('id, full_name, business_name, specialty, avatar_url, city')
              .inFilter('id', allIds),
        ]);

        for (final p in (results[0] as List)) {
          projectMap[p['id']] = _CollectionItem(
            id: p['id'],
            title: p['title'] ?? 'Proje',
            imageUrl: p['cover_image_url'],
          );
        }
        for (final d in (results[1] as List)) {
          final name = (d['business_name'] ?? d['full_name'] ?? 'Tasarımcı') as String;
          final parts = <String>[
            if (d['specialty'] != null) d['specialty'] as String,
            if (d['city'] != null) d['city'] as String,
          ];
          designerMap[d['id']] = _CollectionItem(
            id: d['id'],
            title: name.trim(),
            imageUrl: d['avatar_url'],
            subtitle: parts.join(' · '),
            isDesigner: true,
          );
        }
      }

      // Her item'ın hangi tipte olduğunu veri tabanından öğren
      for (final col in cols) {
        col.projectItems = col.itemIds
            .map((id) => projectMap[id])
            .where((item) => item != null)
            .cast<_CollectionItem>()
            .toList();
        col.designerItems = col.itemIds
            .map((id) => designerMap[id])
            .where((item) => item != null)
            .cast<_CollectionItem>()
            .toList();
        col.items = [...col.projectItems, ...col.designerItems];
      }

      setState(() { _collections = cols; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Koleksiyonlar yüklenemedi.'; _loading = false; });
    }
  }

  Future<void> _removeItem(String collectionId, String itemId) async {
    try {
      final existing = await supabase
          .from('collection_items')
          .select('id')
          .eq('collection_id', collectionId)
          .eq('design_id', itemId)
          .maybeSingle();
      if (existing != null) {
        await supabase.from('collection_items').delete().eq('id', existing['id']);
      }
      await _load();
    } catch (_) {}
  }

  Future<void> _deleteCollection(String collectionId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Koleksiyonu Sil'),
        content: Text('"$name" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await supabase.from('collections').delete().eq('id', collectionId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Koleksiyonlarım'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
                ],
              ),
            )
          : _collections.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Henüz koleksiyon yok.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Proje veya tasarımcı beğenince\nkoleksiyonun burada görünür.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _collections.length,
                itemBuilder: (context, index) {
                  final col = _collections[index];
                  return _CollectionCard(
                    collection: col,
                    onRemoveItem: (itemId) => _removeItem(col.id, itemId),
                    onDelete: () => _deleteCollection(col.id, col.name),
                  );
                },
              ),
            ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final _Collection collection;
  final void Function(String itemId) onRemoveItem;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onRemoveItem,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Icon(
                  collection.designerItems.isNotEmpty && collection.projectItems.isEmpty
                      ? Icons.people_outline
                      : Icons.bookmark_border,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    collection.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${collection.itemIds.length} öğe',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Koleksiyonu sil',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items
          if (collection.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bu koleksiyon boş.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proje grid
                if (collection.projectItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...collection.projectItems.take(6).map((item) => _ProjectThumb(
                          item: item,
                          onRemove: () => onRemoveItem(item.id),
                          onTap: () => context.push('/projects/${item.id}'),
                        )),
                        if (collection.projectItems.length > 6)
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 32 - 24 - 16) / 3,
                            height: (MediaQuery.of(context).size.width - 32 - 24 - 16) / 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('+${collection.projectItems.length - 6}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // Tasarımcı listesi
                if (collection.designerItems.isNotEmpty) ...[
                  if (collection.projectItems.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Profesyoneller', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  Column(
                    children: collection.designerItems.take(5).map((item) => _DesignerRow(
                      item: item,
                      onRemove: () => onRemoveItem(item.id),
                      onTap: () => context.push('/designers/${item.id}'),
                    )).toList(),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DesignerRow extends StatelessWidget {
  final _CollectionItem item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _DesignerRow({required this.item, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              clipBehavior: Clip.hardEdge,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _InitialAvatar(name: item.title))
                  : _InitialAvatar(name: item.title),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty)
                    Text(item.subtitle!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              onPressed: onRemove,
              tooltip: 'Kaldır',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectThumb extends StatelessWidget {
  final _CollectionItem item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _ProjectThumb({required this.item, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.width - 32 - 24 - 16) / 3;
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(item.imageUrl!,
                      width: size, height: size, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                      ))
                  : Container(
                      color: AppColors.background,
                      child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(letter,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    );
  }
}
