import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _items = [
  _FaqItem(
    'Evlumba nedir?',
    'Evlumba; ev sahipleri ile profesyonelleri bir araya getiren, ilham keşfi, '
        'tasarım kaydetme ve iletişim süreçlerini tek yerde toplayan bir platformdur.',
  ),
  _FaqItem(
    'Evlumba\'yı kullanmak ücretli mi?',
    'Temel kullanıcı akışları ücretsizdir. Platform içinde sunulan bazı profesyonel '
        'hizmetler veya ek özellikler ileride ücretli olabilir.',
  ),
  _FaqItem(
    'Nasıl hesap açabilirim?',
    'Kayıt sayfasından e-posta/şifre ile veya Google hesabınla kayıt olabilirsin. '
        'Kayıt sırasında ev sahibi ya da profesyonel rolünü seçebilirsin.',
  ),
  _FaqItem(
    'Profesyonel hesaba nasıl geçebilirim?',
    'Profil ayarları içindeki \'Profesyonel Ol\' sekmesine gidip hesabını profesyonel '
        'role yükseltebilirsin. Onay sonrası profilin profesyonel olarak görünür.',
  ),
  _FaqItem(
    'Destek ekibine nasıl ulaşırım?',
    'İletişim sayfasındaki formu doldurabilir veya doğrudan info@evlumba.com adresine '
        'e-posta gönderebilirsin.',
  ),
];

class SssScreen extends StatelessWidget {
  const SssScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sık Sorulan Sorular'),
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
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _FaqCard(item: _items[i]),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final _FaqItem item;
  const _FaqCard({required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _expanded
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(
                widget.item.answer,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
