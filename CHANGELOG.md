# Changelog

Bu proje [Keep a Changelog](https://keepachangelog.com/) yaklaşımını izler
ve [Semantic Versioning](https://semver.org/) kurallarına yakın bir
şema kullanır. Tarihler ISO 8601 (`YYYY-MM-DD`).

## [Unreleased]

### Added
- GitHub Hygiene Sprint 2 — `LICENSE` (proprietary), `SECURITY.md`,
  issue templates (bug / feature / release_blocker / config),
  `CHANGELOG.md`, README License bölümü.
- v0.1.0 source checkpoint tag/release hazırlığı.

### Notes
- Root dizinindeki 68 legacy markdown audit/rapor henüz taşınmadı
  (Sprint 3: root markdown cleanup).
- `LICENSE` proprietary; üçüncü parti bileşenler kendi lisanslarına
  tabi (bkz. `THIRD_PARTY_LICENSES.md`).

## [0.1.0] — 2026-05-26

İlk public source checkpoint. **Play Store production release değildir.**

### Highlights
- **Sosyal**: Feed (Genel Akış / Takip Edilenler segmentleri), post
  composer (metin/resim/video), yorum, beğeni, kaydetme, paylaşım,
  stories (24 saatlik), takip/takipçi, hashtag chip, post type accent.
- **Gruplar**: public + private, davet/onay akışı, leave safely,
  public profile snapshot RPC.
- **Market**: classified listings (ürün/ekipman), media (`market-media`
  bucket), contact panel (telefon / WhatsApp / in-app), city/district
  controlled vocab, save.
- **İş ilanları**: Usta Arıyor (ticari) + İş Arıyorum (bireysel),
  taxonomy-driven role chips, salary validation.
- **Mesajlaşma**: generic conversations + flutter_chat_ui; legacy job
  conversation modu korunuyor.
- **Bayi Defteri** (5-tab mini-app): Genel Bakış / Bayiler /
  Hareketler / Raporlar / Gün Sonu, EMA pulse card, PDF + plain text
  share, quick payment + cash tendered calculator (donor lift).
- **Fırın paneli**: üretim girişi, fire takibi, gün sonu, rapor.
- **Reçete kütüphanesi** + hesaplama makinesi (FırınNet kütle/oran
  hesabı).
- **Profil**: unified public profile RPC, follow/follower/following,
  avatar upload (`avatars` bucket public + owner-prefix RLS).
- **Auth**: e-posta/şifre, Google OAuth, guest mode, KVKK + privacy
  yasal akış, `delete-account` Edge Function (KVKK / Google Play
  uyumlu).
- **Bildirimler**: app-içi notification merkezi.

### Foundations
- 37 Supabase migration: core schema + RLS + auth handlers, social
  spine, market, jobs, groups, follows, stories, location codes,
  profession taxonomy, worker skills, job offer codes,
  `firinnet_id_foundation` (FN-YYYY-NNNNNN, owner-only).
- Storage bucket'lar: `feed-media`, `market-media`, `story-media`,
  `avatars` — hepsi owner-prefix RLS.
- 4 repository katmanı (base interface + local mock + Supabase +
  guarded auth/guest wrapper) → 14 base + 14 local + 16 Supabase + 9
  guarded.
- Tasarım sistemi: `AppColors`, `AppSpacing`, `AppRadius`, `AppShadow`,
  `AppTypography` token'ları; Color Foundation Sprint paleti (krem
  dominant + warm copper accent + espresso text).
- Premium widget'lar: `PremiumCard` (standard/hero/compact tier),
  `StatCard`, `QuickActionTile`, `PremiumBottomNav`, `FirinnetHeader`,
  `TagChip`, `DealerFilterChip`, `DealerKpiTile`, `DealerAvatar`,
  `EmptyState`, `InlineComposerCard`.
- 1187/1187 test geçer (modüller: auth, social, dealers, groups,
  market, jobs, recipes, messaging, vb.).

### GitHub Hygiene Sprint 1 (bu release'in parçası)
- Default Flutter README → FırınNet README (TR, 124 satır).
- Repo metadata: description + homepage + 10 topic.
- `.github/workflows/flutter.yml` (Flutter 3.35.4 pinned, analyze +
  test + build apk debug).
- PR template.
- `.gitignore`: `.archive/`, `.smoke-shots/`, `*.patch` koruma.
- Analyzer cleanup: 65 issue → 0 (lokal/CI hizalandı).

### Not
Bu tag **kaynak kod checkpoint'idir**, mağaza release'i değildir.
Mağaza release pipeline'ı için kalan adımlar: Android signing
(`android/key.properties`), Play Store / App Store listing, store
listing metadata, ekran görüntüleri, Play Console internal track.

[Unreleased]: https://github.com/futurebotcu/F-r-nNet/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/futurebotcu/F-r-nNet/releases/tag/v0.1.0
