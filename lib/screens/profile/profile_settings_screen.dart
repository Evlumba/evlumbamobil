import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';

const _kPrimary = Color(0xFF0E5A3A);

class ProfileSettingsScreen extends StatefulWidget {
  final String tab; // general | contact | security | professional

  const ProfileSettingsScreen({super.key, required this.tab});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _message;

  // general
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // contact
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();

  // security
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // professional
  bool _upgradeLoading = false;
  String _role = 'homeowner';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _cityCtrl, _emailCtrl, _phoneCtrl, _addressCtrl,
      _websiteCtrl, _instagramCtrl, _facebookCtrl, _linkedinCtrl,
      _currentPwCtrl, _newPwCtrl, _confirmPwCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;
      final data = await supabase
          .from('profiles')
          .select('full_name, role, city, phone, contact_email, address, website, instagram, facebook, linkedin')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        _nameCtrl.text = (data['full_name'] as String?) ?? '';
        _cityCtrl.text = (data['city'] as String?) ?? '';
        _emailCtrl.text = (data['contact_email'] as String?) ?? '';
        _phoneCtrl.text = (data['phone'] as String?) ?? '';
        _addressCtrl.text = (data['address'] as String?) ?? '';
        _websiteCtrl.text = (data['website'] as String?) ?? '';
        _instagramCtrl.text = (data['instagram'] as String?) ?? '';
        _facebookCtrl.text = (data['facebook'] as String?) ?? '';
        _linkedinCtrl.text = (data['linkedin'] as String?) ?? '';
        _role = (data['role'] as String?) ?? 'homeowner';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveGeneral() async {
    setState(() { _saving = true; _message = null; });
    try {
      await supabase.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      }).eq('id', _userId);
      if (mounted) setState(() => _message = 'Kaydedildi ✓');
    } catch (e) {
      if (mounted) setState(() => _message = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveContact() async {
    setState(() { _saving = true; _message = null; });
    try {
      await supabase.from('profiles').update({
        'contact_email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'facebook': _facebookCtrl.text.trim(),
        'linkedin': _linkedinCtrl.text.trim(),
      }).eq('id', _userId);
      if (mounted) setState(() => _message = 'Kaydedildi ✓');
    } catch (e) {
      if (mounted) setState(() => _message = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text.trim();
    final newPw = _newPwCtrl.text.trim();
    final confirm = _confirmPwCtrl.text.trim();
    if (current.isEmpty || newPw.isEmpty) {
      setState(() => _message = 'Tüm alanları doldurun.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _message = 'Yeni şifreler eşleşmiyor.');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _message = 'Şifre en az 6 karakter olmalı.');
      return;
    }
    setState(() { _saving = true; _message = null; });
    try {
      final authEmail = supabase.auth.currentUser?.email ?? '';
      final verify = await supabase.auth.signInWithPassword(email: authEmail, password: current);
      if (verify.user == null) {
        setState(() => _message = 'Mevcut şifre hatalı.');
        return;
      }
      await supabase.auth.updateUser(UserAttributes(password: newPw));
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      if (mounted) setState(() => _message = 'Şifre güncellendi ✓');
    } catch (e) {
      if (mounted) setState(() => _message = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upgradeToProfessional() async {
    setState(() { _upgradeLoading = true; _message = null; });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() => _message = 'Oturum bulunamadı.');
        return;
      }
      final res = await http.post(
        Uri.parse('https://evlumba.com/api/profile/upgrade-role'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      if (res.statusCode == 200) {
        setState(() { _role = 'designer'; _message = 'Profesyonel hesap aktif edildi ✓'; });
      } else {
        setState(() => _message = 'Hesap güncellenemedi.');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _upgradeLoading = false);
    }
  }

  String get _title {
    switch (widget.tab) {
      case 'contact': return 'İletişim';
      case 'security': return 'Güvenlik';
      case 'professional': return 'Profesyonel Ol';
      default: return 'Genel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.tab == 'general') ..._buildGeneral(),
                  if (widget.tab == 'contact') ..._buildContact(),
                  if (widget.tab == 'security') ..._buildSecurity(),
                  if (widget.tab == 'professional') ..._buildProfessional(),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _message!.contains('✓')
                            ? _kPrimary.withOpacity(0.08)
                            : AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.contains('✓') ? _kPrimary : AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildGeneral() => [
    _Field(label: 'Ad Soyad', controller: _nameCtrl),
    const SizedBox(height: 14),
    _Field(label: 'Şehir', controller: _cityCtrl),
    const SizedBox(height: 24),
    _SaveButton(saving: _saving, onPressed: _saveGeneral),
  ];

  List<Widget> _buildContact() => [
    _Field(label: 'İletişim E-posta', controller: _emailCtrl, keyboard: TextInputType.emailAddress),
    const SizedBox(height: 14),
    _Field(label: 'Telefon', controller: _phoneCtrl, keyboard: TextInputType.phone),
    const SizedBox(height: 14),
    _Field(label: 'Adres', controller: _addressCtrl),
    const SizedBox(height: 14),
    _Field(label: 'Website', controller: _websiteCtrl, keyboard: TextInputType.url),
    const SizedBox(height: 14),
    _Field(label: 'Instagram', controller: _instagramCtrl, prefix: '@'),
    const SizedBox(height: 14),
    _Field(label: 'Facebook', controller: _facebookCtrl),
    const SizedBox(height: 14),
    _Field(label: 'LinkedIn', controller: _linkedinCtrl),
    const SizedBox(height: 24),
    _SaveButton(saving: _saving, onPressed: _saveContact),
  ];

  List<Widget> _buildSecurity() => [
    _PasswordField(label: 'Mevcut Şifre', controller: _currentPwCtrl, obscure: _obscureCurrent, onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent)),
    const SizedBox(height: 14),
    _PasswordField(label: 'Yeni Şifre', controller: _newPwCtrl, obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew)),
    const SizedBox(height: 14),
    _PasswordField(label: 'Yeni Şifre (Tekrar)', controller: _confirmPwCtrl, obscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
    const SizedBox(height: 24),
    _SaveButton(saving: _saving, onPressed: _changePassword, label: 'Şifreyi Güncelle'),
  ];

  List<Widget> _buildProfessional() {
    if (_role == 'designer' || _role == 'designer_pending') {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _kPrimary.withOpacity(0.07), borderRadius: BorderRadius.circular(16)),
          child: const Row(children: [
            Icon(Icons.check_circle_rounded, color: _kPrimary, size: 24),
            SizedBox(width: 12),
            Expanded(child: Text('Hesabın zaten profesyonel!', style: TextStyle(fontWeight: FontWeight.w600, color: _kPrimary))),
          ]),
        ),
      ];
    }
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Profesyonel hesaba geç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Portföyünü öne çıkar, mesaj ve teklif akışına sahip ol.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          _Chip('Portföy vitrini ile daha fazla görünürlük'),
          const SizedBox(height: 8),
          _Chip('Profilden doğrudan mesaj ve teklif alma'),
          const SizedBox(height: 8),
          _Chip('Ürünlerini etiketleyerek anında kazan'),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _upgradeLoading ? null : () => _showUpgradeConfirm(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _upgradeLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Profesyonel Ol', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ];
  }

  void _showUpgradeConfirm() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesap Yükselt'),
        content: const Text('Hesabın profesyonel hesaba dönüştürülecek. Onaylıyor musun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () { Navigator.pop(ctx, true); _upgradeToProfessional(); },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final String? prefix;

  const _Field({required this.label, required this.controller, this.keyboard, this.prefix});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          prefixText: prefix,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0E5A3A), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({required this.label, required this.controller, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0E5A3A), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20), onPressed: onToggle),
        ),
      ),
    ]);
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onPressed;
  final String label;

  const _SaveButton({required this.saving, required this.onPressed, this.label = 'Kaydet'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E5A3A),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
