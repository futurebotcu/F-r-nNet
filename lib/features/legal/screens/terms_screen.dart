import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';

/// V1.3.5 — Kullanım Şartları (Türkçe).
///
/// Bu metin ürün ekibinin yazdığı taslak metindir; ticari kullanıma
/// çıkmadan önce **hukuki final kontrolü gerektirir**. Versiyon: V1 taslak.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.legalTermsTitle),
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
              title: '1. FırınNet Nedir?',
              body:
                  'FırınNet, fırıncılar, ustalar ve fırıncılığa bağlı toptancılar '
                  'için günlük üretim, bayi yönetimi, ilan paylaşımı ve mesleki '
                  'akış sunan bir mobil uygulamadır. Bu sözleşme, uygulamayı '
                  'kullanan kişi ile FırınNet sağlayıcısı arasındaki kullanım '
                  'şartlarını düzenler.',
            ),
            _Section(
              title: '2. Hesap ve Kullanıcı Sorumluluğu',
              body:
                  'Hesap oluşturan kullanıcı; girdiği e-posta, şifre, profil '
                  'bilgileri ve hesap türü (Ticari / Bireysel / Toptancı) '
                  'beyanından kendisi sorumludur. Şifrenin gizliliğinin '
                  'korunması kullanıcının yükümlülüğüdür. Üçüncü kişilere ait '
                  'bilgilerin izinsiz girilmesi yasaktır.',
            ),
            _Section(
              title: '3. İçerikler',
              body:
                  'Kullanıcının uygulamada paylaştığı reçete, üretim notu, '
                  'bayi kaydı, ilan ve sektör akışı içeriklerinin doğruluğu, '
                  'içeriklerin telif veya ticari sır niteliği taşıyıp taşımadığı '
                  'kullanıcının sorumluluğundadır. FırınNet, kullanıcı '
                  'içeriklerini kullanıcı adına saklar; kullanıcı kendi '
                  'içeriklerini her zaman silebilir.',
            ),
            _Section(
              title: '4. Yasak Kullanım',
              body:
                  'Uygulama; spam, hakaret, tehdit, dolandırıcılık, sahte '
                  'kimlik kullanımı, izinsiz reklam, üçüncü kişilerin kişisel '
                  'verilerini izinsiz toplama veya yayma amacıyla '
                  'kullanılamaz. Bu tür kullanım tespit edildiğinde hesap '
                  'askıya alınabilir veya kapatılabilir.',
            ),
            _Section(
              title: '5. Ticari Kayıtlar',
              body:
                  'Ticari hesaplar tarafından girilen üretim, fire, bayi '
                  'borç-alacak, fiyat, teslimat gibi kayıtlar kullanıcının '
                  'kendi muhasebe sorumluluğundadır. FırınNet, bu kayıtları '
                  'yedekli şekilde saklamayı taahhüt eder; ancak resmi '
                  'muhasebe / vergi belgesi yerine geçmez.',
            ),
            _Section(
              title: '6. Hizmetin Gelişim Aşamasında Olması',
              body:
                  'FırınNet aktif geliştirme aşamasındadır. Özellikler, '
                  'arayüz, fiyatlandırma ve servis seviyeleri zaman içinde '
                  'değişebilir. Önemli değişiklikler kullanıcıya uygulama '
                  'içinden bildirilir. Servisin geçici olarak '
                  'kullanılamamasından doğan dolaylı zararlardan '
                  'sorumluluk kabul edilmez.',
            ),
            _Section(
              title: '7. Hesap Kapatma',
              body:
                  'Kullanıcı dilediği zaman hesabını kapatma talebinde '
                  'bulunabilir. Hesap kapatıldığında kullanıcıya ait kişisel '
                  'profil verileri silinir; ancak yasal saklama '
                  'yükümlülükleri kapsamında kalan kayıtlar mevzuatın '
                  'öngördüğü süre boyunca saklanabilir.',
            ),
            _Section(
              title: '8. İletişim',
              body:
                  'Bu sözleşme veya uygulama hakkında sorularınız için '
                  'destek kanalı uygulama içinden duyurulur. İletişim '
                  'tercihlerin değişimi mail tabanlı bildirimlerle '
                  'yönetilir.',
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
