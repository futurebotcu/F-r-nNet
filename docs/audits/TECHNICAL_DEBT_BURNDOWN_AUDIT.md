# FırınNet Technical Debt Burn-down Report

Tarih: 2026-06-12 · Önceki HEAD: `ff47cae` · Yöntem: 4 paralel modül denetimi + birim/kaynak-sözleşme testleri + emülatör runtime smoke (Choreographer frame-skip). UI Faz 2 öncesi state/perf/release temelini temizlemek.

## Genel Verdict
Faz 2 UI'ya geçmeden önceki state/perf/release teknik borçları kapatıldı. Ana kazanım: **tick-split** (içerik vs yapısal) ile beğeni/yorum/hareket mutasyonları artık ilgisiz provider'ları recompute etmiyor (görünmez query storm kesildi). Yorum sayacı paged feed'i yeniden çekmeden dar güncelleniyor. Repo controller'ları rebuild'de kapatılıyor. Release minify/proguard hazırlandı. **Runtime/state temeli UI cilası için temiz.**

## Closed Debt

| ID | Alan | Borç | Fix | Before | After |
|----|------|------|-----|--------|-------|
| TD-1 | Dealer tick | hareket → 11 provider recompute | içerik tick'i ayrıldı (`_notifyContent`/`watchContent`/`dealerContentChangesProvider`); hareket/fiyat/not içerik, bayi ekle/düzenle/aktif yapısal | hareket → tüm bayi listesi + diğer bayiler recompute | hareket → yalnız o bayinin tx/bakiye/aktivite slice'ı |
| TD-2 | Feed tick | like/save/yorum → tüm paged feed refetch | içerik tick'i ayrıldı; like/save/yorum içerik, post create/sil/düzenle/medya yapısal | beğeni → paged feed (20 post) yeniden çekilir | beğeni → paged feed refetch YOK (optimistik override yeterli) |
| TD-3 | Feed yorum sayacı | yorum sonrası kart sayacı stale (pull-refresh'e kadar) | `feedCommentCountOverrideProvider` (keepAlive, max(model,override)); yorum gönderiminde +1 | sayaç eski kalır VEYA feed komple reload | dar +1, feed reload YOK, çift sayım YOK (V1 add-only) |
| TD-4 | Repo dispose | provider rebuild'de (login/logout) broadcast controller leak | dealer/feed/group repo'ya `dispose()` + provider'da `ref.onDispose(repo.dispose)` | her auth değişiminde küçük controller leak | rebuild'de controller'lar kapatılır |
| TD-5 | Release build | minify/shrink kapalı, proguard yok | `proguard-rules.pro` + release `isMinifyEnabled`/`isShrinkResources`/`proguardFiles` | minify yok | hazır (gradle parse + debug build doğrulandı; runtime release teyidi signing makinesinde) |

## Tick Split — tamamlananlar ve kararlar

| Modül | Karar | Gerekçe |
|-------|-------|---------|
| **Dealer** | ✅ split | hareket 11 provider'ı tetikliyordu (en büyük storm) |
| **Feed** | ✅ split | like/save/yorum tüm paged feed'i refetch ediyordu |
| **Groups** | ✅ zaten split (önceki sprint) | referans kalıp |
| Messaging | ⏸️ kasıtlı split YOK | konuşma listesi mesaj içeriğine **meşru** bağımlı (son-mesaj önizleme + unread + reorder); mesaj-gönderimi orada saf "içerik" değil. Ayrıca generic chat zaten optimistik (InMemoryChatController). Split son-mesaj önizlemeyi bozardı. |
| Market / Jobs | ❌ split gereksiz | tüm mutasyonlar içerik (ilan listesi); yapısal/içerik ayrımı yok |
| Recipe / Comments | ❌ split gereksiz | tek-provider modül, storm yok |

## Optimistic / Local Patch — domain politikası (denetim)

| Domain | Mevcut | Karar |
|--------|--------|-------|
| Generic DM | ✅ optimistik (`_seenMessageIds` dedup + retry) | **referans kalıp** — değişmedi |
| Like / Save | ✅ optimistik (`_likedOverride`/`_likeCountOverride` + revert) | **referans kalıp** — değişmedi |
| Yorum sayacı | ➕ dar override eklendi (TD-3) | instant feel, feed reload yok |
| Block | ✅ kısmi optimistik (sync cache `_blockedCache`) | değişmedi |
| Yorum create | server-confirmed + skipLoadingOnReload | yeterli (liste flash yok); yeni optimistik bubble riskli → eklenmedi |
| Post create | server-confirmed | nadir işlem, kabul |
| Market/Job listing | server-confirmed | kabul |
| **Recipe create/edit** | server-confirmed | 🔴 calc-sensitive — optimistik YAPILMAZ (concurrent edit malzeme oranını bozar) |
| **Dealer add/edit + hareket** | server-confirmed + dar refresh | 🔴 finansal — optimistik YAPILMAZ; bakiye gerçek tx'ten türetilir |

Sonuç: güvenli optimistik zaten mevcuttu; calc/finansal alanlar bilinçli server-confirmed bırakıldı (correctness). Tek eklenen güvenli dar güncelleme = yorum sayacı.

## Recipe Calculator Debounce
**Gerek yok — zaten optimal.** Denetim: `_recalculate()` yalnız initState (90), kayıt yükleme (153) ve manuel "Hesabı yenile" butonunda (454) çağrılıyor; **her tuş vuruşunda recompute YOK**. Hesaplama O(n), <1ms. Form state TextEditingController'larda (debounce'tan etkilenmez). Tuş-tetikli jank olmadığı için debounce eklenmedi.

