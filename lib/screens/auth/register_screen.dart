import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'homeowner';
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _contactConsent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_contactConsent) {
      setState(() {
        _errorMessage = 'Devam etmek için iletişim onayı zorunlu.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim().isEmpty
          ? 'Yeni Kullanıcı'
          : _nameController.text.trim();

      // Kayıt isteğini web API üzerinden yap (admin API — rate limit yok)
      final client = http.Client();
      http.Response res;
      try {
        res = await client.post(
          Uri.parse('https://www.evlumba.com/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': _role}),
        ).timeout(const Duration(seconds: 15));
      } finally {
        client.close();
      }

      debugPrint('Register response ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200 || body['ok'] != true) {
        setState(() {
          _errorMessage = body['error'] as String? ?? 'Kayıt başarısız.';
        });
        return;
      }

      // Kullanıcı oluşturuldu, şimdi giriş yap
      await supabase.auth.signInWithPassword(email: email, password: password);

      if (mounted) {
        if (_role == 'designer') {
          context.go('/panel');
        } else {
          context.go('/home');
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _localizeAuthError(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (!_contactConsent) {
      setState(() {
        _errorMessage = 'Google ile kayıt için iletişim onayı zorunlu.';
      });
      return;
    }
    // Google Sign-In requires platform-specific setup:
    // Android: Add google-services.json and configure SHA-1
    // iOS: Add GoogleService-Info.plist and URL schemes
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.evlumba://login-callback/',
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _localizeAuthError(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Google ile kayıt başarısız.';
      });
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  String _localizeAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('user already registered') ||
        lower.contains('already exists')) {
      return 'Bu e-posta zaten kayıtlı. Giriş yapmayı dene.';
    }
    if (lower.contains('password should be at least')) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (lower.contains('invalid email')) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 16),
              Text(
                'Kayıt Ol',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Evlumba\'ya hoş geldiniz!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),

              // Role selection
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      title: 'Ev Sahibi',
                      description: 'İlham al, projeler incele',
                      isSelected: _role == 'homeowner',
                      onTap: () => setState(() => _role = 'homeowner'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      title: 'Profesyonel',
                      description: 'İşini sergile, müşteri kazan',
                      isSelected: _role == 'designer',
                      onTap: () => setState(() => _role = 'designer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Google Sign-Up
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _googleLoading ? null : _signUpWithGoogle,
                  icon: _googleLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata, size: 22),
                  label: Text(
                    _googleLoading
                        ? 'Yönlendiriliyor...'
                        : _role == 'designer'
                        ? 'Google ile profesyonel kayıt ol'
                        : 'Google ile kayıt ol',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'veya',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        hintText: 'ornek@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'E-posta zorunlu';
                        }
                        if (!value.contains('@')) {
                          return 'Geçerli bir e-posta girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Şifre zorunlu';
                        }
                        if (value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact consent
                    GestureDetector(
                      onTap: () =>
                          setState(() => _contactConsent = !_contactConsent),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _contactConsent,
                            onChanged: (val) =>
                                setState(() => _contactConsent = val ?? false),
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'İletişim sayfasını okudum ve onaylıyorum.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _role == 'designer'
                                    ? 'Profesyonel Hesap Oluştur'
                                    : 'Ev Sahibi Hesap Oluştur',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Zaten hesabın var mı? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Giriş Yap'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
