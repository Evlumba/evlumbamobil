import '../../widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() => _loading = true);

    try {
      final data = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, about, phone, contact_email, cover_photo_url, tags, starting_from, created_at',
          )
          .eq('id', currentUser.id)
          .maybeSingle();

      setState(() {
        if (data != null) {
          _profile = Profile.fromJson(data as Map<String, dynamic>);
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  void _openSettings(String tab) {
    context.push('/profile-settings', extra: tab);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUser = supabase.auth.currentUser;
    final profile = _profile;
    final email = currentUser?.email ?? '';
    final isDesigner = profile?.isDesigner == true;
    final isHomeowner = !isDesigner;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Profile header ──────────────────────────────────
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                          ? SmartImage(url: profile.avatarUrl, fit: BoxFit.cover)
                          : _AvatarFallback(name: profile?.displayName ?? email.substring(0, 1)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?.displayName ?? 'Kullanıcı',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    if (profile?.specialty != null) ...[
                      const SizedBox(height: 4),
                      Text(profile!.specialty!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                    if (profile?.city != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text(profile!.city!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDesigner ? AppColors.primary.withOpacity(0.1) : AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isDesigner ? 'Tasarımcı' : 'Ev Sahibi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDesigner ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Profil Ayarları ─────────────────────────────────
              _SectionHeader(title: 'Profil Ayarları'),
              Container(
                color: AppColors.surface,
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      title: 'Genel',
                      subtitle: 'Profil fotoğrafı, ad, şehir',
                      onTap: () => _openSettings('general'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: Icons.contact_mail_outlined,
                      title: 'İletişim',
                      subtitle: 'E-posta, telefon, sosyal medya',
                      onTap: () => _openSettings('contact'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: Icons.lock_outline,
                      title: 'Güvenlik',
                      subtitle: 'Şifre değiştir',
                      onTap: () => _openSettings('security'),
                    ),
                    if (isDesigner) ...[
                      const Divider(height: 1, indent: 56),
                      _MenuItem(
                        icon: Icons.image_outlined,
                        title: 'Kapak Fotoğrafı',
                        subtitle: 'Profil kapak görseli',
                        onTap: () => _openSettings('cover-photo'),
                      ),
                    ],
                    if (isHomeowner) ...[
                      const Divider(height: 1, indent: 56),
                      _MenuItem(
                        icon: Icons.star_outline_rounded,
                        title: 'Profesyonel Ol',
                        subtitle: 'Hesabını yükselt',
                        onTap: () => _openSettings('professional'),
                        accent: true,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Diğer ──────────────────────────────────────────
              if (isDesigner) ...[
                _SectionHeader(title: 'Tasarımcı'),
                Container(
                  color: AppColors.surface,
                  child: _MenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Tasarımcı Paneli',
                    subtitle: 'Profilini düzenle, projelerini yönet',
                    onTap: () => context.push('/panel'),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              _SectionHeader(title: 'Genel'),
              Container(
                color: AppColors.surface,
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.chat_bubble_outline,
                      title: 'Mesajlarım',
                      onTap: () => context.go('/messages'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: Icons.help_outline,
                      title: 'Yardım',
                      subtitle: 'Sık sorulan sorular',
                      onTap: () => context.push('/sss'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Container(
                color: AppColors.surface,
                child: _MenuItem(
                  icon: Icons.logout_outlined,
                  title: 'Çıkış Yap',
                  color: AppColors.error,
                  onTap: _signOut,
                ),
              ),

              const SizedBox(height: 32),
              const Text('Evlumba v1.0.3', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'K';
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;
  final bool accent;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? (accent ? const Color(0xFF4F46E5) : AppColors.textPrimary);
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent
              ? const Color(0xFF4F46E5).withOpacity(0.1)
              : (color != null ? color!.withOpacity(0.1) : AppColors.primary.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: itemColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: itemColor, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: Icon(Icons.arrow_forward_ios, size: 13, color: color ?? AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