## Pagination — market/jobs (defer, gerekçeli P2)
- **Feed:** offset-based (20/sayfa), dedup'lu, infinite scroll — referans, sağlam.
- **Market / Jobs:** tek-shot `.limit(100)`, infinite scroll yok.
- **Karar: cursor pagination ERTELENDİ (P2).** Gerekçe: (1) ≈ yeni özellik (load-more UI + state) — "yeni feature yok" kuralı; (2) iş/panel tabloları şu an ~boş, 100 limit fazlasıyla yeterli; (3) offset→cursor dönüşümü concurrent silmede satır atlama riski taşır, kapsamlı test ister. Hazır reçete: `created_at DESC, id DESC` bileşik cursor, `created_at < last OR (created_at == last AND id < lastId)`. Ölçek büyüyünce uygulanmalı.

## Release Build (minify / tree-shake-icons)
- `android/app/proguard-rules.pro` eklendi (Flutter + Supabase/OkHttp + Kotlin keep'leri; minify kapalıyken etkisiz).
- Release block'a `isMinifyEnabled = true` + `isShrinkResources = true` + `proguardFiles(proguard-android-optimize.txt, proguard-rules.pro)` eklendi.
- `uses-material-design: true` mevcut → `--tree-shake-icons` hazır.
- **Doğrulama durumu:** gradle config parse edildi + debug build başarılı (release block dahil değerlendiriliyor). **Release APK/AAB bu ortamda build EDİLEMEDİ** — `key.properties` (signing) yok ve fail-fast hook release task'ını durduruyor (kasıtlı güvenlik). Dolayısıyla **release minify runtime'da teyit edilmedi**; ilk release build signing makinesinde cihaz smoke'u ile doğrulanmalı (store öncesi zaten zorunlu adım). R8 bir şeyi kırarsa ilk bakılacak yer proguard-rules.pro.
- Boyut: debug APK ~231MB (JIT, temsili değil); önceki profile build ~99MB. Release+minify daha küçük beklenir (asıl kazanım AOT'tan; minify host Kotlin/Java katmanında ek kazanç). Signing makinesinde ölçülmeli.
- Signing secret üretilmedi/commit edilmedi.

## Dispose / Memory
- **Düzeltildi:** dealer + feed + group repo'larına `dispose()` (controller.close) + provider'da `ref.onDispose(repo.dispose)` → login/logout rebuild'inde broadcast controller leak'i kapatıldı. (group, önceki sprint P2 olarak işaretliydi.)
- **Kabul (app-lifetime, düşük risk):** kalan ~11 Supabase repo + Local repo'ların tek `_changes` controller'ı; bunlar provider-managed singleton (oturum ömrü), per-rebuild leak ihmal edilebilir. Kalıp artık kurulu, gerekirse genişletilir.
- **Zaten doğru (denetim):** tüm TextEditingController/Video/Chewie/Animation/FocusNode/Timer/ScrollController/StreamSubscription dispose ediliyor; realtime kanal `onCancel` ile temizleniyor. Yeni leak bulunmadı.

## Verification
- analyze: **temiz** · test: **1450/1450** (15 yeni burndown testi: tick-split kaynak-sözleşmesi + override BİRİM testi + dispose + release config) · debug APK build ✓.
- **Runtime smoke (emülatör, ÖLÇÜLDÜ):** tick-split refactor sonrası app stabil açıldı (crash yok); 5-tab navigasyon **0 frame-skip**, feed scroll (7 gesture) **0**, beğeni/etkileşim tap'leri **0**, FATAL/flutter exception/kırmızı ekran **0**. (adb tek-surface kör-tık kalibrasyonu nedeniyle yorum-gönder write akışı görsel olarak sürülemedi; davranış 15 testle + override birim testiyle kapatıldı.)
- Davranış/RLS/data **değişmedi**; finansal hesap mantığı **değişmedi**.

## Remaining P2
- Market/jobs cursor pagination (ölçek büyüyünce).
- Optimistik local insert (post/comment/dealer-list) — şu an server-confirmed + skipLoadingOnReload yeterli.
- Kalan repo'lara dispose genişletme (ihmal edilebilir leak).
- Release minify'ın signing makinesinde cihaz teyidi (store öncesi zorunlu).
- Comments-page header sayacı override'a bağlama (ikincil yüzey; liste zaten anında güncelleniyor).

## Final Recommendation
State/perf/release teknik borçları kapandı veya gerekçeyle P2'ye ertelendi. Runtime smoke jank/crash göstermedi, 1450 test yeşil. **Faz 2 UI Quality sprintine geçilebilir** — temel temiz.
