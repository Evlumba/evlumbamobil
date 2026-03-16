import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _cityController = TextEditingController();
  final _aboutController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _startingFromController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _specialtyController.dispose();
    _cityController.dispose();
    _aboutController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _startingFromController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, about, phone, contact_email, website, instagram, cover_photo_url, tags, starting_from, created_at',
          )
          .eq('id', currentUser.id)
          .maybeSingle();

      if (data != null) {
        final profile = Profile.fromJson(data as Map<String, dynamic>);
        _profile = profile;
        _fullNameController.text = profile.fullName ?? '';
        _businessNameController.text = profile.businessName ?? '';
        _specialtyController.text = profile.specialty ?? '';
        _cityController.text = profile.city ?? '';
        _aboutController.text = profile.about ?? '';
        _phoneController.text = profile.phone ?? '';
        _emailController.text = profile.contactEmail ?? '';
        _websiteController.text = profile.website ?? '';
        _instagramController.text = profile.instagram ?? '';
        _startingFromController.text = profile.startingFrom ?? '';
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _saving = true);

    try {
      await supabase.from('profiles').upsert({
        'id': currentUser.id,
        'full_name': _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        'business_name': _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        'specialty': _specialtyController.text.trim().isEmpty
            ? null
            : _specialtyController.text.trim(),
        'city': _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        'about': _aboutController.text.trim().isEmpty
            ? null
            : _aboutController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'contact_email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'website': _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        'instagram': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'starting_from': _startingFromController.text.trim().isEmpty
            ? null
            : _startingFromController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil güncellendi.'),
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

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _saving = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final path = 'avatars/${currentUser.id}.$ext';

      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final url = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', currentUser.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf güncellendi.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenemedi: $e'),
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
        title: const Text('Profili Düzenle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
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
                    // Avatar upload
                    Center(
                      child: GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.border,
                              backgroundImage: _profile?.avatarUrl != null &&
                                      _profile!.avatarUrl!.isNotEmpty
                                  ? NetworkImage(_profile!.avatarUrl!)
                                  : null,
                              child: _profile?.avatarUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 44,
                                      color: AppColors.textSecondary,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader(title: 'Kişisel Bilgiler'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Ad Soyad',
                      icon: Icons.person_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _businessNameController,
                      label: 'İşletme Adı',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _specialtyController,
                      label: 'Uzmanlık / Unvan',
                      hint: 'ör. İç Mimar, Dekorasyon Uzmanı',
                      icon: Icons.work_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _cityController,
                      label: 'Şehir',
                      icon: Icons.location_city_outlined,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _aboutController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Hakkımda',
                        hintText: 'Kendinizi tanıtın...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: 'İletişim'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Telefon',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailController,
                      label: 'İletişim E-postası',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Web Sitesi',
                      icon: Icons.language_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _instagramController,
                      label: 'Instagram',
                      hint: 'kullaniciadi (@ olmadan)',
                      icon: Icons.camera_alt_outlined,
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Hizmet Bilgileri'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _startingFromController,
                      label: 'Başlangıç Fiyatı',
                      hint: 'ör. ₺₺, ₺₺₺, 5000₺\'den başlayan',
                      icon: Icons.attach_money_outlined,
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Değişiklikleri Kaydet'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}
