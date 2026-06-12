# FırınNet Navigation IA Report — Topluluk · Pazar · İlanlar · Mesajlar · Panel

Tarih: 2026-06-12 · Önceki HEAD: `e84e47d` · Yöntem: 2 paralel nav denetimi + sözleşme/davranış/widget testleri + emülatör runtime smoke. Ürün mimarisini sadeleştirme (UI redesign DEĞİL).

## Gelen nav yapısı

| # | Tab | İçerik |
|---|-----|--------|
| 1 | **Topluluk** | Feed (Genel Akış) + Gruplar — segmentli sosyal alan |
| 2 | **Pazar** | "Yakında" B2B/tedarik/teklif ağı yüzeyi (mini nokta rozet) |
| 3 | **İlanlar** | Eleman (jobs) + İş yeri (marketplace bakery_transfer) + Ekipman (marketplace equipment_sale) |
| 4 | **Mesajlar** | Tüm konuşmalar — alt nav'a çıktı, okunmamış sayaç rozeti |
| 5 | **Panel** | İşletme araçları merkezi (bozulmadı) |

## Feed + Gruplar nasıl birleşti
- Yeni `CommunityScreen` (`/community`): tek "Topluluk" başlığı + `SegmentTabBar` (Genel Akış / Gruplar) + **lazy IndexedStack**.
- Çocuk ekranlar `embedded: true` ile kendi `FirinNetHeader`'larını çizmez (tek başlık). `SocialFeedPage(embedded)` + `GroupsListScreen(embedded)`.
- Header aksiyonu segmente duyarlı: Genel Akış'ta profil avatarı (profil ana nav'dan çıktığı için tek erişim noktası korundu), Gruplar'da "+" grup oluştur.
- Feed scroll/takip-tümü segmenti, grup üyelik/composer P0 fixleri, post/comment/report/block/media davranışı **bozulmadı**.
- Lazy IndexedStack → segment değişiminde reload/spinner flash yok, ziyaret edilen segment canlı kalır (scroll korunur).

## İlanlar nasıl birleşti
- Yeni `ListingsScreen` (`/ilanlar`): tek "İlanlar" başlığı + segmentler + lazy IndexedStack.
- Eleman = `JobsScreen(embedded)` (iç "Usta Arıyor / İş Arıyor" alt-segmenti korundu).
- İş yeri = `MarketplaceScreen(embedded, forceListingType: bakery_transfer)`.
- Ekipman = `MarketplaceScreen(embedded, forceListingType: equipment_sale)`.
- Marketplace `listingType` ile temiz ayrılabilir (mevcut alan, schema değişmedi). Gömülü segmentte header + type-chip satırı gizli, filtre segmente kilitli.
- Segmente duyarlı "+" : Eleman → hesap tipine göre Usta Arıyor / İş Arıyor formu; İş yeri/Ekipman → marketplace ilan formu.
- **Düzeltilen bug:** forceListingType bir "aktif filtre" sayıldığı için boş segment "filtreli/Filtreleri temizle" gösteriyordu; "temizle" forced tipi sıfırlayıp segment kilidini kırabiliyordu. Düzeltildi: gömülüde sade "Henüz ilan yok / İlk ilanı oluştur" boş-state, "temizle" forced tipi korur.

## Pazar yakında
- Yeni `PazarComingSoonScreen` (`/pazar`): modern/sade/şeffaf coming-soon. Hero (handshake + "Yakında" rozeti + B2B vizyon copy) + 3 madde (Tedarikçileri keşfet / Teklif al / Ürün ve kampanyaları takip et) + footnote. **Backend/fake data YOK.**
- Alt nav Pazar tab'ında mini "Yakında" noktası rozeti.

