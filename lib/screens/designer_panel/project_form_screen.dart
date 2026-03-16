import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/designer_project.dart';

const List<String> _projectTypes = [
  'Salon',
  'Mutfak',
  'Banyo',
  'Yatak Odası',
  'Çocuk Odası',
  'Ofis',
  'Koridor',
  'Bahçe',
  'Diğer',
];

const List<String> _budgetLevels = [
  'low',
  'medium',
  'high',
  'pro',
];

const Map<String, String> _budgetLabels = {
  'low': '₺ – Ekonomik',
  'medium': '₺₺ – Orta',
  'high': '₺₺₺ – Yüksek',
  'pro': 'Pro',
};

class ProjectFormScreen extends StatefulWidget {
  final String? projectId;

  const ProjectFormScreen({super.key, this.projectId});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _projectType;
  String? _budgetLevel;
  bool _isPublished = false;
  bool _loading = false;
  bool _saving = false;
  List<String> _uploadedImageUrls = [];
  bool _uploadingImages = false;

  bool get _isEditing => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _fetchProject();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchProject() async {
    setState(() => _loading = true);

    try {
      final data = await supabase
          .from('designer_projects')
          .select(
            'id, designer_id, title, project_type, location, description, tags, budget_level, cover_image_url, is_published, created_at, designer_project_images(image_url, sort_order)',
          )
          .eq('id', widget.projectId!)
          .single();

      final project = DesignerProject.fromJson(data);
      _titleController.text = project.title;
      _locationController.text = project.location ?? '';
      _descriptionController.text = project.description ?? '';
      _projectType = project.projectType;
      _budgetLevel = project.budgetLevel;
      _isPublished = project.isPublished;
      _uploadedImageUrls = project.images
          .map((i) => i.imageUrl)
          .where((u) => u.isNotEmpty)
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proje yüklenemedi.')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;

    setState(() => _uploadingImages = true);

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    for (final image in picked) {
      try {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last.toLowerCase();
        final path =
            'projects/${currentUser.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

        await supabase.storage.from('project-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

        final url =
            supabase.storage.from('project-images').getPublicUrl(path);
        setState(() => _uploadedImageUrls.add(url));
      } catch (e) {
        // Continue uploading remaining images
      }
    }

    setState(() => _uploadingImages = false);
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _saving = true);

    try {
      final projectData = {
        'designer_id': currentUser.id,
        'title': _titleController.text.trim(),
        'project_type': _projectType,
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'budget_level': _budgetLevel,
        'is_published': _isPublished,
        'cover_image_url': _uploadedImageUrls.isNotEmpty
            ? _uploadedImageUrls.first
            : null,
      };

      String projectId;
      if (_isEditing) {
        await supabase
            .from('designer_projects')
            .update(projectData)
            .eq('id', widget.projectId!);
        projectId = widget.projectId!;
      } else {
        final result = await supabase
            .from('designer_projects')
            .insert(projectData)
            .select('id')
            .single();
        projectId = (result as Map<String, dynamic>)['id'] as String;
      }

      // Upsert project images
      if (_uploadedImageUrls.isNotEmpty) {
        // Delete existing images first (for edit)
        if (_isEditing) {
          await supabase
              .from('designer_project_images')
              .delete()
              .eq('project_id', projectId);
        }

        await supabase.from('designer_project_images').insert(
          _uploadedImageUrls.asMap().entries.map((e) {
            return {
              'project_id': projectId,
              'image_url': e.value,
              'sort_order': e.key,
            };
          }).toList(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Proje güncellendi.' : 'Proje oluşturuldu.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Projeyi Düzenle' : 'Yeni Proje'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProject,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Images section
                    const Text(
                      'Fotoğraflar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_uploadedImageUrls.isNotEmpty) ...[
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _uploadedImageUrls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _uploadedImageUrls[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100,
                                      height: 100,
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _uploadedImageUrls.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _uploadingImages ? null : _pickAndUploadImages,
                      icon: _uploadingImages
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _uploadingImages
                            ? 'Yükleniyor...'
                            : 'Fotoğraf Ekle',
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Proje Bilgileri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Proje Başlığı *',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Başlık zorunlu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _projectType,
                      decoration: const InputDecoration(
                        labelText: 'Oda / Mekan Tipi',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _projectTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _projectType = val),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Konum',
                        hintText: 'ör. İstanbul, Türkiye',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _budgetLevel,
                      decoration: const InputDecoration(
                        labelText: 'Bütçe Seviyesi',
                        prefixIcon: Icon(Icons.attach_money_outlined),
                      ),
                      items: _budgetLevels.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(_budgetLabels[level] ?? level),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _budgetLevel = val),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        hintText: 'Proje hakkında bilgi verin...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Publish toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Yayınla',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Herkese açık yap',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPublished,
                            onChanged: (val) =>
                                setState(() => _isPublished = val),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProject,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Projeyi Güncelle'
                                    : 'Projeyi Oluştur',
                              ),
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
