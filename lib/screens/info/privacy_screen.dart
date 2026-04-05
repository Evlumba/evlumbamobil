import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik Politikası'),
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
            'Son güncelleme: 14 Mart 2026',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _body(
            'Evlumba olarak kişisel verilerinizi korumayı önceliklendiriyoruz. '
            'Bu politika, platformu kullanırken hangi verileri topladığımızı, '
            'bu verileri neden işlediğimizi, kimlerle paylaşabildiğimizi ve '
            'tercihlerinizi nasıl yönetebileceğinizi açıklar.',
          ),
          _section('1. Topladığımız Veri Türleri'),
          _body(
            'Platform kullanımına bağlı olarak ad-soyad, e-posta, telefon, profil bilgileri, '
            'mesajlar, yorumlar, görseller, işlem ve ödeme bilgileri ile teknik kullanım verileri '
            '(IP, cihaz, tarayıcı, ziyaret zamanı, sayfa etkileşimleri gibi) toplayabiliriz. '
            'Ayrıca sosyal oturum açma, iş ortakları veya kamuya açık kaynaklar üzerinden '
            'tarafımıza iletilen sınırlı bilgileri de mevzuata uygun şekilde işleyebiliriz.',
          ),
          _section('2. Verileri Kullanma Amaçlarımız'),
          _body(
            'Verileri; hesabınızı oluşturmak, platform işlevlerini sağlamak, teklif/mesaj akışını '
            'yürütmek, güvenliği artırmak, kötüye kullanımı önlemek, müşteri desteği sunmak, '
            'deneyimi kişiselleştirmek ve hizmet kalitesini geliştirmek için kullanırız. '
            'Yasal yükümlülüklerin yerine getirilmesi, uyuşmazlık yönetimi ve hakların korunması '
            'gibi hukuki amaçlar için de veri işlenebilir.',
          ),
          _section('3. Verilerin Paylaşımı'),
          _body(
            'Verileriniz; yalnızca gerekli olduğu ölçüde altyapı, analiz, ödeme, güvenlik, '
            'iletişim ve destek sağlayıcılarıyla paylaşılabilir. Bazı profil/yorum içerikleri, '
            'platform doğası gereği diğer kullanıcılar tarafından görüntülenebilir. '
            'Yasal zorunluluk veya resmi makam talebi halinde, yürürlükteki mevzuat kapsamında '
            'ilgili kurumlara sınırlı açıklama yapılabilir.',
          ),
          _section('4. Çerezler ve Benzeri Teknolojiler'),
          _body(
            'Evlumba; oturum yönetimi, güvenlik, performans ölçümü, tercihlerin hatırlanması ve '
            'içerik iyileştirme amaçlarıyla zorunlu ve zorunlu olmayan çerezlerden yararlanabilir. '
            'Çerez tercihlerinizi tarayıcı ayarlarınızdan yönetebilir, silebilir veya engelleyebilirsiniz. '
            'Bazı çerezleri devre dışı bırakmanız halinde platformun bazı bölümleri beklenen şekilde '
            'çalışmayabilir.',
          ),
          _section('5. Haklarınız ve Tercihleriniz'),
          _body(
            'Uygulanabilir mevzuata göre verilerinize erişim, düzeltme, silme, işleme itiraz etme, '
            'taşınabilirlik talep etme ve pazarlama iletişimi tercihlerinizi güncelleme haklarına '
            'sahip olabilirsiniz. Hesap ayarlarınız üzerinden birçok tercihi doğrudan yönetebilir, '
            'kalan talepler için bizimle iletişime geçebilirsiniz.',
          ),
          _section('6. Saklama, Güvenlik ve Çocuklar'),
          _body(
            'Verileri, işleme amacının gerektirdiği süre boyunca ve yasal saklama yükümlülüklerine '
            'uygun şekilde tutarız. Yetkisiz erişim, kayıp veya kötüye kullanım risklerini azaltmak '
            'için teknik ve idari güvenlik önlemleri uygularız. Evlumba 18 yaş altına yönelik bir '
            'hizmet değildir. 18 yaş altına ait veri işlendiğinin fark edilmesi halinde, bu veriler '
            'makul süre içinde silinir.',
          ),
          _section('7. Politika Güncellemeleri'),
          _body(
            'Bu politika zaman zaman güncellenebilir. Önemli değişikliklerde platform içinde bildirim '
            'yayınlanır veya uygun kanallardan bilgilendirme yapılır.',
          ),
          _section('8. İletişim'),
          _body(
            'Gizlilik talepleriniz için bize info@evlumba.com adresinden ulaşabilirsiniz.',
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
