import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/search_filters.dart';
import '../../widgets/search_filter_sheet.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Profile? _profile;
  Map<String, dynamic> _aboutDetails = const {};
  List<String> _professionalTypes = [];
  List<String> _services = [];
  List<String> _projectTypes = [];
  List<String> _serviceAreas = [];
  List<String> _styleExpertise = [];
  List<String> _cities = [];
  List<String> _serviceRegions = [];
  List<String> _workingModels = [];
  String? _startingBudget;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _aboutController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, about, phone, contact_email, website, instagram, cover_photo_url, tags, starting_from, about_details, created_at',
          )
          .eq('id', currentUser.id)
          .maybeSingle();

      if (data != null) {
        final profile = Profile.fromJson(data);
        _profile = profile;
        _aboutDetails =
            Map<String, dynamic>.from(data['about_details'] as Map? ?? {});
        _fullNameController.text = profile.fullName ?? '';
        _businessNameController.text = profile.businessName ?? '';
        _aboutController.text = profile.about ?? '';
        _phoneController.text = profile.phone ?? '';
        _emailController.text = profile.contactEmail ?? '';
        _websiteController.text = profile.website ?? '';
        _instagramController.text = profile.instagram ?? '';
        _professionalTypes = [...profile.professionalTypes];
        _services = [...profile.services];
        _projectTypes = [...profile.projectTypes];
        _serviceAreas = [...profile.serviceAreas];
        _styleExpertise = [...profile.styleExpertise];
        _cities = profile.cities.isNotEmpty
            ? [...profile.cities]
            : [
                if ((profile.city ?? '').trim().isNotEmpty) profile.city!.trim()
              ];
        _serviceRegions = [...profile.serviceRegions];
        _workingModels = [...profile.workingModels];
        _startingBudget = profile.startingBudget;
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateGeneralSelections()) return;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _saving = true);

    try {
      final profileGeneral = <String, dynamic>{
        'displayName': _fullNameController.text.trim(),
        if (_businessNameController.text.trim().isNotEmpty)
          'businessName': _businessNameController.text.trim(),
        if (_profile?.avatarUrl != null) 'profileImageUrl': _profile!.avatarUrl,
        'professionalTypes': _professionalTypes,
        'services': _services,
        'projectTypes': _projectTypes,
        'serviceAreas': _serviceAreas,
        'styleExpertise': _styleExpertise,
        'city': _cities.isNotEmpty ? _cities.first : null,
        'cities': _cities,
        'serviceRegions': _serviceRegions,
        if (_startingBudget != null) 'startingBudget': _startingBudget,
        'workingModels': _workingModels,
        'tags': _profile?.tags ?? const <String>[],
      };
      final nextAboutDetails = Map<String, dynamic>.from(_aboutDetails)
        ..['profileGeneral'] = profileGeneral;

      await supabase.from('profiles').upsert({
        'id': currentUser.id,
        'full_name': _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        'business_name': _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        'specialty':
            _professionalTypes.isEmpty ? null : _professionalTypes.join(' • '),
        'city': _cities.isEmpty ? null : _cities.first,
        'about': _aboutController.text.trim().isEmpty
            ? null
            : _aboutController.text.trim(),
        'about_details': nextAboutDetails,
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
        'starting_from': _startingBudget,
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

  bool _validateGeneralSelections() {
    final missing = <String>[];
    if (_fullNameController.text.trim().length < 2) {
      missing.add('Ad / Profil adı');
    }
    if (_professionalTypes.isEmpty) missing.add('Profesyonel Türü');
    if (_services.isEmpty) missing.add('Hizmetler');
    if (_projectTypes.isEmpty) missing.add('Proje Tipleri');
    if (_serviceAreas.isEmpty) missing.add('Hizmet Alanları');
    if (_cities.isEmpty) missing.add('Şehir');
    if (_serviceRegions.isEmpty) missing.add('Hizmet Bölgeleri');

    if (missing.isEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Zorunlu alanları tamamlayın: ${missing.join(', ')}'),
        backgroundColor: AppColors.error,
      ),
    );
    return false;
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
          .update({'avatar_url': url}).eq('id', currentUser.id);

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
                      label: 'Tam Ad / Profil Adı *',
                      icon: Icons.person_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _businessNameController,
                      label: 'İşletme Adı',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 12),
                    SearchMultiSelectSection(
                      title: 'Profesyonel Türü *',
                      selectedValues: _professionalTypes,
                      options: SearchFilters.professionalOptions,
                      initiallyExpanded: _professionalTypes.isEmpty,
                      onToggle: (value) => setState(() {
                        _professionalTypes = _toggle(_professionalTypes, value);
                        if (_professionalTypes.length > 3) {
                          _professionalTypes =
                              _professionalTypes.take(3).toList();
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    SearchMultiSelectSection(
                      title: 'Hizmetler *',
                      selectedValues: _services,
                      options: SearchFilters.serviceOptions,
                      onToggle: (value) => setState(
                        () => _services = _toggle(_services, value),
                      ),
                      onSetValues: (values) =>
                          setState(() => _services = values),
                    ),
                    SearchMultiSelectSection(
                      title: 'Proje Tipleri *',
                      selectedValues: _projectTypes,
                      options: SearchFilters.projectTypeOptions,
                      onToggle: (value) => setState(
                        () => _projectTypes = _toggle(_projectTypes, value),
                      ),
                      onSetValues: (values) =>
                          setState(() => _projectTypes = values),
                    ),
                    SearchMultiSelectSection(
                      title: 'Hizmet Alanları *',
                      selectedValues: _serviceAreas,
                      options: SearchFilters.roomOptions,
                      onToggle: (value) => setState(
                        () => _serviceAreas = _toggle(_serviceAreas, value),
                      ),
                      onSetValues: (values) =>
                          setState(() => _serviceAreas = values),
                    ),
                    SearchMultiSelectSection(
                      title: 'Stil Uzmanlıkları',
                      selectedValues: _styleExpertise,
                      options: SearchFilters.styleOptions,
                      onToggle: (value) => setState(
                        () => _styleExpertise = _toggle(_styleExpertise, value),
                      ),
                      onSetValues: (values) =>
                          setState(() => _styleExpertise = values),
                    ),
                    SearchMultiSelectSection(
                      title: 'Şehir *',
                      selectedValues: _cities,
                      options: SearchFilters.cityOptions,
                      onToggle: (value) => setState(
                        () => _cities = _toggle(_cities, value),
                      ),
                      onSetValues: (values) => setState(() => _cities = values),
                    ),
                    SearchMultiSelectSection(
                      title: 'Hizmet Bölgeleri *',
                      selectedValues: _serviceRegions,
                      options: SearchFilters.serviceRegionOptions,
                      onToggle: (value) => setState(
                        () => _serviceRegions = _toggle(_serviceRegions, value),
                      ),
                      onSetValues: (values) =>
                          setState(() => _serviceRegions = values),
                    ),
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
                    DropdownButtonFormField<String>(
                      initialValue: _startingBudget,
                      decoration: const InputDecoration(
                        labelText: 'Başlangıç Bütçesi',
                        prefixIcon: Icon(Icons.attach_money_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Seçilmedi'),
                        ),
                        ...SearchFilters.startingBudgetOptions.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _startingBudget = value),
                    ),
                    const SizedBox(height: 12),
                    SearchMultiSelectSection(
                      title: 'Çalışma Modeli',
                      selectedValues: _workingModels,
                      options: const [
                        'Ücretsiz Ön Görüşme',
                        'Saatlik Danışmanlık',
                        'Proje Bazlı Ücret',
                        'm² Bazlı Ücret',
                        'Paket Hizmet',
                        'Anahtar Teslim',
                        'Teklif Üzerinden',
                      ],
                      onToggle: (value) => setState(
                        () => _workingModels = _toggle(_workingModels, value),
                      ),
                      onSetValues: (values) =>
                          setState(() => _workingModels = values),
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

  List<String> _toggle(List<String> values, String value) {
    return values.contains(value)
        ? values.where((item) => item != value).toList()
        : [...values, value];
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
