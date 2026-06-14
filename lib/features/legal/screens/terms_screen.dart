import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../widgets/legal_page.dart';

/// Kullanım Şartları (Türkçe).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: AppStrings.legalTermsTitle,
      intro:
          'Bu şartlar, FırınNet uygulamasını kullanan kişi ile FırınNet '
          'sağlayıcısı arasındaki ilişkiyi düzenler. Uygulamayı kullanarak bu '
          'şartları kabul etmiş olursun.',
      sections: [
        LegalSection(
          '1. FırınNet Nedir?',
          'FırınNet; fırıncılar, ustalar ve fırıncılığa bağlı toptancılar için '
              'günlük üretim, bayi yönetimi, ilan paylaşımı ve mesleki akış '
              'sunan bir dijital sektör ağıdır.',
        ),
        LegalSection(
          '2. Hesap ve Kullanıcı Sorumluluğu',
          'Hesap girişi Google hesabınla yapılır; Google hesabının '
              'güvenliğinden kendin sorumlusun. Profil bilgilerin ve hesap türü '
              '(Ticari / Bireysel / Toptancı) beyanın senin sorumluluğundadır. '
              'Üçüncü kişilere ait bilgilerin izinsiz girilmesi yasaktır.',
        ),
        LegalSection(
          '3. İçerikler',
          'Paylaştığın reçete, üretim notu, bayi kaydı, ilan ve sektör akışı '
              'içeriklerinin doğruluğu ve telif/ticari sır niteliği senin '
              'sorumluluğundadır. FırınNet içeriklerini senin adına saklar; '
              'içeriklerini her zaman silebilirsin.',
        ),
        LegalSection(
          '4. Topluluk ve Yasak Kullanım',
          'Uygulama; spam, hakaret, tehdit, dolandırıcılık, sahte kimlik, '
              'izinsiz reklam veya başkalarının kişisel verilerini izinsiz '
              'toplama/yayma amacıyla kullanılamaz. Ayrıntılar için Topluluk '
              'Kuralları geçerlidir. İhlal tespit edildiğinde içerik kaldırılır '
              've hesap askıya alınabilir veya kapatılabilir.',
        ),
        LegalSection(
          '5. Ticari Kayıtlar',
          'Ticari hesaplarca girilen üretim, fire, bayi borç-alacak, fiyat ve '
              'teslimat kayıtları kullanıcının kendi muhasebe sorumluluğundadır. '
              'FırınNet bu kayıtları yedekli saklamayı amaçlar; ancak resmi '
              'muhasebe / vergi belgesi yerine geçmez.',
        ),
        LegalSection(
          '6. Bildirme ve Engelleme',
          'Uygunsuz içerik veya kullanıcıları uygulama içinden bildirebilir '
              '(şikayet) ve istediğin kullanıcıyı engelleyebilirsin. Bildirimler '
              'incelenir ve gerektiğinde içerik veya hesap hakkında işlem '
              'yapılır.',
        ),
        LegalSection(
          '7. Hizmetin Gelişimi',
          'FırınNet aktif geliştirme aşamasındadır; özellikler ve arayüz zaman '
              'içinde gelişir. Önemli değişiklikler uygulama içinden bildirilir. '
              'Servisin geçici olarak kullanılamamasından doğan dolaylı '
              'zararlardan sorumluluk kabul edilmez.',
        ),
        LegalSection(
          '8. Hesap Kapatma',
          'Hesabını uygulama içinden (Ayarlar → Hesabımı sil) dilediğin zaman '
              'kapatabilirsin. Kapatıldığında kişisel profil verilerin silinir; '
              'yasal saklama yükümlülüğü kapsamındaki kayıtlar mevzuatın '
              'öngördüğü süre boyunca saklanabilir.',
        ),
      ],
    );
  }
}
