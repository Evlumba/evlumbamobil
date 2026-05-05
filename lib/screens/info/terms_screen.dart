import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanım Koşulları'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Son güncelleme: 5 Mayıs 2026',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _body(
            'Evlumba; ev sahipleri ile profesyonellerin profil, proje, yorum, forum ve mesajlaşma '
            'özellikleri üzerinden iletişim kurduğu bir platformdur. Hesap oluşturan veya giriş yapan '
            'her kullanıcı bu koşulları ve topluluk kurallarını kabul eder.',
          ),
          _section('1. Sıfır Tolerans Politikası'),
          _body(
            'Sakıncalı içerik, taciz, tehdit, nefret söylemi, ayrımcılık, müstehcen veya yasa dışı içerik, '
            'spam, dolandırıcılık ve diğer kullanıcıları hedef alan kötüye kullanım davranışlarına sıfır '
            'tolerans uygulanır. Bu kuralları ihlal eden içerikler kaldırılabilir; ihlali yapan hesaplar '
            'uyarı, geçici kısıtlama veya kalıcı kapatma dahil yaptırımlara tabi olabilir.',
          ),
          _section('2. Kullanıcı İçerikleri'),
          _body(
            'Kullanıcılar forum mesajı, blog yorumu, değerlendirme, profil bilgisi, proje görseli ve '
            'mesajlaşma içeriklerinden sorumludur. Paylaşılan içeriklerin hukuka, üçüncü kişi haklarına '
            've Evlumba topluluk kurallarına uygun olması gerekir.',
          ),
          _section('3. Filtreleme, Şikayet ve Engelleme'),
          _body(
            'Evlumba sakıncalı ifadeleri azaltmak için içerik filtreleme uygular. Kullanıcılar uygulama '
            'içindeki şikayet araçlarıyla sakıncalı içerikleri bildirebilir ve kötüye kullanım davranışı '
            'gösteren kullanıcıları engelleyebilir. Engellenen kullanıcının içerikleri engelleyen '
            'kullanıcının akışından hemen gizlenir ve bildirim geliştirici ekibe iletilir.',
          ),
          _section('4. Moderasyon Süresi'),
          _body(
            'Evlumba ekibi sakıncalı içerik bildirimlerini 24 saat içinde inceler. İhlal doğrulanırsa '
            'ilgili içerik kaldırılır ve ihlali yapan kullanıcı platformdan uzaklaştırılabilir.',
          ),
          _section('5. Hesap ve Güvenlik'),
          _body(
            'Kullanıcılar hesap bilgilerinin güvenliğinden sorumludur. Başkasının hesabına yetkisiz erişim, '
            'kimlik taklidi veya platform güvenliğini zedeleyen davranışlar yasaktır.',
          ),
          _section('6. İletişim'),
          _body(
            'Koşullar, şikayetler ve hesap güvenliği talepleri için info@evlumba.com adresinden bize '
            'ulaşabilirsiniz.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );

  static Widget _body(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          color: AppColors.textSecondary,
        ),
      );
}
