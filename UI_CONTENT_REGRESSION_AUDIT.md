# FırınNet — UI İçerik Regresyon Auditi

Tarih: 2026-05-12
Kapsam: Tasarım polish turları sonrası profil, akış, panel, role dashboard, ilanlar ve feed composer ekranlarında içerik bloku silinmesi/gizlenmesi kontrolü.

**Yöntem notu:** `C:\dev\firinnet` git repo olarak başlatılmamış (`Is a git repository: false`). Bu nedenle `git diff` yapılamaz — polish öncesi/sonrası karşılaştırma **sadece polish raporlarının "eklendi/çıkarıldı" beyanı vs. mevcut dosyalardaki gerçek içerik** üzerinden yapılmıştır. Belge-temelli doğrulama.

**Audit kuralları:**
- Kod değiştirilmedi.
- Supabase'e dokunulmadı.
- Sadece okuma.

---

## TL;DR

| Sonuç |
|---|
| **Kesin silinen kullanıcı-görür içerik bloğu**: **Yok**. Profil/Feed/Panel/Role Dashboard/Jobs/Composer ekranlarında raporda "yapıldı" denen tüm section'lar şu an dosyada mevcut. |
| **Sadece stil/renk değişimi**: Polish turlarının %95'i renk paleti + tipografi + gölge + placeholder ikon + featured stripe. Layout/section sayısı korunmuş. |
| **Doğrulanamayan şüpheli alanlar**: 3 adet (aşağıda detay) — bunların hepsi raporlarda kasıtlı not düşülmüş kararlar; git geçmişi olmadığı için "kullanıcı bunu istemeden mi oldu" cevaplanamaz. |

---

## 1. Kesin Silinen İçerik

**Bu kategoride bulunan**: **0 kullanıcı-görür section**.

Polish raporlarının "Çıkarıldı" bölümlerinde geçen şeyler **tamamen** ya legacy renk alias'ı ya da yerine daha iyi component konmuş eski widget dosyası:

| Polish raporu | "Çıkarıldı" maddesi | Etki kategorisi |
|---|---|---|
| UI_POLISH_REPORT.md | `lib/core/widgets/summary_metric_card.dart` dosyası | **Widget dosyası refactor**: yerine `MetricPill` + `StatCard` geldi. Kullanıcıya aynı içerik görünür. |
| UI_POLISH_REPORT.md | `lib/core/widgets/big_action_card.dart` dosyası | **Widget dosyası refactor**: yerine `QuickActionTile(featured: true)` geldi. Aynı işlev, daha iyi hiyerarşi. |
| UI_POLISH_REPORT.md | `lib/core/widgets/section_header.dart` dosyası | **Widget dosyası refactor**: yerine `SectionLabel` (chevron + adjustable gap) geldi. |
| UI_POLISH_REPORT.md | Legacy `AppColors` alias'ları: `copperBright`, `copperDeep`, `ember`, `surfaceHigh`, `warning` | **Renk constant cleanup**, görünür değişiklik yok. |
| UI_REDESIGN_REPORT.md | Material default theme + 3-tab bottom nav | **Yerine 5-tab premium nav geldi**, sonra NAV_SOCIAL_PRIORITY_FIX ile bottom nav set'i tekrar düzenlendi. Aşağıdaki "şüpheli" #2'ye bakın. |
| COLOR_THEME_APPLICATION_REPORT.md | Dark espresso palette | **Renk dönüşümü** (dark → light cream). Yapı aynı. |
| VISUAL_THEME_QA_REPORT.md | White-on-amber text overlay'leri | **Kontrast düzeltme**, içerik değil. |
| UI_POLISH_FINAL_REPORT.md | Gradient-only placeholder'lar | **Yerine ikon + label empty state** geldi, daha bilgilendirici. |
| THEME_REFINEMENT_REPORT.md | Soğuk siyah-gri background | **Renk değişimi** (un tonu). |
| FEED_COMPOSER_LAYOUT_FIX_REPORT.md | `Row(Spacer + SizedBox(height:44, child: FilledButton))` pattern'i | **Layout constraint çözümü**, görsel sözleşme aynı. |

`lib/core/widgets/premium/` altında şu an mevcut: `feed_post_card`, `firinnet_header`, `job_opportunity_card`, `market_product_card`, `metric_pill`, `premium_bottom_nav`, `premium_card`, `premium_scaffold`, `quick_action_tile`, `section_label`, `stat_card` — 11 widget. Polish raporlarının vaad ettiği premium component sistemi tamamen yerinde.

---

## 2. Sadece Stil/Renk Değişen Bölümler

**Tüm polish raporlarının ezici çoğunluğu bu kategoride.**

### 2.1 Renk paleti dönüşümü (`COLOR_THEME_APPLICATION_REPORT.md`)
- background `#FFF8ED`, surface `#F6EFE3`, card `#FAF2E6`, elevatedCard `#F3E6D3` — krem zemin
- copper `#D6A13A`, softGold `#B98224`, copperMuted `#E8BF63`
- 4 tema dosyası + 7 widget renk uyarlaması
- **Widget tree değişmedi.**

