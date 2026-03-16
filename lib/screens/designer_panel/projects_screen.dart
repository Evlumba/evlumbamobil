import '../../widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';

class PanelProjectsScreen extends StatefulWidget {
  const PanelProjectsScreen({super.key});

  @override
  State<PanelProjectsScreen> createState() => _PanelProjectsScreenState();
}

class _PanelProjectsScreenState extends State<PanelProjectsScreen> {
  List<DesignerProject> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .eq('designer_id', currentUser.id)
          .order('created_at', ascending: false);

      setState(() {
        _projects = (data as List)
            .map((e) => DesignerProject.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Projeler yüklenirken hata oluştu.';
        _loading = false;
      });
    }
  }

  Future<void> _deleteProject(String projectId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Sil'),
        content: const Text(
          'Bu projeyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.from('designer_projects').delete().eq('id', projectId);
      setState(() {
        _projects.removeWhere((p) => p.id == projectId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proje silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _togglePublish(DesignerProject project) async {
    try {
      await supabase
          .from('designer_projects')
          .update({'is_published': !project.isPublished})
          .eq('id', project.id);

      setState(() {
        final index = _projects.indexWhere((p) => p.id == project.id);
        if (index >= 0) {
          _projects[index] = project.copyWith(
            isPublished: !project.isPublished,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Projelerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/panel/projects/new');
              _fetchProjects();
            },
            tooltip: 'Yeni Proje',
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchProjects,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.grid_view_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz projeniz yok.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.push('/panel/projects/new');
                      _fetchProjects();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('İlk Projeyi Ekle'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchProjects,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  return _ProjectListItem(
                    project: project,
                    onEdit: () async {
                      await context.push('/panel/projects/${project.id}/edit');
                      _fetchProjects();
                    },
                    onDelete: () => _deleteProject(project.id),
                    onTogglePublish: () => _togglePublish(project),
                  );
                },
              ),
            ),
      floatingActionButton: _projects.isNotEmpty
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/panel/projects/new');
                _fetchProjects();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _ProjectListItem extends StatelessWidget {
  final DesignerProject project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;

  const _ProjectListItem({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = project.displayCoverUrl;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          if (coverUrl.isNotEmpty)
            SmartImage(
              url: coverUrl,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: Container(
                height: 140,
                color: AppColors.border,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: project.isPublished
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project.isPublished ? 'Yayında' : 'Taslak',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: project.isPublished
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (project.projectType != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    project.projectType!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Düzenle'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onTogglePublish,
                        icon: Icon(
                          project.isPublished
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                        ),
                        label: Text(project.isPublished ? 'Gizle' : 'Yayınla'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                          foregroundColor: project.isPublished
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.1),
                        padding: const EdgeInsets.all(8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
