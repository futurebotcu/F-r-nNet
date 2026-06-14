import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../widgets/legal_page.dart';

/// Hesap ve Veri Silme bilgilendirme ekranı (Türkçe).
///
/// Hesap silme işlemi Ayarlar → "Hesabımı sil" üzerinden yapılır; bu ekran
/// neyin nasıl silindiğini açıklar (Play / KVKK hesap-silme şeffaflığı).
class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: AppStrings.legalAccountDeletionTitle,
      intro:
          'Hesabını ve verilerini dilediğin zaman uygulama içinden silebilirsin. '
          'Bu işlem geri alınamaz.',
      sections: [
        LegalSection(
          'Nasıl silinir?',
          'Ayarlar → "Hesabımı sil" adımını izle. Güvenlik için onay olarak '
              '"HESABIMI SİL" yazman istenir. Onayladıktan sonra hesabın kalıcı '
              'olarak silinir ve oturumun kapatılır.',
        ),
        LegalSection(
          'Neler silinir?',
          'Hesabına bağlı profil bilgilerin (ad, hesap türü, şehir, meslek '
              'rozeti, e-posta), fırın paneli kayıtların (üretim, fire, '
              'reçeteler), bayi/müşteri kayıtların, ilan ve marketplace '
              'paylaşımların ve sosyal içeriklerin (gönderiler, yorumlar, '
              'beğeniler, gruplar, mesajlar) kalıcı olarak silinir.',
        ),
        LegalSection(
          'İstisnalar',
          'Yasal saklama yükümlülüğü bulunan kayıtlar, mevzuatın öngördüğü süre '
              'boyunca anonimleştirilmiş biçimde saklanabilir. Bu kayıtlar '
              'kimliğinle ilişkilendirilmez.',
        ),
        LegalSection(
          'Misafir kullanım',
          'Misafir (kayıtsız) modda bir hesap oluşturulmaz; bu modda tutulan '
              'veriler cihazında yereldir ve uygulama verilerini temizlediğinde '
              'silinir.',
        ),
        LegalSection(
          'Yardım',
          'Hesap silme ile ilgili bir sorun yaşarsan Destek ve Yardım '
              'bölümünden bize ulaşabilirsin.',
        ),
      ],
    );
  }
}
