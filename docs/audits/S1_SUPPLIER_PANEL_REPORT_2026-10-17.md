# S1 — Tedarikçi Paneli Ana Ekranı: Sprint Raporu

**Tarih:** 2026-10-17 · **Dal:** `feat/supplier-panel-s1` (base: `audit/system-audit-2026-10-16` → main `2934f4b`) · **Durum:** TAMAMLANDI, onay bekliyor · **Production dağıtımı:** YOK · **DB değişikliği:** YOK

Referans: `SYSTEM_AUDIT_SUPPLIER_PANEL_2026-10-16.md` (§7.1, §8, §10) ve `S1_SECURITY_IMPACT_B2B_GUARDS.md`.

## 1. Kapsam doğrulaması (talep edilen madde 1)

| Rapor maddesi | Koddaki karşılığı | Durum |
|---|---|---|
| §7.1 Panel ana ekranı V1 | `lib/features/dashboard/widgets/supplier_panel_home.dart` (yeni), `role_dashboard_screen.dart` wholesaler dalı | ✅ |
| Hızlı kazanım 1 — kart hedefleri | `role_panel_cards.dart:166-209`: "Ürün/Hizmet İlanı Ver" (`/market/listings/new`, ekipman ilanı) ve "Firma Profilim" (`/profile`, sosyal profil) kaldırıldı; B2B ürün/mağaza girişleri SupplierPanelHome hızlı işlemlerine taşındı; "Duyuru / Fiyat Listesi (Yakında)" kaldırıldı | ✅ |
| Hızlı kazanım 5 — Mağazam filtreleri | `supplier_store_tab.dart`: "Öne çıkan ürünler" yalnız `published`, "Aktif kampanyalar" yalnız `published && !isExpired`; boş durumda yönlendirici ipucu; paywall/plan kartı sayımı sunucuyla aynı küme | ✅ |
| Hızlı kazanım 10 — bayat yorum/ölü dosya | `pazar_coming_soon_screen.dart` silindi; `supabase_b2b_repository.dart`, 3 form başlığı, `premium_bottom_nav.dart` yorumları güncellendi; `navigation_ia_test` düzeltildi | ✅ |
| Gereken altyapı | Yeni tablo/RPC/migration **yok**; yalnız `/pazar?tab=` query param + `B2bCampaign.isExpired` yardımcı | ✅ |

## 2. Önceki panelin sorunları (kanıt: denetim §4.1, §5 #1)

1. Tedarikçi girişte **sıfır canlı veri** görüyordu (yalnız okunmamış mesaj rozeti).
2. "Ürün/Hizmet İlanı Ver" kartı **B2B ürün değil ekipman ilanı** formunu açıyordu.
3. "Firma Profilim" kartı **B2B mağazaya değil sosyal profile** gidiyordu.
4. "Duyuru / Fiyat Listesi" kartı tıklanınca "Yakında aktif olacak" snackbar'ı — boş vaat.
5. Panel'den B2B mağazaya, ürünlere, taleplere **hiç link yoktu**; tedarikçi Pazar sekmesini kendisi keşfetmek zorundaydı.
6. Mağazam'da "Öne çıkan ürünler" taslakları, "Aktif kampanyalar" süresi dolmuşları gösteriyordu; kampanya paywall sayımı sunucuyla uyumsuzdu (erken kilit).

## 3. Yapılan değişiklikler (commit'ler)

