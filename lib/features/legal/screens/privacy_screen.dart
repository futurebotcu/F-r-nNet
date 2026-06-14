import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../widgets/legal_page.dart';

/// Gizlilik Politikası (Türkçe).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: AppStrings.legalPrivacyTitle,
      intro:
          'FırınNet, fırıncılar ve sektör kullanıcıları için bir dijital ağdır. '
          'Bu politika; hangi verileri, neden işlediğimizi ve bu veriler '
          'üzerindeki haklarını açıklar.',
      sections: [
        LegalSection(
          '1. İşlenen Veriler',
          'Hesabını oluştururken e-posta adresin, şifrelenmiş kimlik '
              'doğrulama bilgin, profil adın, hesap türün (Ticari / Bireysel / '
              'Toptancı), meslek rozetin ve şehir bilgin işlenir. Uygulamayı '
              'kullandıkça eklediğin reçeteler, üretim/fire kayıtları, bayi '
              'kayıtları, ilanlar ve sektör akışı paylaşımları da hesabına '
              'bağlı olarak saklanır.',
        ),
        LegalSection(
          '2. İşleme Amacı',
          'Veriler; hesabın oluşturulup yönetilmesi, güvenli oturum açma, '
              'ticari kayıtların yalnızca sana görünür şekilde saklanması, '
              'sektör akışı ve ilan modüllerinin çalışması ile kötüye kullanım '
              'tespiti ve hesap güvenliği için işlenir.',
        ),
        LegalSection(
          '3. Altyapı ve Saklama',
          'Kimlik doğrulama ve veri saklama altyapısı olarak Supabase '
              'kullanılır. Veriler, yalnızca kendi verilerini görmeni sağlayan '
              'satır-bazlı erişim kuralları (RLS) ile korunur. FırınNet ekibi '
              'destek amacıyla kişisel verilere erişmez; teknik gereklilik '
              'durumunda erişim, en küçük yetki ilkesiyle sınırlıdır.',
        ),
        LegalSection(
          '4. Üçüncü Taraf Paylaşımı',
          'Verilerin reklam, profil zenginleştirme veya satış amacıyla '
              'üçüncü taraflara aktarılmaz. Yalnızca yetkili merci talebi '
              'olduğunda, mevzuatın öngördüğü ölçüde paylaşım yapılabilir.',
        ),
        LegalSection(
          '5. Giriş Yöntemi',
          'FırınNet\'e giriş Google hesabınla yapılır. Google üzerinden '
              'yalnızca kimliğini doğrulamak için gereken temel bilgiler '
              '(e-posta, ad) alınır; Google şifren FırınNet ile paylaşılmaz.',
        ),
        LegalSection(
          '6. KVKK Kapsamında Hakların',
          '6698 sayılı KVKK kapsamında; verilerinin işlenip işlenmediğini '
              'öğrenme, hangi verilerin işlendiğini öğrenme, düzeltme ve silme '
              'talep etme, işlenmesine itiraz etme haklarına sahipsin. Bu '
              'haklarını destek kanalı üzerinden kullanabilirsin.',
        ),
        LegalSection(
          '7. Cihaz Bilgisi',
          'Uygulama; oturum sürekliliği için cihazda küçük tercih dosyaları '
              '(örn. misafir modu durumu, oturum bilgisi) tutar. Bu veriler '
              'reklam veya profil çıkarma amacıyla kullanılmaz.',
        ),
        LegalSection(
          '8. Hesap ve Veri Silme',
          'Hesabını uygulama içinden silebilirsin. Hesabını sildiğinde '
              'profilin ve sana bağlı kayıtlar kalıcı olarak silinir. Yasal '
              'saklama yükümlülüğü olan kayıtlar, mevzuatın öngördüğü süre '
              'boyunca anonimleştirilmiş şekilde saklanabilir.',
        ),
      ],
    );
  }
}