## Mesajlar alt nav'a çıktı mı
- Evet. `/messages` artık shell TAB'i (eskiden Panel içinden full-screen push). `MessagesListScreen` korundu. `/messages/:id` (ChatScreen) shell DIŞINDA full-screen kalır → chat'ten geri Mesajlar listesine döner.
- **Okunmamış rozeti:** `totalUnreadMessagesProvider` (değişmedi) alt nav Mesajlar item'ında `PremiumNavItem.badgeCount` ile gösterilir.
- Panel "Mesajlar" kartı korundu; artık `context.go` (tab geçişi) ile çalışır (nested shell push önlendi).

## Panel bozuldu mu
- Hayır. RoleDashboardScreen + bayi/gün sonu/raporlar/reçeteler/ayarlar dokunulmadı. `_onTap` tab-route seti yeni nav + legacy redirect route'larını kapsayacak şekilde güncellendi (Mesajlar kartı dahil go ile geçer).

## Eski route'lar ne oldu (geriye dönük uyumluluk)
- `/feed` → `/community` redirect
- `/groups` → `/community?seg=groups` redirect
- `/jobs` → `/ilanlar` redirect
- `/market` → `/ilanlar?seg=isyeri` redirect
- `/messages/:id`, `/market/listings/:id`, `/market/listings/new`, `/jobs/offers/new`, `/worker/job-seek/new`, `/groups/:id`, `/groups/create` — **dokunulmadı**, çalışır.
- feed_boundary CTA'ları (`/market`, `/market/listings/new`) redirect/var olan route ile çözülür — kırılmadı.

## State / performans korundu mu
- Tab geçişi mevcut `ShellRoute` + `context.go` mimarisi (değişmedi; cross-tab state önceki davranışla aynı).
- Segment geçişi lazy IndexedStack → reload yok, spinner flash yok, provider storm yok.
- Önceki sprintlerin perf kazanımları (tick-split, skipLoadingOnReload, signed-URL cache, N+1, memCacheWidth) **bozulmadı** (embedded child'lar aynı provider'ları kullanır).

## Verification
- analyze: **temiz** · test: **1469/1469** (18 yeni nav IA testi: sözleşme + redirect + embedded param + 5 widget render testi; golden baseline yeni IA'ya güncellendi) · debug APK ✓.
- **Runtime smoke (emülatör, ÖLÇÜLDÜ):** 5 tab + segmentler gerçek cihazda gezildi. Alt nav doğru (Topluluk/Pazar+Yakında nokta/İlanlar/Mesajlar/Panel). Topluluk Genel Akış↔Gruplar segment geçişi + İlanlar Eleman↔İş yeri↔Ekipman geçişi **0 frame-skip**. Pazar coming-soon + İş yeri sade boş-state render OK. Header segmente duyarlı aksiyon (profil avatar ↔ grup "+"). FATAL/exception/kırmızı ekran/logout: **0** (tüm oturum).
- Supabase schema/RLS/data/repository davranışı **değişmedi** (kapsam yalnız client nav/UI kompozisyon).

## Kalan P2 (Faz 2 UI Quality)
- Topluluk Genel Akış segmenti, feed'in kendi "Genel Akış / Takip Edilenler" toggle'ı ile yan yana → "Genel Akış" etiketi iki kez görünür (üst segment + alt toggle). Spec segment adını "Genel Akış" istedi; iki bar görsel sadeleştirme adayı (UI sprinti).
- İş yeri/Ekipman "+" deep preselect (listing_type formda hazır gelsin) — şu an form açılır, tip kullanıcı seçer.
- StatefulShellRoute/IndexedStack ile cross-tab state preservation (opsiyonel; mevcut davranış korundu).

## Final
Alt nav yapısı net: Topluluk = sosyal alan, Pazar = yakında B2B, İlanlar = eleman/iş yeri/ekipman, Mesajlar = tüm konuşmalar, Panel = işletme araçları. Eski route'lar redirect ile korundu, davranış/RLS/perf bozulmadı, 1469 test yeşil, runtime smoke temiz (0 jank/crash). IA sadeleşmesi tamam.