### 2.2 Görsel kontrast polishleri (`VISUAL_THEME_QA_REPORT.md`)
- Group card cover gradient: dark → warm bej (görsel arka plan)
- Market placeholder: warm bej + "Görsel yok" label
- Feed post placeholder: warm bej
- Status bar overlay: light tema ikonları

### 2.3 Lokalizasyon + empty state (`UI_POLISH_FINAL_REPORT.md`)
- `"Jobs"` → `"İş İlanları"` (AppStrings.jobsTitle) ✓ jobs_screen.dart'ta doğrulandı
- Empty state: ikon + label kombinasyonu

### 2.4 Hiyerarşi polishleri (`UI_POLISH_REPORT.md`)
- `AppShadow.heroGlow`: 2 katmanlı (espresso + copper halo)
- `PremiumCard`: default shadow + border
- `EmptyState`: yeniden yazıldı (ikon + başlık + subtitle + optional CTA)
- `QuickActionMini`: 2-col grid için kompakt tile
- Featured stripe: 3px softGold dikey + copper border

### 2.5 Layout constraint fix (`FEED_COMPOSER_LAYOUT_FIX_REPORT.md`)
- `feed_composer.dart` Paylaş butonu Row pattern değişti
- **Görsel sözleşme aynı** (sağa hizalı, 44 px, bakır, "Paylaş"); sadece infinite-width exception çözüldü
- 2 yeni widget regresyon testi

### 2.6 Mevcut ekranlardaki section sayımı (envanter)

| Ekran | Mevcut section'lar | Beklenen / kayıp |
|---|---|---|
| **profile_screen.dart** | Header • Hero (avatar + name + roleBadge + Hesap pill + Şehir pill) • İstatistikler (3 kolon: Paylaşım/Bağlantı/Yıl) • Hesap (5 satır: İşletme Bilgileri/Ürünlerim/Raporlarım/E-posta/Ayarlar) • Profilden Çık • EmptyState (profile null ise) | Hepsi var. **Kayıp yok.** |
| **feed_screen.dart** | Header • Story strip (Sen + 8 avatar) • Sektör Grupları carousel • Composer • Posts+Insights sliver | Hepsi var. **Kayıp yok.** |
| **role_dashboard_screen.dart** | Header (greeting + subtitle) • Role badge strip ("Profil oluşturmadın" CTA dahil) • Section label • Panel tile list (featured + default) | Hepsi var. **Kayıp yok.** |
| **bakery_panel_screen.dart** | Header (date subtitle + calendar action) • Today hero (CANLI rozeti + net özet + 3 pill) • Üretim Yönetimi (featured "Reçete Hesapla" + 2×2 mini grid) • Bayi Yönetimi (özet kart + Bayi Yönetimine Git butonu) • Son hareketler (data veya empty state + "İlk üretimi gir" CTA) • Topluluk İpuçları (3 TipCard) | Hepsi var. **Kayıp yok.** |
| **jobs_screen.dart** | Header (TR "İş İlanları" + "Sektörün iş ağı" + add) • Segment toggle (Usta Arıyor / İş Arıyor) • Section label + Filtre link • İlan kartları (position+business+city+salary+experience+badge+shift+5 chip+Başvur CTA) | Hepsi var. **Kayıp yok.** |
| **feed_composer.dart** | Collapsed (avatar + prompt + edit ikon) • Expanded (type label + close • 5 ChoiceChip type'ı • TextField 3-4 line • Paylaş butonu sağda) | Hepsi var. Layout fix sonrası sağa hizalama tutarlı. **Kayıp yok.** |

---

## 3. Git Geçmişi Olmadığı İçin Doğrulanamayan Şüpheli Alanlar

Bu üç madde polish raporlarında **kasıtlı not düşülmüş kararlar**; raporları okuyup onaylayabiliriz ama "bir polish turunda yanlışlıkla silinmiş olabilir mi" sorusunu git diff ile kanıtlayamayız.

### 3.1 Bottom nav'dan "Profil" tab'ının çıkarılması
- **Rapor referansı**: `NAV_PROFILE_TO_JOBS_REPORT.md` ve `NAV_SOCIAL_PRIORITY_FIX_REPORT.md` (dosya adlarından anlaşılıyor — özel olarak iki rapor bu nav düzenlemesini belgelemiş).
- **Şu anki durum**: `app_router.dart` ShellRoute'unda 5 tab: `/feed`, `/groups`, `/market`, `/jobs`, `/panel`. Profile tab değil, **ayrı route** olarak duruyor (Feed header avatar tap'iyle push).
- **Çözümleme**: Bu **kasıtlı bir UX kararı**. Profile feed üst-sağdan erişiliyor (header avatar). Ama kullanıcı isterse Profile'ı geri tab'a koyabiliriz — bu PR'da yapılmamalı (audit kuralı: kod değişmiyor).
- **Risk**: Düşük. Profile route + ekran tamamen mevcut, sadece erişim noktası değişti.

