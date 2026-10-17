# FırınNet — Kapsamlı Sistem Denetimi, Kurumsal E-posta Kontrolü ve Tedarikçi Paneli Planı

**Tarih:** 2026-10-16 · **Baz commit:** main `2934f4b` · **Kapsam:** salt-okunur denetim (kod + canlı Supabase şeması/advisor). Üretim verisine yazılmadı, migration uygulanmadı, dağıtım yapılmadı.

**Kanıt etiketi:** `[DOĞRULANDI]` = kaynak dosya/DB sorgusuyla teyit edildi · `[TAHMİN]` = kanıt eksik, varsayım · `[CANLI]` = üretim DB'de sorgulandı.

---

## 0. Yönetici özeti

- **E-posta:** `info@firin.net` **henüz çalışmıyor** (MX/SPF/DMARC yok, alan park halinde). Durum C → hiçbir adres değiştirilmedi; geçiş planı §1.4'te. Kamuya açık 5 yüzeyde şahsi Gmail adresi kullanılıyor.
- **Mimari sağlam:** Flutter + Riverpod + GoRouter, Supabase (81 tablo, hepsi RLS'li), 7 edge function, 279 test dosyası / ~2.600 test, CI yeşil. Gizli anahtar sızıntısı yok.
- **Tedarikçi deneyimi iki parçaya bölünmüş:** Panel sekmesi tedarikçiye yalnızca 6 statik kart (biri "Yakında") gösteriyor; gerçek B2B yönetim yüzeyi Pazar › Mağazam sekmesinde. Dashboard'da hiçbir KPI yok, "Ürün/Hizmet İlanı Ver" kartı B2B ürün değil ekipman ilanı açıyor, "Firma Profilim" B2B mağazaya değil sosyal profile gidiyor.
- **Canlı veri:** 39 profil, 1 tedarikçi mağazası, 1 ürün, 1 kampanya, 0 teklif talebi, 0 ilan `[CANLI]`. Yani tedarikçi tarafı henüz fiilen kullanılmamış; büyük yeniden tasarım yerine akışı birleştirmek ve ilk değer anını (teklif talebi → yanıt → müşteri) görünür kılmak öncelik.
- **Güvenlik:** P0 yok. 4 orta bulgu (is_verified sahip-yazılabilir, reply insert'te accepted serbest, talep accepted_reply_id alıcı-yazılabilir, bucket limitleri yok) + 1 gizli ürün regresyonu (kampanyada bağlı ürün hiç kaydedilmiyor).
- **İlk geliştirilecek sayfa:** Tedarikçi Panel ana ekranı (role_dashboard wholesaler dalı) — gerekçe §10.

---

## 1. Kurumsal destek e-postası denetimi (Aşama 1)

### 1.1 Hedef adres durumu `[DOĞRULANDI]`

`firin.net` alan adı için DNS sorgusu (yerel çözücü + 8.8.8.8):

| Kayıt | Sonuç |
|---|---|
| NS | ns3.epik.com (Epik park/registrar) |
| A | 149.33.29.239 (park sayfası) |
| MX | **yok** |
| TXT (SPF) | **yok** |
| _dmarc TXT | **yok** |

Sonuç: `info@firin.net` adresine şu an posta teslim edilemez. **Durum C** geçerli: adres değişikliği yapılmadı.

### 1.2 Envanter: hangi adres nerede, ne amaçla

| Yüzey | Dosya | Adres | Amaç | Karar |
|---|---|---|---|---|
| Uygulama içi Destek ekranı (mailto + metin) | `lib/core/constants/app_strings.dart:817` (`supportEmail`), kullanım `lib/features/settings/screens/support_screen.dart:75-92,219` | f***75@gmail.com | Kamuya açık destek | **Geçiş adayı** (mailbox hazır olunca) |
| Gizlilik politikası (GitHub Pages) | `docs/privacy/index.html:194` | f***75@gmail.com | Kamuya açık gizlilik iletişimi | Geçiş adayı |
| Hesap silme web sayfası | `docs/account-deletion/index.html:128,131` | f***75@gmail.com | Kamuya açık, Play "Data deletion" URL'si | Geçiş adayı |
| Güvenlik bildirimi | `SECURITY.md:35` | f***75@gmail.com | Güvenlik açığı bildirimi | **Değiştirme** (kritik hesap/güvenlik kanalı; ayrı security@ düşünülmeli) |
| Mağaza gizlilik politikası taslağı | `docs/store/privacy_policy_tr.md:122`, `docs/store/privacy_policy_tr.html:94` | `info@fırın.net` (IDN, Türkçe karakterli) | Store metni | **Hatalı/tutarsız**: ne gmail ne de firin.net; yayınlanmış privacy/index.html ile çelişiyor. Mailbox hazır olunca `info@firin.net` ile düzeltilmeli |
| Anlaşmalı iş yeri başvuru maili (edge fn) | `supabase/functions/send-partner-business-application-email/index.ts:57,82` | hedef: env `PARTNER_APPLICATION_EMAIL`/`SUPPORT_EMAIL` (tanımsız → `email_not_configured`); gönderen varsayılanı `onboarding@resend.dev` | Transactional | Env ile yönetiliyor, kodda şahsi adres yok. Mailbox hazır olunca secret olarak set edilecek |
| Store meta (Support URL) | `docs/store/STORE_METADATA.md:66` | GitHub repo URL (geçici) | Play/App Store destek bağlantısı | Mailbox + destek sayfası hazır olunca güncellenecek |
| Store review notes | `docs/store/REVIEW_NOTES_DRAFT.md:24` | `<to be provided>` | Reviewer iletişimi | Boş; doldurulacak |
| Supabase Auth SMTP / e-posta şablonları | Dashboard (repoda `supabase/config.toml` yok) | **Bu oturumdan doğrulanamadı** `[TAHMİN]` | Şifre sıfırlama, doğrulama | Dashboard › Auth › SMTP Settings'te gönderen adresi kontrol edilmeli |
| Google Play Console destek e-postası | Konsol (repo dışı) | Doğrulanamadı | Mağaza listeleme | Konsolda kontrol |
| Test/seed adresleri | `supabase/tests/**`, `docs/audits/legacy/**` | `*@test.local`, `*@firinnet.local`, `bot+*@firinnet.system` | Test fikstürü | Dokunulmaz |
| Login ipucu | `app_strings.dart:118` | `firin@ornek.com` | Placeholder | Dokunulmaz |

Geliştirici hesabı, Supabase/RevenueCat/Firebase sahipliği, keystore ve Play Console hesap adresleri **kapsam dışı bırakıldı** (talimat gereği otomatik değiştirilmez).

### 1.3 Yapılan değişiklik

**Hiçbiri.** Mailbox doğrulanmadan adres değişimi, destek taleplerinin kaybolmasına yol açar.

### 1.4 Güvenli geçiş planı (mailbox hazır olduğunda)

1. **DNS/posta kutusu** (repo dışı, sahip): firin.net için MX (Google Workspace / Zoho / Yandex vb.), SPF `v=spf1 include:<sağlayıcı> ~all`, DKIM seçici, DMARC `v=DMARC1; p=quarantine; rua=mailto:dmarc@firin.net`. info@ kutusu oluşturulup mevcut Gmail'e **yönlendirme** kurulur (geçiş süresince iki kanal da okunur).
2. **Doğrulama:** info@firin.net'e dışarıdan test maili → teslim teyidi; Resend'de firin.net domain doğrulaması (DKIM) → `PARTNER_APPLICATION_FROM = "FırınNet <noreply@firin.net>"`.
3. **Kod PR'ı (tek, küçük, geri alınabilir):** `supportEmail` sabiti + `docs/privacy/index.html` + `docs/account-deletion/index.html` + `docs/store/privacy_policy_tr.{md,html}` → `info@firin.net`. Testler: `support_screen` widget testi `AppStrings.supportEmail` üzerinden çalıştığı için kırılmaz; `grep -r "gmail.com" lib docs/privacy docs/account-deletion` sıfır dönmeli.
4. **Secrets:** `SUPPORT_EMAIL`/`PARTNER_APPLICATION_EMAIL` edge function secret'ı set edilir (repoya yazılmaz).
5. **Konsollar:** Play Console destek e-postası ve Store metadata Support URL güncellenir.
6. **SECURITY.md:** ayrı karar; `security@firin.net` açılırsa oraya, yoksa mevcut kalır.

---

## 2. Mimari ve teknoloji haritası `[DOĞRULANDI]`

| Katman | Teknoloji | Not |
|---|---|---|
| Mobil | Flutter, Riverpod 2 (133 FutureProvider, 132 ConsumerWidget), GoRouter tek ShellRoute | `lib/` 523 dart dosyası, 25 feature modülü |
| Tema | Material 3, `lib/app/theme/{app_theme,app_colors,app_tokens,app_typography}.dart` | Dark mode yok (`darkTheme()` light döner, `app.dart:79-80`) |
| Backend | Supabase Postgres (81 tablo, hepsi RLS), ~150 SECURITY DEFINER fn, 5 storage bucket | 93 migration, `supabase/migrations/` |
| Edge fn | delete-account, push-dispatch, revenuecat-webhook, revenuecat-sync-my-entitlements, revenuecat-confirm-listing-payment, send-partner-business-application-email, academy-worker | `[CANLI]` 7 aktif; verify_jwt: delete-account/partner-email/rc-sync/rc-confirm **açık**, push-dispatch/rc-webhook/academy-worker **kapalı** (shared-secret/HMAC ile korunuyor) |
| Ödeme | RevenueCat (IAP) + Supabase webhook; havale/Iyzico yok | `listing_payments_enabled=false`, `supplier_paid_packages_published=false` `[CANLI]` |
| Push | FCM via push-dispatch | |
| İçerik motoru | Akademi botu (pg_cron + academy-worker) | 13 akademi/iç tablo kasıtlı policy'siz (service_role) |
| CI | GitHub Actions: analyze + test (golden hariç) + debug apk | `.github/workflows` |
| Test | 279 dosya, ~2.622 case, 3 golden; 101 dosya kaynak-metin "guard" testi | integration_test yok |
| Yapılandırma | `--dart-define` (SUPABASE_URL/ANON_KEY/REVENUECAT), release'te boşsa fail-fast | Hard-coded secret yok |

**Rol modeli:** tek enum `AccountType { commercial, individual, wholesaler }` (`lib/features/profile/models/bakery_profile.dart:6`), DB `profiles.account_type`. Alt roller: şoför (bireysel + aktif atama), şube personeli (`BranchRole`), B2B görünüm rolü (`B2bRole.supplier` ⇔ wholesaler, `b2b_providers.dart:427-434`). **Admin rolü/paneli yok** — backoffice işleri service_role script'leriyle (`scripts/admin/*.ps1`).

---

## 3. Kullanıcı rolleri ve sayfa envanteri (Aşama 2)

Tam route tablosu: 100+ route; aşağıda rol bazlı yüzeyler ve değerlendirme. Alt nav (5 sekme) tüm rollerde ortak: Topluluk · Pazar · İlanlar · Mesajlar · Panel (`lib/features/dashboard/screens/app_shell.dart:23-54`). Auth guard prefix'leri: `/panel, /dealers, /debt-expense, /pazar/magazam, /wholesale, /partners` (`app_router.dart:354-363`). **Hiçbir route rol kontrolü yapmıyor**; rol koruması widget guard'larında (`PatronDriverGuard`, `PatronBranchGuard`).

### 3.1 Rol × Panel kartları (`lib/features/dashboard/services/role_panel_cards.dart`)

| Rol | Kartlar | Canlı veri |
|---|---|---|
| Fırın/İşletme (commercial) | Fırın Paneli, Bayi Paneli, Borç & Gider, Şube Yönetimi, Hesaplama, Reçetelerim, Profil ve CV, Anlaşmalı İş Yerleri, İlanlarım, Mesajlar + PlanStatusCard | Plan durumu, kilit rozetleri, okunmamış mesaj |
| Usta/Çalışan (individual) | Profil ve CV, Bayi Paneli, Hesaplama, Reçetelerim, Partners, İş İlanları, Mesajlar (+Şube İşlerim koşullu) | Okunmamış mesaj |
| **Tedarikçi (wholesaler)** | Bayi Paneli (Müşteriler), **Ürün/Hizmet İlanı Ver → `/market/listings/new` (ekipman ilanı, B2B ürün değil)**, **Firma Profilim → `/profile` (sosyal profil, mağaza değil)**, Partners, Gelen Mesajlar, **Fiyat Duyuruları (Yakında)** | Yalnız okunmamış mesaj |

### 3.2 Sayfa değerlendirmesi ve öncelik

| Sayfa / Akış | Amaç | Adım | Sorun | Öncelik |
|---|---|---|---|---|
| Panel (wholesaler) `role_dashboard_screen.dart` | Tedarikçi ana ekranı | — | KPI yok, 2 kart yanlış hedefe gidiyor, 1 kart "Yakında", B2B mağazaya link yok | **P0** |
| Pazar › Mağazam `supplier_store_tab.dart` | Mağaza yönetimi | 2 tık + form | İyi temel; "Öne çıkan ürünler" aslında tüm ürünler (taslak dahil), "Aktif kampanyalar" süresi dolmuşları da gösteriyor; sayfa açılışında yalın spinner | P1 |
| Pazar › Teklif Ağı `supplier_offer_network_tab.dart` | Gelen talepler + ilgilenenler | 1 tık | Talep listesi global (kategori/bölge filtresi yok), okunmadı/yanıtlandı işareti yok, talebin hangi ürüne ait olduğu görünmüyor (`target_id` map edilmiyor), sayfalama yok | **P0** (ticari çekirdek) |
| Ürün formu `supplier_product_form_screen.dart` | Ürün ekle/düzenle | 1 ekran | Fiyat tipi salt "Teklif al", tek görsel, silme/çoğaltma yok, açıklama uzunluk sınırı yok; mağaza yoksa jenerik hata | P1 |
| Kampanya formu `supplier_campaign_form_screen.dart` | Kampanya | 1 ekran | **Bağlı ürün serbest metin ve hiç kaydedilmiyor** (`supabase_b2b_repository.dart` insert/update'te `linked_product_id` yok; satır 45'te yalnız select) | **P1 (bug)** |
| Mağaza düzenle `supplier_store_edit_screen.dart` | Firma vitrini | 1 ekran | İl/ilçe, telefon, web, adres alanı yok; çift-gönderim ve dirty guard yok (diğer iki formda var); hard-coded Türkçe label'lar | P1 |
| Mağaza detayı (alıcı görünümü) `b2b_store_detail_screen.dart` | Güven + teklif | — | Mesaj/ara/takip aksiyonu yok; sahip butonları paywall'ı atlıyor (`:144-154`, sunucu yine engelliyor) | P1 |
| Alıcı teklif akışı `b2b_offer_bottom_sheet.dart` | Talep oluştur | 1 sheet | 8 sabit şehir listesi (il seçici yerine); kategori sabit 6 | P2 |
| Planlar `plans_screen.dart` | Paket | — | Wholesaler'a yalnız Free/Premium; fiyat metni "açıklanacak" | P2 (lansman süresince kasıtlı) |
| Bayi Paneli (wholesaler = Müşteriler) `dealer_shell_screen.dart` | Defter | — | Güçlü; wholesaler için "Bayi" dili yerine "Müşteri" dili kısmen uygulanmış; şoför sekmesi tedarikçiye de açık | P2 |
| İlanlar (Eleman/İş yeri/Ekipman) | Pazar yeri | — | Sayfalama `.limit(100)`; view_count kolonu var ama artırılmıyor/gösterilmiyor | P2 |
| Topluluk/Feed | Sosyal | — | Olgun; tek gerçek sayfalama burada | P3 |
| Mesajlar | DM | — | B2B lead mini-chat ayrı sistemde (`b2b_quote_lead_messages`), ana Mesajlar'da görünmüyor | P1 |
| Ayarlar › Destek | SSS + mailto | 2 tık | Şahsi Gmail (bkz §1) | P1 (mailbox'a bağlı) |
| Ölü/erişilemez route'lar | — | — | `/onboarding, /panel/report, /dealers/assigned/:id, /wholesale/customers, /worker/experiences, /worker/job-seek, /jobs/offers/:id/edit` çağrısız; `pazar_coming_soon_screen.dart` route'suz | P3 (temizlik) |

---

## 4. Tedarikçi panelinin mevcut durumu (Aşama 3) `[DOĞRULANDI]`

### 4.1 Giriş akışı
Tedarikçi giriş yapınca Panel sekmesinde "Toptan ağ" başlıklı 6 kart görür. B2B mağazasına ulaşmak için **Pazar sekmesine geçmesi** gerekir; Panel'den mağazaya hiçbir link yok. Mağazam sekmesi: "Fırıncılar mağazanı böyle görüyor" şeridi → `SupplierPlanCard` (ürün/kampanya/yanıt kotaları, gerçek sayım) → mağaza hero → Mağazanı düzenle → ürün listesi → kampanya listesi.

### 4.2 Veri modeli (canlı)
- `b2b_supplier_shops` (owner başına 1): shop_name, description, city, district, service_regions[], categories[], logo_url, cover_url, is_active, **is_verified** (UI'da hiç kullanılmıyor, formda yok).
- `b2b_products`: name, category (6 sabit), min_order (metin), delivery_regions[], price_type ('quote' sabit), description, image_url (tek), published. **Fiyat/birim/stok/çoklu görsel/SKU yok.**
- `b2b_campaigns`: title, category, linked_product_id (kaydedilmiyor), regions[], min_order, valid_until, description, image_url, published.
- Talep zinciri: `b2b_quote_requests` (alıcı) → `b2b_quote_replies` (tedarikçi, 1/talep) → `b2b_quote_leads` (alıcı "ilgileniyorum", telefon paylaşımı) → `b2b_quote_lead_messages` (mini-chat, RPC-only).
- **Analitik: hiç yok.** Görüntülenme, tıklama, teklif dönüşümü için kolon/tablo/UI bulunmadı. `market_listings.view_count` var ama artıran kod yok.

### 4.3 Entitlement (canlı etkin değerler)
- Free: ürün 1 / kampanya 0 / yanıt 3 ay; Premium: sınırsız. **Pro katmanı (5/3/20) sunucudan kaldırılmış** (`20260923120000_launch_premium_and_listing_v1.sql:477-508`), `paid_business_plan` pro→premium map'liyor.
- Tedarikçi lansman kampanyası **AKTİF** `[CANLI]`: `supplier_launch_free_start=2026-09-25`, `until=2027-10-01` → tüm tedarikçiler şu an premium limitli.
- İlan ücreti: `get_listing_fee_amount_cents` canlıda yalnız `job_seek`→0, ödemeler kapalı→0, aksi 5000. **Tedarikçi Pro/Premium muafiyeti ezilmiş** (`20260712100000:195-218` → `20260923120000:853-872`). Ödemeler kapalı olduğu için bugün etkisi yok; **ödemeler açılmadan önce karar gerekli** (istemci hâlâ `supplier_listing_fee_exempt` okuyor).
- UI paywall: Mağazam'da ürün/kampanya ekle (`supplier_store_tab.dart:84-127`), yanıt (`b2b_offer_bottom_sheet.dart:281-288`). Mağaza detayındaki sahip butonları paywall'sız.

### 4.4 Eksikler (bulunamadı, varmış gibi gösterilmeyecek)
Sipariş, CRM, yapılandırılmış fiyat teklifi (tutar+miktar+geçerlilik), fatura, stok, talep filtreleme, "gönderdiğim teklifler" listesi, teklif düzenleme/geri çekme, talep okundu işareti, yeni talep bildirimi (bildirim yalnız lead/mesaj/kabul'de), ürün silme/çoğaltma, mağaza-profil bağı, ürün görüntülenme sayısı, admin doğrulama aracı.

---

## 5. En kritik 15 UX/UI problemi

| # | Problem | Kanıt | Etki | Öncelik |
|---|---|---|---|---|
| 1 | Tedarikçi Panel'i KPI'sız, mağazaya linksiz; 2 kart yanlış hedef, 1 kart "Yakında" | `role_panel_cards.dart:166-209` | İlk 5 saniyede değer yok | P0 |
| 2 | Gelen taleplerde okunmadı/yanıtlandı durumu yok; "Teklif Ver" zaten yanıtlanmışta da görünüyor, hata sunucudan 23505 | `supplier_offer_network_tab.dart:123-158`, `supabase_b2b_repository.dart:767-773` | Tedarikçi hangi işe baktığını bilmiyor | P0 |
| 3 | Talebin hangi ürün/kampanya/mağazaya geldiği gösterilmiyor (`target_id` map yok) | `b2b_quote_request_card.dart` | Teklif bağlamsız | P0 |
| 4 | Talep listesi global, kategori/bölge filtresi ve sayfalama yok | `supabase_b2b_repository.dart:591-600` | Ölçekte kullanılamaz | P1 |
| 5 | Kampanya "bağlı ürün" serbest metin + hiç kaydedilmiyor | `supabase_b2b_repository.dart:519-579` | Sessiz veri kaybı | P1 |
| 6 | B2B lead mini-chat ana Mesajlar'dan kopuk; alt nav unread rozetine girmiyor | `b2b_lead_message_sheet.dart`, `b2b_quote_lead_messages` | Mesaj kaçar | P1 |
| 7 | Mağaza düzenlemede il/ilçe/telefon/web yok; çift-gönderim ve dirty guard yok | `supplier_store_edit_screen.dart:67-89` | Güven + veri kalitesi | P1 |
| 8 | Alıcı mağaza detayında mesaj/ara/takip aksiyonu yok | `b2b_store_detail_screen.dart:60-245` | Ticari etkileşim tek kanala (teklif) sıkışmış | P1 |
| 9 | Ürün kartlarında "Yönet" menüsünde silme/çoğaltma yok; detayda yalnız 4 alan | `b2b_meta_pill.dart:115-160` | Katalog yönetimi eksik | P1 |
| 10 | Yalın `CircularProgressIndicator` (71 kullanım, 51 dosya) vs skeleton (16 dosya); 28 `.when` `skipLoadingOnReload`'suz (çoğu dealers) | agent sayımı | Yenilemede spinner flash | P2 |
| 11 | `textMuted` #9CA3AF beyazda ~2.5:1 (AA fail), temanın `bodySmall`/hint varsayılanı; 271 kullanım | `app_theme.dart:112-115,307` | Okunabilirlik, yaşlı kullanıcı | P1 |
| 12 | 596 literal `fontSize` (26 farklı değer), 557 inline `TextStyle`; semantik renkler token yerine literal (`0xFF166534` ×20 = `successInk`) | `b2b_meta_pill.dart:202-218` vb. | Tutarsızlık, bakım maliyeti | P2 |
| 13 | Küçük dokunma hedefleri: B2B form clear butonu 16px, "Kaldır" 12.5px metin, 34/38px butonlar | `b2b_form_field.dart:132-136`, `b2b_image_upload_field.dart:97-107`, `supplier_store_tab.dart:389` | Mobil kullanılabilirlik | P1 |
| 14 | Sarı metin kuralı 4 yerde ihlal; `brandLemonPressed` ikon beyazda ~1.6:1 | `quick_action_tile.dart:179`, `b2b_store_card.dart:149` | Marka/erişilebilirlik | P2 |
| 15 | Türkçe büyük/küçük harf: B2B'de `toUpperCase()`/`toLowerCase()` (İ/ı hatası), arama istemci tarafı tüm katalog üstünde | `supabase_b2b_repository.dart:72-74,376-383` | "İstanbul" araması başarısız | P1 |

Ek (P1, tedarikçi dışı): `dealer_return_form_screen.dart:62-110` çift-gönderim koruması yok + istemci id → **çift iade kaydı** mümkün `[DOĞRULANDI]`; `group_create_screen.dart:58-103` aynı (çift grup + yakalanmamış hata).

---

## 6. Güvenlik ve performans bulguları (Aşama 6)

### 6.1 Güvenlik — kod + canlı policy teyidi

| # | Sev | Bulgu | Kanıt | Öneri |
|---|---|---|---|---|
| S1 | Orta | `b2b_supplier_shops.is_verified` sahip tarafından PATCH edilebilir (update policy yalnız owner, kolon koruyucu trigger yok) | `[CANLI]` `b2b_shops_update` with_check `owner_id=auth.uid()`; tek trigger `trg_b2b_shops_updated` | "Doğrulanmış" rozeti UI'a girmeden önce BEFORE UPDATE guard (is_verified değişimi yalnız service_role) |
| S2 | Orta | Tedarikçi yanıt insert'inde `status/accepted` serbest; guard trigger yalnız BEFORE UPDATE | `[CANLI]` `trg_b2b_replies_guard_status` UPDATE-only; `b2b_replies_insert` with_check status'u sınırlamıyor | INSERT'e de guard veya with_check `status='sent' and accepted=false` |
| S3 | Orta | Alıcı `b2b_quote_requests.accepted_reply_id/status` doğrudan yazabilir (RPC bypass) | `[CANLI]` `b2b_qr_update_own` | Kolon guard trigger: accepted_reply_id yalnız `b2b_accept_quote_reply` üzerinden |
| S4 | Orta | 5 bucket'ta `file_size_limit`/`allowed_mime_types` yok; 4'ü public | `[CANLI]` storage.buckets | Dashboard/migration ile 5–10MB + image/* (chat-media video/mp4 ek) |
| S5 | Orta-Düşük | Tedarikçi rolü yalnız istemcide; RLS `account_type` kontrol etmiyor → herhangi bir authenticated kullanıcı mağaza/ürün açabilir; promo'lu bireysel sınırsız limit alır | `b2b_providers.dart:433`, `20260925090000:129-150` | `b2b_shops_insert` with_check'e `account_type='wholesaler'` |
| S6 | Düşük | `profiles.is_bot`, `firinnet_id` kullanıcı tarafından değiştirilebilir (format+unique var, sahiplik yok) | `[CANLI]` `profiles_update_own`; trigger yalnız account_type guard | Kolon guard |
| S7 | Düşük | Entitlement limitleri yalnız INSERT'te; downgrade sonrası republish serbest | `20260712100000:159-176` | Şimdilik kabul (kampanya limiti 0/-1) |
| S8 | Düşük | Partner başvuru maili edge fn'de rate limit yok (DB'de 5/saat var ama mail tekrar gönderilebilir) | `send-partner-business-application-email/index.ts` | `sent_at` kolonu + tek gönderim |
| S9 | Düşük | `branch_processes.created_by ON DELETE RESTRICT` → hesap silme bloklanabilir | `20260705120000:104` | SET NULL |
| S10 | Düşük | B2B içerik için report/block target type yok | `20260611013000:18-19` | `b2b_product`, `b2b_shop` target eklenmeli (store UGC gereği) |
| S11 | Bilgi | Supabase advisor: `b2b_open_quote_requests` SECURITY DEFINER view (kasıtlı, buyer_id gizli), 80 SD fonksiyon authenticated'a açık (çoğu kasıtlı RPC; 17'si keyfi user_id parametresi alıp başkasının planını döndürüyor — düşük bilgi sızıntısı), **leaked password protection kapalı** | advisor çıktısı | Dashboard › Auth'ta HIBP korumasını aç (sıfır kod) |
| ✔ | — | anon'un `market_listings`/`profiles`/`b2b_*` üzerinde SELECT yetkisi **yok** (policy `{public}` olsa da grant yok) | `[CANLI]` role_table_grants | Sorun değil |
| ✔ | — | Hard-coded secret yok; `.env.*`, `google-services.json`, keystore gitignore'da; release build define'sız fail-fast | agent taraması | — |
| ✔ | — | delete-account yalnız çağıranı siler, storage prefix temizliği best-effort (1000 limit sayfalanmamış) | `delete-account/index.ts:63-128` | Sayfalama P3 |

### 6.2 Performans

| Bulgu | Kanıt | Öncelik |
|---|---|---|
| B2B repo'da 31 sorgu, 0 limit; `listProducts` tüm katalogu çekip istemcide arıyor; `_shopCounts` saymak için tüm satırları indiriyor | `supabase_b2b_repository.dart:246-292,363` | P1 (ölçek öncesi) |
| Dealer `listAllTransactions` tüm geçmişi indiriyor; son 5 aktivite ve bakiye istemcide hesaplanıyor; PostgREST max-rows 1000 ise **bakiyeler sessizce yanlış** olabilir | `supabase_dealer_repository.dart:373`, `dealer_providers.dart:153-165,612-630` | P1 (doğrulanmalı: max-rows ayarı) |
| 200 `auth_rls_initplan` uyarısı (policy'lerde `auth.uid()` yerine `(select auth.uid())`) | advisor | P2 (tek migration, mekanik) |
| 38 indekssiz FK, 18 kullanılmayan indeks, 1 duplicate indeks (`market_listings` owner) | advisor | P2 |
| Konuşma başına `unreadCount` çağrısı (olası N+1) | `supabase_messaging_repository.dart:251` | P2 |
| `Image.memory` 88px thumbnail'de `cacheWidth` yok | `market_listing_form_screen.dart:1128` | P2 |
| `ListView(children:)` 96 vs builder 22 | sayım | P3 |

---

## 7. Tedarikçi paneli için önerilen ideal yapı

İlke: **tek giriş noktası, gerçek veri, 3 saniyede "bugün ne yapmalıyım".** Yeni tablo gerektirmeyen sürüm (V1) ile küçük ek altyapı (V2) ayrılmıştır.

### 7.1 Panel ana ekranı (wholesaler dalı) — V1, mevcut altyapıyla
```
[Selamlama + mağaza adı + plan rozeti (Free/Premium · lansman hediyesi)]
[Mağaza tamamlanma şeridi: logo · açıklama · bölge · kategori · ilk ürün  (x/5)]
[KPI satırı — hepsi mevcut sorgulardan]
  Yanıt bekleyen talep | Yayında ürün / limit | Aktif kampanya | İlgilenen müşteri
[Hızlı işlemler]  Ürün ekle · Kampanya oluştur · Talepleri gör · Mağazamı düzenle
[Son faaliyet — mevcut notifications tablosundan b2b olayları]
[Mevcut kartlar: Müşteriler (Bayi Paneli) · Mesajlar · Anlaşmalı İş Yerleri]
```
Kaldırılacak/değişecek: "Ürün/Hizmet İlanı Ver" → "Ürün ekle" (B2B), "Firma Profilim" → "Mağazam" (`/pazar` supplier tab 0), "Fiyat Duyuruları (Yakında)" → kaldır (boş vaat).

Veri kaynakları: `b2bMyStoreProvider`, `b2bMyProductsProvider`, `b2bMyCampaignsProvider`, `b2b_open_quote_requests()` sayısı, `myEntitlementProvider`, lead sayısı (`b2b_quote_leads` shop'a göre), `notifications` (type like 'b2b_%'). **Hiçbiri yeni tablo gerektirmez.**

### 7.2 Talepler (Teklif Ağı → "Talepler")
- Segment: **Yeni** (yanıtlamadığım) · **Yanıtladım** · **İlgilenenler** · **Kazanılan** (accepted).
- Kart: kategori + miktar + şehir + **hangi ürünüm/kampanyam** (target_type/target_id join; V1'de istemci map, V2'de RPC'ye `target_label` kolonu) + "ne zaman".
- "Yanıtladım" işareti: `b2b_quote_replies` where supplier_shop_id = benim (mevcut select policy izin veriyor) → set içinde kontrol. Yeni tablo yok.
- Filtre: kategorilerim / bölgelerim (mağaza profilinden varsayılan), tümü.
- V2: `b2b_quote_requests` için yeni talep bildirimi trigger'ı (kategori eşleşen aktif mağazalara), RPC'ye `p_category[]`, `p_region[]`, limit/offset.

### 7.3 Ürün ve kampanya yönetimi
- V1: Silme (RLS policy zaten var, repo + "Yönet" menüsü), çoğaltma (istemci tarafı kopya → insert), kampanya "bağlı ürün" → kendi ürünlerinden seçici + `linked_product_id` yazımı (bug fix), "Öne çıkan ürünler" yalnız yayındakiler, süresi dolmuş kampanyalar "Süresi doldu" rozeti.
- V2 (schema ek, additif): `b2b_products.price_amount numeric null`, `price_unit text null` ("Teklif al" varsayılan korunur), `availability text` (stokta / sipariş üzerine / tükendi), `b2b_product_media` tablosu (çoklu görsel, market_listing_media örneğiyle).

### 7.4 Mağaza profili
- V1: il/ilçe alanı (kolonlar var, forma eklenir), çift-gönderim + dirty guard, Türkçe label'lar AppStrings'e, profil tamamlanma hesabı istemcide.
- V2: `phone`, `website`, `address` kolonları; alıcı detayında "Mesaj gönder" (mevcut `find_or_create_direct_conversation` RPC, context_type='b2b_shop') ve "Ara".
- Doğrulanmış rozeti: **S1 guard migration'ı olmadan UI'a konmaz.**

### 7.5 Mesajlaşma birleştirme
Lead mini-chat'i ana Mesajlar'a taşımak orta boy iş (V2): `find_or_create_direct_conversation(context_type='b2b_lead', context_id=lead_id)` ile konuşma açıp `b2b_quote_lead_messages`'ı okumaya devam etmek yerine konuşma akışına geçiş. V1'de en azından alt nav rozetine lead mesaj sayısını eklemek.

### 7.6 Mobil
Tek sütun, 44px dokunma hedefleri (B2B küçük hedefler düzeltilir), form altında yapışkan "Kaydet", skeleton yükleme, offline/yavaş ağda `ErrorRetryState`.

---

## 8. Hızlı kazanımlar (≤1 gün, düşük risk, mevcut testlerle)

1. Wholesaler Panel kartlarını düzelt: "Ürün ekle" → `/pazar/magazam/urun-ekle`, "Mağazam" → `/pazar`, "Fiyat Duyuruları" kaldır (`role_panel_cards.dart`, `panel_v1_2_test.dart` güncellenir).
2. Kampanya `linked_product_id` yazımı + ürün seçici (bug).
3. Teklif Ağı'nda "Yanıtladın" rozeti ve butonu gizleme (istemci set kontrolü).
4. Mağaza düzenle formuna çift-gönderim + `DirtyFormGuard` (diğer iki formdaki kalıp kopyalanır).
5. Mağazam: yalnız yayındaki ürünleri "Öne çıkan"da göster; süresi dolmuş kampanyaya rozet.
6. Türkçe `trUpper`/Türkçe-duyarlı lower B2B'de.
7. Supabase Dashboard: leaked password protection AÇ; bucket boyut/MIME limitleri (kod değişikliği yok).
8. `dealer_return_form_screen` + `group_create_screen` çift-gönderim guard'ı (veri bütünlüğü).
9. `textMuted`'ı `bodySmall` varsayılanından çıkarıp `textSecondary`'ye çek (tek satır tema değişikliği, golden testleri güncellenir).
10. `supabase_b2b_repository.dart` ve form başlıklarındaki "HENÜZ AKTİF DEĞİL / mock" yorumlarını temizle; `pazar_coming_soon_screen.dart` sil.

---

## 9. Önceliklendirilmiş yol haritası

| Sprint | Kapsam | Tür | Risk |
|---|---|---|---|
| **S1 — Tedarikçi Panel ana ekranı** | §7.1 V1 + hızlı kazanım 1,5,10 | UI, yeni tablo yok | Düşük |
| **S2 — Talepler yeniden yapı** | §7.2 V1 (segmentler, yanıtladım, ürün bağlamı, filtre) + hızlı kazanım 3 | UI + istemci map | Düşük |
| **S3 — Ürün/kampanya yönetimi** | sil/çoğalt, linked_product fix, formlar, küçük hedefler | UI + 1 bug | Düşük |
| **S4 — Güvenlik guard migration'ı** | S1/S2/S3/S5 kolon guard'ları + bucket limitleri + HIBP | Additif migration + RLS smoke | Orta (RLS smoke şart) |
| **S5 — Mağaza profili V1 + V2 kolonları** | il/ilçe, telefon/web/adres, tamamlanma, alıcıya mesaj/ara | Additif migration | Düşük |
| **S6 — Talep V2** | yeni talep bildirimi, RPC filtre/sayfalama, B2B repo limitleri | Migration + repo | Orta |
| **S7 — Mesajlaşma birleştirme** | lead chat → Mesajlar | Orta boy | Orta |
| **S8 — İşletme deneyimi** | Fırın Paneli giriş, dealers spinner/retry hijyeni, çift-gönderim | UI | Düşük |
| **S9 — Bireysel + keşif** | İlanlar sayfalama, view_count, arama | Repo + UI | Düşük |
| **S10 — Tasarım sistemi borcu** | token'laştırma (semantik renk, fontSize ölçeği), kontrast, sarı metin, skeleton standardı, ölü route temizliği | Geniş ama mekanik | Düşük-orta (golden) |
| Paralel, repo dışı | Mailbox + DNS → e-posta geçiş PR'ı (§1.4); ödeme açılmadan tedarikçi ilan ücreti kararı | — | — |

---

## 10. İlk geliştirilecek sayfa ve gerekçe

**Tedarikçi Panel ana ekranı (`role_dashboard_screen.dart` wholesaler dalı + `role_panel_cards.dart:166-209`).**

Gerekçe:
1. Tedarikçinin her girişte gördüğü ilk ekran; bugün sıfır canlı veri ve iki yanlış hedefli kart içeriyor. Sorun ağırlığı × görülme sıklığı en yüksek.
2. Gereken tüm veri mevcut provider'lardan geliyor; **yeni tablo, migration, RLS yok** → en düşük risk, en hızlı önce/sonra farkı.
3. Panel'i B2B mağazaya bağlamak, sonraki sprintlerin (Talepler, ürün yönetimi) keşfedilebilirliğini çözer; sıralama bağımlılığı bu yüzden.
4. Canlıda 1 tedarikçi mağazası var; kullanıcı davranışı henüz oluşmadığından bugün değiştirmenin kırılma maliyeti sıfıra yakın.

Kabul kriterleri: Panel 3 KPI + tamamlanma şeridi + 4 hızlı işlem gerçek veriyle; "Yakında" kart yok; `panel_v1_2_test` + yeni widget testi; `flutter analyze` temiz; emülatörde frame-skip 0; commercial/individual panelleri değişmez (regresyon golden).

---

## 11. Ticari değer analizi (Aşama 7)

**Düzenli giriş gerektirecek somut değer:** gelen teklif talepleri ve "ilgilenen" müşteriler. Bugün tedarikçi yeni talepten haberdar edilmiyor (bildirim yalnız lead/mesaj/kabul'de) ve talebi yanıtlayıp yanıtlamadığını göremiyor. Bu iki boşluk kapanmadan hiçbir görsel iyileştirme geri dönüş yaratmaz.

**A. Mevcut altyapıyla hemen:** Panel KPI'ları; Talepler segmentleri; talep → ürün bağlamı; yanıtladım/kazandım görünürlüğü; mağaza tamamlanma; "Öne çıkan" doğru filtre; Müşteriler (Bayi Paneli) ile B2B lead'i aynı kişiye bağlayan basit "Müşteri olarak ekle" kısayolu (`/wholesale/customers/new` prefill).

**B. Küçük geliştirmeyle:** yeni talep push bildirimi (kategori/bölge eşleşmeli trigger); talep filtre/sayfalama RPC; ürün fiyat/birim/bulunabilirlik kolonları; çoklu görsel; mağaza iletişim alanları + alıcıdan mesaj; B2B içerik raporlama target'ı; ürün görüntülenme sayacı (`b2b_products.view_count` + RPC increment, debounce) → "ilanlarımın performansı" için ilk gerçek metrik.

**C. Yeni mimari/yatırım:** yapılandırılmış teklif (tutar, miktar, geçerlilik, revizyon); sipariş/teslimat takibi; CRM pipeline; doğrulanmış firma süreci (belge + backoffice onayı → admin paneli gerektirir); tedarikçi analitik panosu; fiyat listesi yayını (kaldırılan "Fiyat Duyuruları" kartının gerçek karşılığı; kota/Premium özelliği olarak gelir modeline uyar).

**Gelir modeliyle uyum:** Lansman (→2027-10-01) boyunca tüm tedarikçiler Premium limitli; bu süre "premium alışkanlığı" yaratmak için kullanılmalı: Panel'de lansman hediyesini ve bitiş tarihini görünür tutmak, Free'ye düşüşte neyi kaybedeceğini (ürün 1, kampanya 0, yanıt 3) KPI satırında göstermek. Ödemeler açılmadan tedarikçi ilan ücreti muafiyeti kararı netleşmeli (§4.3).

**Gereksiz karmaşa oluşturacaklar:** sipariş/fatura modülü, çok kullanıcılı tedarikçi hesabı, stok yönetimi, B2B'de ayrı mesajlaşma sistemi (mevcut kopukluğu artırır).

---

## 12. Ajan bulgularında düzeltilenler
- "Tedarikçi lansman kampanyası pasif (start null)" iddiası **yanlış**: canlıda start=2026-09-25, aktif.
- Policy `{public}` olan `market_listings_select_active_or_own` anon'a açık değil: anon'a tablo grant'i yok `[CANLI]`.

## 13. Bu turda yapılmayanlar (kasıtlı)
Geniş yeniden tasarım, migration, dağıtım, e-posta değişikliği (mailbox hazır değil), Supabase Dashboard ayar değişikliği (HIBP/bucket limitleri — sahibin onayıyla yapılmalı).