| Commit | İçerik |
|---|---|
| `84b01c0` b2b | `B2bCampaign.isExpiredAt/isExpired/isActive`; Mağazam filtreleri + ipuçları; plan kartı/paywall aktif kampanya sayımı. (Not: `pazar_coming_soon_screen.dart` silme bu commit'e girdi.) |
| `75b3638` router | `AppRoutes.pazarTab('magazam'|'talepler'|…)`; `B2bShellScreen(initialTab:)` + `resolveTab` + `didUpdateWidget` (Panel'den `go` ile sekme değişimi) |
| `a2d4da8` panel | `SupplierPanelHome`: Mağaza durumu kartı (logo/ad/bölge-kategori/plan rozeti + 5 adımlı tamamlanma çubuğu) · "Bugün" 4 KPI · 4 hızlı işlem · mağaza-yok CTA · skeleton · ErrorRetryState. Wholesaler kartları "Diğer araçlar": Müşteriler / Gelen Mesajlar / Anlaşmalı İş Yerleri. 36 yeni AppStrings. Testler + PNG yakalama testi. |
| `cab2bcb` cleanup | Bayat yorumlar, nav testi |
| (bu commit) docs | S1 raporu, güvenlik etki analizi, ekran görüntüleri |

### Veri kaynakları (hepsi mevcut provider)
`b2bMyStoreProvider` · `b2bMyProductsProvider` · `b2bMyCampaignsProvider` · `b2bOpenQuoteRequestsProvider` (RPC, anonim) · `b2bSupplierLeadsProvider` (RLS: yalnız kendi mağazası) · `myEntitlementProvider`.

### KPI tanımları (dürüst etiketler)
- **Açık talep** = ağdaki tüm açık/yanıt bekleyen talepler (global; "benim yanıtlamadıklarım" S2'de). Yardımcı metin bunu söyler: "Ağdaki teklif talepleri".
- **Yayında ürün** = `published` ürün sayısı / plan limiti (sınırsızsa yalnız sayı); taslak varsa "n taslak".
- **Aktif kampanya** = yayında + süresi dolmamış / limit; pasif varsa "n süresi dolmuş".
- **İlgilenen** = `interested` lead sayısı.

### Durum yönetimi
- İlk yükleme: `PremiumListSkeleton` (3 satır). Yenileme: `skipLoadingOnReload` (spinner flash yok).
- Mağaza hatası: `ErrorRetryState` → tüm 5 provider invalidate; "Diğer araçlar" etkilenmez.
- Mağaza yok (`id` boş): tek CTA kartı "Mağaza bilgilerini gir" → `/pazar/magazam/duzenle`; KPI/hızlı işlemler yine görünür.
- Yetki: widget yalnız `AccountType.wholesaler` için kurulur; commercial/individual panelleri değişmedi (test). Yazma kısıtı server-side; "Ürün ekle"/"Kampanya oluştur" paywall aynası (`SupplierPaywall.productLock/campaignLock`), entitlement yüklenmemişse form açılır (sunucu korur, Mağazam ile aynı kural).

## 4. Görsel çıktılar

`docs/audits/s1/` (widget-test ile gerçek Inter/Roboto fontlarıyla render, 2x):

| Dosya | Senaryo |
|---|---|
| `panel_wholesaler_store_390x844.png` | Mağaza var, Premium (lansman hediyesi rozeti), telefon viewport |
| `panel_wholesaler_store_full_free.png` | Tam sayfa, Free plan ("3 / 1", "2 / 0" mock seed limit üstü — gerçek Free hesapta sunucu zaten kapatır) |
| `panel_wholesaler_no_store.png` | İlk giriş, mağaza yok → CTA kartı (*buton etiketi yakalama ortamında font fallback'i nedeniyle kutu çiziyor; cihazda normal*) |
| `panel_wholesaler_320_x1_3.png` | 320px dar ekran, 1.3x yazı — taşma yok |

Cihaz/emülatör ekran görüntüsü alınmadı: bu makinede emülatör PATH'te değil ve canlı tedarikçi hesabı kimlik bilgisi yok. Widget yakalama deterministik ve tekrarlanabilir (`flutter test test/golden/supplier_panel_s1_capture_test.dart`).

## 5. Mobil kullanım değerlendirmesi

- **Tek sütun, baş parmak bölgesi:** hızlı işlemler ve KPI 2×2 grid, kartlar tam genişlik; tüm dokunma hedefleri ≥ 44px (QuickActionMini/PremiumCard/KPI tile tam kart alanı).
- **320px + 1.3x/1.5x:** taşma testi geçiyor; KPI etiketleri tek satır ellipsis ("Aktif kamp…"), hızlı işlem etiketleri 2 satır. 1.5x'te etiket kırpılması kabul edilebilir ama ideal değil → S2'de KPI etiketlerine 2 satır izni değerlendirilecek.
- **Yavaş ağ:** skeleton + hata/yeniden dene; KPI'lar tek tek "—" ile yüklenir, sayfa bloklanmaz.
- **Navigasyon:** Panel → `/pazar?tab=` `go` ile alt sekmeye geçer (nested push yok, geri tuşu davranışı AppShell PopScope ile aynı); formlar `push`.
- **Performans:** yeni sorgu yok; Panel açılışında 5 provider paralel (Mağazam zaten 3'ünü yüklüyor; +2: açık talepler RPC, lead'ler). `autoDispose` → sekmeden çıkınca bırakılır.

## 6. Test sonuçları

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test test/supplier_panel_home_test.dart test/panel_v1_2_test.dart test/navigation_ia_test.dart` | 53/53 |
| `flutter test --exclude-tags golden` (CI komutu) | **2955/2955 geçti** (önce 2.6k; yeni 21 test + mevcut) |
| `flutter test test/golden/supplier_panel_s1_capture_test.dart` | 4/4, PNG üretildi |
| `flutter build apk --debug` (CI adımı) | ✅ app-debug.apk üretildi (Gradle assembleDebug 157 s) |

Yeni testler: tamamlanma hesabı (taslak ürün saymaz), kampanya süresi (ISO/“Süresiz”/serbest metin), `resolveTab` (tedarikçi/alıcı), wholesaler kart listesi (yanlış hedefler yok, comingSoon yok, diğer roller değişmedi), widget: mağaza var / yok / hata / Free paywall (ürün, kampanya) / ticari-bireyselde yok / 320px ×3 ölçek.

## 7. Çözülmeyen riskler

1. **Güvenlik (DB):** `is_verified` sahip-yazılabilir, reply INSERT'te `accepted` serbest, alıcı `accepted_reply_id` yazabilir → etki analizi + taslak guard migration `S1_SECURITY_IMPACT_B2B_GUARDS.md`. Bugün kritik istismar **doğrulanmadı** (rozet UI'da yok; kabul akışı RPC'ye bağlı); uygulanması **onayınızı** bekliyor.
2. **"Açık talep" KPI'si global**: tedarikçinin yanıtladıkları ayrılmıyor (sunucu RPC `buyer_id` döndürmez, yanıt eşlemesi istemci tarafı set ile S2'de).
3. **Yeni talep bildirimi yok**: tedarikçi talepleri yalnız Panel/Teklif Ağı'na girince görür (S6 trigger).
4. **Mock limit üstü değerler** ("3 / 1"): gerçek Free hesapta oluşmaz; grandfathered durumda dürüst gösterim.
5. **Yakalama ortamı buton fontu**: yalnız PNG artefaktı, kod etkisi yok.
6. **Silme commit'i yanlış pakette**: `pazar_coming_soon_screen.dart` silmesi b2b commit'ine girdi (işlevsel etkisi yok; PR squash'ta önemsiz).
7. Emülatör/cihaz smoke yapılmadı (ortam); CI adımlarının tamamı (analyze / test / debug apk) yerelde yeşil.

## 8. S2 önerileri (Talepler yeniden yapı — denetim §7.2)

1. Teklif Ağı → **"Talepler"**: segmentler Yeni (yanıtlamadığım) · Yanıtladım · İlgilenenler · Kazanılan. Yanıt eşlemesi: `b2b_quote_replies` where supplier_shop_id = benim (mevcut select policy izin veriyor) → istemci set; "Teklif Ver" yanıtlananlarda gizlenir (23505 hatası son savunma kalır).
2. Talep kartında **hangi ürünüm/kampanyam/mağazam** (target_type/target_id istemci map; kendi ürün/kampanya listesi zaten yüklü).
3. **Filtre**: kategorilerim / bölgelerim (mağaza profilinden varsayılan) · tümü.
4. Panel KPI "Açık talep" → "Yanıt bekleyen" (benim yanıtlamadıklarım) + Panel'de son 3 talep önizlemesi.
5. Küçük hedefler: `b2b_quote_request_card` buton min 44px; KPI etiketi 2 satır.
6. Hazırlık (S4 için): guard migration onayı + RLS smoke planı.
