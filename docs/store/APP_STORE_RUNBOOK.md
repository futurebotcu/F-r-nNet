# FırınNet — App Store Runbook

> Windows'ta nereye kadar geldik, Mac/Xcode + Apple Developer ile ne kalıyor.
> App Store Prep Sprint 1 (2026-05-29) çıktısı. İlgili dosyalar:
> [STORE_METADATA.md](STORE_METADATA.md), [PRIVACY_LABEL_DRAFT.md](PRIVACY_LABEL_DRAFT.md),
> [REVIEW_NOTES_DRAFT.md](REVIEW_NOTES_DRAFT.md), [SCREENSHOT_CHECKLIST.md](SCREENSHOT_CHECKLIST.md).

## Mevcut iOS Proje Durumu (özet)
| Alan | Değer |
|---|---|
| iOS klasörü | ✅ var (Flutter scaffold) |
| Bundle ID | `com.firinnet.firinDefter` |
| Display name | FırınNet |
| Version / build | 0.1.0 / 1 |
| Deployment target | iOS 13.0 |
| URL scheme (deep link) | `firinnet://` (Supabase OAuth callback) |
| Info.plist izinleri | ✅ Camera + PhotoLibrary + PhotoLibraryAdd (Sprint 1'de eklendi) |
| Native Google/Apple SDK | yok (Supabase OAuth web akışı) |

## ✅ Windows'ta Tamamlananlar (Sprint 1)
- App Store metadata taslağı (`STORE_METADATA.md`).
- App Privacy label taslağı (`PRIVACY_LABEL_DRAFT.md`).
- Review notes taslağı (`REVIEW_NOTES_DRAFT.md`).
- Screenshot checklist + cihaz boyutları (`SCREENSHOT_CHECKLIST.md`).
- iOS `Info.plist` kamera/foto izin açıklamaları eklendi.
- iOS auth ekranında sosyal login gizleme (`kHideSocialLoginOnIos`) → Guideline
  4.8 + incomplete-feature riskini azaltma (Android etkilenmedi).
- UGC moderation/report/block durum denetimi (aşağıda risk olarak işlendi).

## 🍎 Mac / Xcode + Apple Developer Gerekenler
1. **Apple Developer Program** üyeliği (yıllık, hesap gerekli).
2. **App ID kaydı** — `com.firinnet.firinDefter` (Apple Developer portal).
3. **Signing & Capabilities** (Xcode):
   - Development + Distribution sertifikaları.
   - Provisioning profile (App Store dağıtımı).
   - (Apple Sign-In açılacaksa) "Sign in with Apple" capability + Service ID + Key (.p8).
4. **App icon** — onaylı 1024×1024 FırınNet ikonu (aşağıda P1 blocker).
5. `flutter build ipa` → `.xcarchive` / `.ipa` (yalnız macOS).
6. **Upload** — Xcode Organizer / Transporter / `xcrun altool` / Xcode Cloud.
7. **TestFlight** — internal/external test.
8. **iOS device/simulator smoke** — auth, foto yükleme, deep link, push (varsa APNs).
9. **App Store Connect** (web) — app record, metadata, screenshots, privacy
   anketi, fiyat (ücretsiz), submit for review.

> **Alternatif:** macOS donanımı olmadan **macOS CI runner** (GitHub Actions
> `macos-latest` veya Xcode Cloud) ile imzalı IPA + TestFlight otomatize
> edilebilir; yine Apple Developer hesabı + sertifika/secrets şarttır.

---

## ⚠️ Known Apple Review Risks
### P0 — Submission öncesi çözülmeli
- **Apple Sign-In / Sosyal login (Guideline 4.8):** Uygulama Google ile girişi
  destekliyor; Apple Sign-In henüz aktif değil (`kAppleSignInComingSoon=true`).
  - **Sprint 1 azaltması:** iOS'ta tüm sosyal login gizlendi
    (`kHideSocialLoginOnIos=true`) → iOS'ta yalnız email/şifre + guest. Bu,
    "Google var Apple yok" ve "işlevsiz Yakında butonu" risklerini iOS'ta
    ortadan kaldırır.
  - **Kalıcı çözüm (Mac+portal+kod):** Apple Service ID + capability kur,
    `signInWithApple()` doğrula, `kAppleSignInComingSoon=false` ve
    `kHideSocialLoginOnIos=false` çevir, iOS cihazda smoke et.
- **UGC moderation/report/block (Guideline 1.2):** Şu an kullanıcılar yalnız
  KENDİ post/yorumunu silebiliyor. Başkasının içeriğini **şikayet (report)**,
  kullanıcı **engelleme (block)** ve içerik **filtreleme/moderasyon** YOK.
  UGC + sosyal app olduğu için Apple bunları bekler. **Sprint dışı** bırakıldı
  (yalnız audit); submission öncesi eklenmesi gerekir:
  - Post/yorum için "Şikayet et" aksiyonu + sunucu kaydı.
  - Kullanıcı engelleme (block) + engellenenin içeriğini gizleme.
  - Yayınlanmış iletişim/destek bilgisi + EULA.
- **iOS AppIcon placeholder:** `ios/Runner/Assets.xcassets/AppIcon.appiconset`
  içindeki ikonlar (1024 dahil) **varsayılan Flutter mavi logosu** — marka değil.
  Apple varsayılan/Flutter ikonunu reddeder. **Onaylı 1024×1024 FırınNet ikonu
  gerekir.** (Repo'da onaylı ikon asset'i bulunmadığından Sprint 1'de
  üretilmedi/uydurulmadı.) Onaylı asset gelince Windows'ta `flutter_launcher_icons`
  ile üretilebilir.

### P1
- **Info.plist izinleri:** ✅ Sprint 1'de eklendi (Camera/PhotoLibrary/Add). Eğer
  ileride başka native izin (mikrofon, konum precise vb.) eklenirse string şart.
- **iOS device/simulator smoke yapılmadı** (Mac yok) — auth/foto/deep link
  davranışı gerçek iOS'ta doğrulanmalı.

### P2
- Launch screen markasız (default Flutter LaunchImage) — branded launch önerilir.
- `url_launcher` `tel:`/`whatsapp` için `LSApplicationQueriesSchemes` (kullanım varsa).
- Screenshot üretimi (Mac/simulator).
- Reviewer demo hesabı doldurulmalı (`REVIEW_NOTES_DRAFT.md`).
- App Privacy anketinin son hâli App Store Connect'te girilmeli.
- Story 24h expiry davranışının canlı doğrulanması (opsiyonel; create/view kapandı).
- GitHub Pages'in privacy/account-deletion URL'lerini gerçekten servis ettiği teyidi.

---

## Submission Öncesi Checklist
- [ ] Apple Developer hesabı + App ID
- [ ] Onaylı 1024 app icon (placeholder kaldırıldı)
- [ ] Apple Sign-In aktif **veya** iOS'ta sosyal login gizli (Sprint 1: gizli ✅)
- [ ] UGC report + block + moderasyon eklendi
- [ ] Info.plist izin metinleri ✅
- [ ] Privacy + account-deletion URL'leri canlı (GitHub Pages teyidi)
- [ ] Metadata + keywords + açıklama son hâli
- [ ] App Privacy anketi dolduruldu
- [ ] Screenshots (Mac/simulator) çekildi + yüklendi
- [ ] Demo hesap review notuna eklendi
- [ ] `flutter build ipa` (Mac) + TestFlight smoke
- [ ] Submit for Review
