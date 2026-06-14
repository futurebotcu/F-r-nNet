import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../widgets/legal_page.dart';

/// Topluluk Kuralları (Türkçe).
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: AppStrings.legalCommunityTitle,
      intro:
          'Topluluk kuralları, FırınNet\'i güvenli ve faydalı tutmak için var. '
          'Burası fırıncıların, ustaların ve tedarikçilerin mesleki bir ağı; '
          'paylaşımlarını buna göre yap.',
      sections: [
        LegalSection(
          '1. Saygılı ol',
          'Hakaret, aşağılama, tehdit, taciz, nefret söylemi ve hedef gösterme '
              'kabul edilmez. Eleştiri serbesttir; kişiselleştirmeden, mesleki '
              've yapıcı tut.',
        ),
        LegalSection(
          '2. Gerçek ve doğru içerik',
          'Sahte kimlik, yanıltıcı ilan, taklit hesap ve dolandırıcılık '
              'yasaktır. İlan ve fiyat paylaşımlarının gerçeği yansıtması '
              'beklenir.',
        ),
        LegalSection(
          '3. Spam ve istenmeyen içerik yok',
          'Tekrarlayan reklam, alakasız bağlantı yığını, toplu mesaj ve '
              'platform dışına yönlendiren istenmeyen içerik paylaşma. '
              'Paylaşımlar sektörle ilgili ve özgün olmalı.',
        ),
        LegalSection(
          '4. Mahremiyete saygı',
          'Başkalarının kişisel bilgilerini (telefon, adres, özel yazışma) '
              'izinsiz paylaşma. Kendi iletişim bilgini paylaşırken de dikkatli '
              'ol.',
        ),
        LegalSection(
          '5. Yasal ve güvenli kullanım',
          'Yasa dışı ürün/hizmet tanıtımı, telif ihlali ve güvenliği tehdit '
              'eden içerik paylaşılamaz. Gıda güvenliği konusunda yanıltıcı '
              'yönlendirme yapma.',
        ),
        LegalSection(
          '6. Bildir ve engelle',
          'Kurallara aykırı bir içerik veya kullanıcı görürsen içeriğin/'
              'profilin menüsünden "Şikayet et" ile bildirebilirsin. '
              'İstemediğin bir kullanıcıyı "Engelle" ile gizleyebilirsin; '
              'engellediğin kişi seninle iletişim kuramaz.',
        ),
        LegalSection(
          '7. Kurallara uyulmazsa',
          'Kuralları ihlal eden içerikler kaldırılabilir; tekrarlayan veya ağır '
              'ihlallerde hesap askıya alınabilir ya da kapatılabilir. Amaç '
              'cezalandırmak değil, topluluğu güvende tutmaktır.',
        ),
      ],
    );
  }
}
