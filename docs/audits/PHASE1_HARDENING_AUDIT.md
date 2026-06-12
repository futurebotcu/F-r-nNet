# FırınNet Faz 1 — Hardening & Release Candidate Audit

Tarih: 2026-06-12 · HEAD öncesi: `fe7ed13` · Denetim: 4 paralel kod agent'ı + Supabase read-only + Supabase advisors.

## Genel Verdict

- **Android closed-beta:** ✅ kod tarafı hazır. Bloker: marka app icon (P1, onaylı asset bekliyor). İzinler sahada (emülatör) video gönderimiyle çalıştığı kanıtlı.
- **iOS TestFlight:** 🟠 2 bloker: (1) onaylı app icon (P0), (2) macOS/Xcode signing (P0, Windows'tan yapılamaz). Mikrofon izni bu sprintte eklendi.
- **Bilinen P0 (fonksiyonel):** kalmadı — kritik akışlar (auth/session, mesajlaşma, gruplar, medya, feed/UGC, market/ilan, panel/bayi) denetlendi; bulunan P0-sınıfı kalıp (provider obje-watch) düzeltildi.
- **Codebase sağlığı:** ~8.5/10 — çekirdek kalıplar sağlam, mimari borç yok.

## Denetlenen Alanlar
codebase mimari · bilinen-P0 kalıpları · error/loading/empty + dispose/leak · performans desenleri · store readiness · repo/secrets · Supabase/RLS + advisors · CI/build.

## P0 Fixed (bu sprint)

| ID | Alan | Root Cause | Fix |
|----|------|-----------|-----|
| H-1 | 7 repository provider (feed/messaging/market/jobs/worker/bakery/recipe/dealer) | `currentAuthUserProvider` OBJE watch ediliyordu; AuthUser'da `==` yok → token refresh/app resume her seferinde repo + in-memory cache resetliyordu (grup composer P0'ının kök kalıbı). | `.select((u) => u?.id)` — yalnız userId izlenir; davranış birebir aynı, rebuild fırtınası ve cache kaybı engellendi. |

## P0 Remaining (otomatik çözülemez)

| ID | Alan | Problem | Etki | Neden | Aksiyon |
|----|------|---------|------|-------|---------|
| R-1 | iOS app icon | Varsayılan Flutter placeholder | App Store otomatik red | Onaylı 1024px marka asseti repo'da yok (uydurulamaz) | Kullanıcı icon sağlar → `flutter_launcher_icons` |
| R-2 | iOS signing/IPA/TestFlight | macOS+Xcode+Apple hesabı gerekir | iOS dağıtım imkânsız | Windows ortamı | Mac/macOS CI |

## P1 (closed beta öncesi)

| ID | Alan | Problem | Etki | Aksiyon |
|----|------|---------|------|---------|
| P1-1 | iOS mikrofon izni | Video kaydı mikrofona erişir, plist string yoktu → crash riski | iOS video kayıt çökme | **FIXED bu sprint** — NSMicrophoneUsageDescription eklendi |
| P1-2 | Sorgu limitleri | follow/market-mine/jobs-myoffers/stories/listGroups limitsizdi | Yüksek hacimde RAM/ANR | **FIXED bu sprint** — defansif `.limit()` eklendi |
| P1-3 | Android marka icon + adaptive | Varsayılan Flutter icon, adaptive yok | Zayıf marka (red değil) | Onaylı icon → launcher icons |
| P1-4 | listConversations N+1 | Konuşma başına ayrı son-mesaj SELECT (50 conv = 50 sorgu) | Mesaj listesi açılış gecikmesi | RPC/view ile tek sorguya birleştir |
| P1-5 | Signed URL storm | listMessages/listGroupMessages her medya mesajına paralel createSignedUrl | Chat açılış lag | DB cache (TTL) veya client LRU |
| P1-6 | Privacy/account-deletion URL'leri | GitHub Pages canlılığı doğrulanmadı | iOS review red riski | URL'leri tarayıcıda teyit et |
| P1-7 | EULA/ToS in-app gösterim | Terms ekranı route'lu ama signup öncesi onay akışı yok | iOS isteyebilir | Signup'a ToS onayı ekle (P1) |

