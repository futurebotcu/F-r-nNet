// Destek ve Yardım — SSS (sık sorulan sorular) + e-posta ile iletişim.
//
// SSS collapsible (ExpansionTile) premium kartta; "Bize ulaşın" bölümü
// url_launcher mailto: ile destek e-postasını açar (cihazda mail uygulaması
// yoksa Türkçe snackbar + adres gösterir). Kişisel veri basılmaz.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}

const List<_Faq> _faqs = [
  _Faq(
    'FırınNet nedir?',
    'FırınNet; fırıncılar, ustalar ve tedarikçiler için bir dijital sektör '
        'ağıdır. Sektör akışı, gruplar, ilanlar ve işini takip etmen için '
        'araçlar tek yerde toplanır.',
  ),
  _Faq(
    'Google ile giriş yapmak zorunlu mu?',
    'Hesap açmak için Google ile giriş kullanılır. Dilersen misafir olarak da '
        'keşfedebilirsin; ancak paylaşım yapmak ve kayıtlarını saklamak için '
        'giriş gerekir.',
  ),
  _Faq(
    'Misafir olarak neler yapabilirim?',
    'Misafir modda akışı ve ilanları keşfedebilirsin. Gönderi/yorum, kayıt ve '
        'kişisel veri saklama gibi işlemler için Google ile giriş gerekir.',
  ),
  _Faq(
    'Profilimi nasıl tamamlarım?',
    'Google ile giriş yaptıktan sonra hesap türünü (Fırın / Bireysel / '
        'Toptancı), adını, şehrini ve meslek rozetini seçersin. Bu bilgiler '
        'profilinde görünür ve sana uygun araçların açılmasını sağlar.',
  ),
  _Faq(
    'Paylaşım, beğeni ve yorum nasıl çalışır?',
    'Toplulukta gönderi paylaşır, başkalarının paylaşımlarını beğenir ve '
        'yorum yazarsın. Paylaşım için Google ile giriş gerekir; misafir modda '
        'akışı görüntüleyebilirsin.',
  ),
  _Faq(
    'İçerik nasıl bildirilir?',
    'Bir gönderi, yorum veya profilin sağ üst menüsünden "Şikayet et" '
        'seçeneğiyle bildirebilirsin. Bildirimler incelenir ve gerektiğinde '
        'işlem yapılır.',
  ),
  _Faq(
    'Bir kullanıcıyı nasıl engellerim?',
    'Kullanıcının profil menüsünden "Engelle" diyebilirsin. Engellenen kişi '
        'seninle iletişim kuramaz. Engeli Ayarlar → Engellenen kullanıcılar '
        'bölümünden kaldırabilirsin.',
  ),
  _Faq(
    'Hesabımı nasıl silebilirim?',
    'Ayarlar → "Hesabımı sil" adımını izle. Onay için "HESABIMI SİL" yazman '
        'istenir; işlem geri alınamaz ve verilerin kalıcı olarak silinir.',
  ),
  _Faq(
    'Verilerim nasıl korunur?',
    'Verilerin yalnızca sana görünür şekilde, hesabına özel olarak saklanır. '
        'Ayrıntılar için Gizlilik Politikası bölümüne bakabilirsin.',
  ),
];

/// Bayi Defteri / uygulama kullanımı how-to başlıkları (ikinci SSS kartı).
const List<_Faq> _ledgerFaqs = [
  _Faq(
    'Bayi Defteri nedir?',
    'Bayi Defteri; teslimat, iade, tahsilat ve açık bakiyeni telefondan '
        'takip etmen için hazırlanmış bir araçtır. Panel sekmesinden açılır. '
        'Kayıtlar yalnızca sana görünür; resmi muhasebe yerine geçmez, takip '
        'amaçlıdır.',
  ),
  _Faq(
    'Bayi nasıl eklenir?',
    'Bayi Defteri → Bayiler sekmesinde "İlk bayiyi ekle" ile bayinin adını '
        '(istersen bölge, telefon, çalışma tipini) girersin. Sonra o bayiye '
        'teslimat ve tahsilat işleyebilirsin.',
  ),
  _Faq(
    'Hareket nasıl eklenir?',
    'Bayi detayında "Ürün Ver" (teslimat), "Ödeme Al" (tahsilat) veya '
        '"İade Al" ile işlem girersin. Tutar ve tarihi yazarsın; açık bakiye '
        'otomatik güncellenir. Çift kayıt olmaması için kaydet anında buton '
        'kilitlenir.',
  ),
  _Faq(
    'Teslimat, tahsilat ve iade ne demek?',
    'Teslimat bayinin borcunu artırır (ürün verdin), tahsilat borcu azaltır '
        '(ödeme aldın), iade ise verdiğin üründen geri geleni düşer. Açık '
        'bakiye bu üçünün sonucudur.',
  ),
  _Faq(
    'Günlük Özet / Gün Sonu ne işe yarar?',
    'Gün Sonu, o günün teslimat ve tahsilat toplamını gösteren bir özettir. '
        'Ayrıca kapatman gereken bir şey yok; yeni gün açıldığında o günün '
        'verisi otomatik gelir.',
  ),
  _Faq(
    'Rapor/PDF nasıl oluşturulur ve paylaşılır?',
    'Bayi detayı veya Raporlar ekranından özet çıkarırsın; panoya kopyalar, '
        'düz metin (WhatsApp/SMS) ya da PDF olarak paylaşabilirsin. PDF dosya '
        'adı bayi adı ve tarihle oluşur, WhatsApp\'tan doğrudan gönderebilirsin.',
  ),
];

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppStrings.supportEmail,
      query: 'subject=${Uri.encodeComponent(AppStrings.supportEmailSubject)}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _showMailError(context);
      }
    } catch (_) {
      if (context.mounted) _showMailError(context);
    }
  }

  void _showMailError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppStrings.supportMailError}${AppStrings.supportEmail}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.supportTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.l,
                AppSpacing.pageH,
                0,
              ),
              child: Text(
                AppStrings.supportSubtitle,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // ───── Sık sorulan sorular
            const SectionLabel(title: AppStrings.supportFaqSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _faqs.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 0,
                            indent: AppSpacing.l,
                            endIndent: AppSpacing.l,
                            color: AppColors.borderHairline,
                          ),
                        _FaqItem(faq: _faqs[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ───── Bayi Defteri ve kullanım
            const SectionLabel(title: 'Bayi Defteri ve kullanım'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _ledgerFaqs.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 0,
                            indent: AppSpacing.l,
                            endIndent: AppSpacing.l,
                            color: AppColors.borderHairline,
                          ),
                        _FaqItem(faq: _ledgerFaqs[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ───── Bize ulaşın
            const SectionLabel(title: AppStrings.supportContactSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.supportContactDesc,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.supportEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    AppPrimaryButton(
                      label: AppStrings.supportContactCta,
                      icon: Icons.send_rounded,
                      onPressed: () => _contactSupport(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.faq});
  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: 2,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.m,
      ),
      iconColor: AppColors.brandLemonPressed,
      collapsedIconColor: AppColors.textMuted,
      title: Text(
        faq.q,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            faq.a,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
