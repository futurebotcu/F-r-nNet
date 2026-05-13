import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';

/// V1.3.5 — Gizlilik Politikası (Türkçe).
///
/// Bu metin ürün ekibinin yazdığı taslak metindir; ticari kullanıma
/// çıkmadan önce **hukuki final kontrolü gerektirir**. Versiyon: V1 taslak.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.legalPrivacyTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.authEntry);
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: const [
            _DraftBanner(),
            SizedBox(height: AppSpacing.l),
            _Section(
              title: '1. İşlenen Veriler',
              body:
                  'FırınNet kullanıcı hesabını oluştururken aşağıdaki '
                  'verileri işler: e-posta adresi, şifrelenmiş kimlik '
                  'doğrulama bilgisi, profil adı, hesap türü (Ticari / '
                  'Bireysel / Toptancı), meslek rozeti, şehir bilgisi. '
                  'Kullanıcı uygulamayı kullandıkça eklediği reçeteler, '
                  'üretim/fire kayıtları, bayi kayıtları, ilanlar ve sektör '
                  'akışı paylaşımları da hesabına bağlı olarak saklanır.',
            ),
            _Section(
              title: '2. İşleme Amacı',
              body:
                  'Veriler; (a) hesabın oluşturulup yönetilmesi, '
                  '(b) güvenli oturum açma ve şifre yenileme, (c) ticari '
                  'kayıtların yalnızca kullanıcıya görünür şekilde '
                  'saklanması, (d) sektör akışı ve ilan modüllerinin '
                  'çalışması, (e) kötüye kullanım tespiti ve hesap güvenliği '
                  'için işlenir.',
            ),
            _Section(
              title: '3. Altyapı ve Saklama',
              body:
                  'Kimlik doğrulama ve veri saklama altyapısı olarak '
                  'Supabase kullanılır. Veriler, hesap sahibinin yalnızca '
                  'kendi verilerini görmesini sağlayan satır-bazlı erişim '
                  'kuralları (RLS) ile korunur. FırınNet ekibi destek '
                  'amacıyla kişisel verilere erişmez; teknik gereklilik '
                  'durumunda erişim, en küçük yetki ve şeffaflık ilkesiyle '
                  'sınırlıdır.',
            ),
            _Section(
              title: '4. Üçüncü Taraf Paylaşımı',
              body:
                  'Kullanıcı verileri reklam, profil zenginleştirme veya '
                  'satış amacıyla üçüncü taraflara aktarılmaz. Yasal mercii '
                  'talebi olduğunda mevzuatın öngördüğü ölçüde paylaşım '
                  'yapılabilir.',
            ),
            _Section(
              title: '5. KVKK Kapsamında Kullanıcı Hakları',
              body:
                  '6698 sayılı KVKK kapsamında her kullanıcı; verilerinin '
                  'işlenip işlenmediğini öğrenme, hangi verilerin '
                  'işlendiğini öğrenme, düzeltme ve silme talep etme, '
                  'işlenmesine itiraz etme haklarına sahiptir. Bu haklar '
                  'destek kanalı üzerinden iletilen talep ile kullanılır.',
            ),
            _Section(
              title: '6. Çerez ve Cihaz Bilgisi',
              body:
                  'Mobil uygulama; oturum sürekliliği için cihazda küçük '
                  'tercih dosyaları (örn. misafir modu durumu, oturum '
                  'tokeni) tutar. Bu veriler reklam veya profil çıkarma '
                  'amacıyla kullanılmaz.',
            ),
            _Section(
              title: '7. Hesap Kapatma ve Veri Silme',
              body:
                  'Hesap kapatma talebinde bulunan kullanıcının kişisel '
                  'profil verileri sistemden silinir. Yasal saklama '
                  'yükümlülüğü olan kayıtlar, mevzuatın öngördüğü süre '
                  'boyunca anonimleştirilmiş şekilde saklanabilir.',
            ),
            _Section(
              title: '8. İletişim',
              body:
                  'KVKK kapsamındaki talepler ve gizlilik soruları için '
                  'iletişim kanalı uygulama içinden duyurulur. Bu '
                  'politikadaki değişiklikler kullanıcıya uygulama içinden '
                  'bildirilir.',
            ),
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.softGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.softGold.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: AppColors.softGold, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bu metin V1 taslaktır ve hukuki final kontrol gerektirir.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