## P2 (Faz 2 / sonraya)

| ID | Alan | Problem | Neden |
|----|------|---------|-------|
| P2-1 | CachedNetworkImage memCacheWidth | Full-res decode → bellek spike | Görüntü kalitesi etkisi; ölçülü test gerek |
| P2-2 | Provider invalidation granülerliği | like/save 4 provider invalidate | Optimistic UI refactor; risk |
| P2-3 | SocialPostCard rebuild | her build Theme.of/_timeAgo | StatelessWidget migration |
| P2-4 | Public bucket listing (avatars/feed/market/story) | broad SELECT policy listeleme izni veriyor (advisor WARN) | Object URL erişimi için gerekmez; sıkılaştırma ayrı doğrulama ister |
| P2-5 | SECURITY DEFINER fn'ler anon/auth execute (advisor WARN) | bump_conversation_updated_at, rls_auto_enable anon'a açık | Zararsız (destructive değil); revoke temizliği |
| P2-6 | Leaked password protection (advisor WARN) | HaveIBeenPwned kapalı | Supabase Auth ayarı (dashboard) |
| P2-7 | Android enableOnBackInvokedCallback=false | Predictive back kapalı | go_router back testi gerek |

## Performans Notları

- **Cold start:** emülatörde `am start -W` ~ hızlı (warm); splash 700ms timer yok, ilk frame Supabase init'e bağlı ~400-500ms. Kabul edilebilir.
- **En büyük riskler:** signed URL storm + listConversations N+1 (ikisi de P1, davranış doğru ama ölçek riski). Sorgu limitleri bu sprintte kapatıldı.
- **APK:** debug ~231MB (debug normal); release shrink/minify + tree-shake-icons önerilir (P2).
- **Leak:** repository broadcast StreamController'ları close edilmiyor (uzun oturumda küçük birikme) — P2; provider rebuild sıklığı select fix ile zaten azaldı.

## Supabase / Security

- **Project:** `sjeqwiqgwzagengdukye` (doğrulandı). **Migration:** 40, local/prod uyumlu.
- **RLS:** 39/39 tabloda açık. `firinnet_id_counters` RLS açık + policy yok = erişim tamamen kapalı (kasıtlı, güvenli).
- **anon yetkileri:** hiçbir tabloda INSERT/SELECT/UPDATE/DELETE YOK (yalnız REFERENCES/TRIGGER/TRUNCATE = Postgres default, pratik risk yok). **anon write imkânsız.**
- **Buckets:** chat-media **private** (signed URL). avatars/feed/market/story public — advisor "listing" WARN'ı P2.
- **content_reports/user_blocks:** select-own RLS; başka kullanıcıya görünmez ✓. Kullanıcıya update/delete YOK (moderasyon kuyruğu korunur) ✓.
- **delete-account Edge Function:** ACTIVE, verify_jwt=true ✓.
- **Secrets:** key.properties/.env/.jks/keystore **tracked DEĞİL**; yalnız .example'lar. Secret leak YOK. `.env.local` gitignore'lu.
- **Advisor:** tüm bulgular INFO/WARN (P0 yok). Production data write/update/delete YAPILMADI; schema/RLS DEĞİŞMEDİ.

## Değişen Dosyalar (bu sprint)
`feed/messaging/marketplace/jobs/worker/bakery_panel/dealers` providers (7 select fix) · `supabase_follow_repository` · `supabase_market_listing_repository` · `supabase_job_offer_repository` · `supabase_social_stories_repository` · `supabase_social_group_repository` (limitler) · `ios/Runner/Info.plist` (mikrofon) · docs/qa smoke checklist · bu doküman.

## Doğrulama
- flutter analyze: temiz · flutter test: **1385/1385** · git: junk dizini temizlendi (`CDEVFI~1` boş dizin git taramalarını bozuyordu).