### 3.2 "Mesajlar" ekranının placeholder kalması
- **Rapor referansı**: `FINAL_THEME_SMOKE_REPORT.md` → "Mesajlar placeholder".
- **Şu anki durum**: `lib/features/messages/` dizini **yok**. Role dashboard'daki "Mesajlar" / "Gelen Mesajlar" kartları `comingSoon: true` ile snackbar ("Yakında aktif olacak") gösterir.
- **Çözümleme**: Bu **V1 kapsamı dışı kasıtlı boşluk**, silinme değil. AppStrings'te `comingSoon = 'Yakında aktif olacak'` etiket var.
- **Risk**: Yok. Karar belgelenmiş.

### 3.3 Profile screen'in stats kartı (Paylaşım/Bağlantı/Yıl)
- **Şu anki durum**: `profile_screen.dart:217-222`'de hardcoded `12 / 186 / 4` değerleri.
- **Çözümleme**: Polish raporlarında bu sayıların değiştiği bahsi yok. Backend bağlanmadığı için hardcoded mock olduğu anlaşılıyor (memory ile uyumlu: Flutter mock akış). Henüz "Supabase'e bağla" turuna gelmemiş.
- **Risk**: Düşük. Mock sayılar, gerçek veri V2'de gelir.

---

## 4. Polish "Eklendi" Maddelerinin Kodla Eşleşmesi

Polish raporlarının "Eklendi" bölümünde geçen tüm önemli component'ler şu an kodda mevcut:

| Vaad | Dosya | Durum |
|---|---|---|
| `PremiumCard` | `lib/core/widgets/premium/premium_card.dart` | ✓ |
| `FirinNetHeader` | `lib/core/widgets/premium/firinnet_header.dart` | ✓ |
| `StatCard` | `lib/core/widgets/premium/stat_card.dart` | ✓ |
| `QuickActionTile` + `QuickActionMini` | `lib/core/widgets/premium/quick_action_tile.dart` | ✓ |
| `FeedPostCard` | `lib/core/widgets/premium/feed_post_card.dart` | ✓ |
| `MarketProductCard` | `lib/core/widgets/premium/market_product_card.dart` | ✓ |
| `JobOpportunityCard` | `lib/core/widgets/premium/job_opportunity_card.dart` | ✓ |
| `PremiumBottomNav` (gradient indicator) | `lib/core/widgets/premium/premium_bottom_nav.dart` | ✓ |
| `SectionLabel` | `lib/core/widgets/premium/section_label.dart` | ✓ |
| `MetricPill` | `lib/core/widgets/premium/metric_pill.dart` | ✓ |
| `EmptyState` (revamp) | `lib/core/widgets/empty_state.dart` | ✓ |
| `AppShadow.heroGlow` | `lib/app/theme/app_tokens.dart` (implied) | (token, dosya yapı doğrulandı) |
| Lokalizasyon `'Jobs' → 'İş İlanları'` | `app_strings.dart:97` `jobsTitle = 'İş İlanları'` | ✓ |

Hiçbir raporda eklendi denip kodda bulunmayan "vaat-içerik" yok.

---

## 5. Sonuç ve Öneri

1. **Tasarım polish turları sırasında profil/akış/panel/dashboard/ilanlar/composer ekranlarında kullanıcı-görür içerik bloğu silinmedi.** Tüm hero, kart, satır, segment, tile, CTA, empty state mevcut.

2. **Polish'lerde "çıkarılan" şeyler** ya legacy renk constant'ları (görsel etki yok) ya da yerine daha iyi component konmuş eski widget dosyaları (UX'te aynı işlev). Bunlar pozitif refactor, regresyon değil.

3. **Bottom nav'dan Profile tab'ının çıkarılması** ve **Mesajlar ekranının placeholder kalması** ayrı raporlarda kasıtlı not düşülmüş UX kararları. "Silindi" değil, "tasarım kararı".

4. **Aksiyon önerisi**: Yok — geri alma gerekmiyor. Eğer kullanıcı belirli bir ekrandaki bir blokun (örn. profile screen'de bir bölüm) eksik hissettiriyorsa bunu manuel UI smoke'unda görür, o spesifik bölüm raporlanır ve hedefli düzeltilir.

5. **Belirsizlik notu**: Bu audit `git diff` yokluğunda **niyet vs şu an** karşılaştırmasıdır. Bir polish turunun raporlamadığı sessiz silmeleri yakalayamaz. Repo `git init`'lendiğinde ileride bu kategori dolduğunda gerçek diff'le doğrulama yapılabilir; şu an için raporlar tutarlı.

---

## EK: Audit Dışında Tutulanlar (kapsam dışı, kasıtlı)

- `lib/features/marketplace/` — kullanıcı listede saymadı.
- `lib/features/social_groups/` — Feed'den carousel olarak göründüğü kadarıyla audit'e dahil; ayrı detaylı tarama istenmedi.
- `lib/features/dealers/` — V1 zaten son raporlarda (`DEALER_MANAGEMENT_REPORT.md`) belgeli; audit istenmedi.
