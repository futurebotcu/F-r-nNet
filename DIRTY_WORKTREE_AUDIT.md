# Dirty Worktree Audit

## Genel Verdict

Worktree yeni P0 ürün sprintleri için temiz değil. Kalan dirty set tek bir küçük
format artığı değil; 216 tracked modified dosya ve 1 untracked asset içeriyor.
Diffler tema, premium UI, sosyal modüller, marketplace, bayi defteri, repository,
provider, model ve test katmanlarına yayılmış durumda.

Bu sprintte otomatik restore/stash/commit yapılmadı. Sınıflandırma sonucuna göre
önce riskli ürün davranışı değişiklikleri sahiplenilmeli; ardından UI/polish
kalıntıları ayrı commit veya stash planına alınmalı. 14 dosya whitespace-only
olarak güvenli restore adayıdır, ancak yine de ayrı onayla restore edilmelidir.

## Dosya Sayısı Özeti

* Modified: 216 tracked file
* Added: 0 tracked file
* Deleted: 0 tracked file
* Untracked: 1 asset
* Format/Whitespace-only: 14 tracked file
* Gerçek içerik farkı: 202 tracked file

## Kategori A — Önceki Sprint Kalıntısı Olabilecekler

Bu grup ağırlıklı olarak UI/theme/premium component/screen değişiklikleri içeriyor.
Davranış etkisi olabilir, ancak repository/provider/model kadar kritik veri riski
taşımıyor. Lemon/premium UI polish, sosyal ekranlar, marketplace ekranları, bayi
ekran polish ve genel görsel düzenleme kalıntısı gibi duruyor.

| Dosya | Kategori | Diff Özeti | Risk | Önerilen Aksiyon |
|---|---|---|---|---|
| `lib/app/app.dart` | A | App bootstrap/UI wiring değişikliği, 4+/8- | Orta | Kaynağı belirlenene kadar dokunma; UI sprint kalıntısı olarak ayrı incele. |
| `lib/app/theme/*` | A | Tema renkleri, token, typography ve theme geniş değişiklikleri, 512+/376- | Orta | Lemon/theme sprint kalıntısı gibi; ayrı theme commit veya stash adayı. |
| `lib/core/constants/app_products.dart` | A | Ürün sabitlerinde küçük içerik farkı, 3+/4- | Orta | Ürün copy/data etkisi olabilir; ürün sprinti öncesi sahiplen. |
| `lib/core/data/*` | A | Taxonomy/location data küçük farklar, 6+/8- | Orta | Seed/taxonomy cleanup olabilir; ayrı data audit gerekir. |
| `lib/core/utils/number_formatter.dart` | A | Sayı formatlama util değişikliği, 5+/2- | Orta | Formatlama davranışı etkileyebilir; küçük ama testle doğrulanmalı. |
| `lib/core/widgets/*` | A | Shared widget, empty state, interaction, tag/chip/location UI farkları, 123+/102- | Orta | UI polish seti olarak grupla; shared widget olduğu için tek tek review et. |
| `lib/core/widgets/premium/*` | A | Premium cards/header/nav/metric/section bileşenleri, 314+/321- | Orta | Lemon/premium UI kalıntısı; golden etkisi olası, ayrı commit/stash. |
| `lib/features/auth/screens/*` ve `auth/widgets/*` | A | Auth ekranları ve social buttons UI/copy farkları, 101+/91- | Orta | Auth UX sprint kalıntısı olabilir; guard/repo dosyalarından ayrı commit edilmeli. |
| `lib/features/auth/utils/auth_error_translator.dart` | A | Error copy mapping küçük fark, 1+/3- | Orta | Kullanıcı hata metni değişebilir; auth copy commit adayı. |
| `lib/features/bakery_panel/screens/*` | A | Bakery panel, recipe, calculator, report ekranları, 291+/272- | Orta | Panel UI/polish kalıntısı; hesaplama servislerinden ayrı tutulmalı. |
| `lib/features/dashboard/screens/role_dashboard_screen.dart` | A | Dashboard UI farkı, 16+/25- | Orta | Ana giriş akışı etkisi olabilir; dashboard UI commit adayı. |
| `lib/features/dealers/screens/*` | A | Bayi ekranları, list/report/share/form ekran farkları, 280+/275- | Orta | Bayi UI sprint kalıntısı olabilir; repository/service dosyalarından ayrı review. |
| `lib/features/dealers/widgets/*` | A | Bayi widget polish ve hesap makinesi UI farkları, 114+/83- | Orta | Bayi UI commit adayı; `cash_tendered_calculator` ayrıca testlenmeli. |
| `lib/features/feed/widgets/insight_card.dart` | A | Feed insight widget küçük fark, 2+/8- | Düşük-Orta | Sosyal UI setine ekle. |
| `lib/features/jobs/screens/*` | A | İş ilanı ekran UI farkları, 52+/48- | Orta | Jobs UI sprint kalıntısı olarak ayrı incele. |
| `lib/features/legal/screens/*` | A | Legal ekran küçük farklar, 2+/6- | Düşük-Orta | Copy/layout etkisi; ayrı küçük commit olabilir. |
| `lib/features/marketplace/data/marketplace_taxonomy.dart` | A | Marketplace taxonomy küçük fark, 1+/2- | Orta | Data etkisi olabilir; marketplace setiyle review. |
| `lib/features/marketplace/screens/*` ve `widgets/*` | A | Marketplace ekran/widget geniş UI farkları, 422+/348- | Orta | Marketplace UI/polish kalıntısı; tek commit veya stash adayı. |
| `lib/features/messages/screens/*` ve `widgets/*` | A | Mesaj ekranları ve starter sheet farkları, 127+/66- | Orta | Messaging UI kalıntısı; repository değişikliklerinden ayrı review. |
| `lib/features/messaging/screens/chat_screen.dart` | A | Chat screen küçük fark, 2+/1- | Orta | Messaging UI setine ekle. |
| `lib/features/notifications/screens/*` ve `widgets/*` | A | Notification UI farkları, 8+/12- | Düşük-Orta | Notification UI commit adayı. |
| `lib/features/onboarding/screens/*` | A | Onboarding/splash UI farkları, 18+/27- | Orta | Boot/entry deneyimi etkilenebilir; ayrı review. |
| `lib/features/profile/screens/*` ve `widgets/*` | A | Profile/CV/edit/follow UI farkları, 172+/177- | Orta | Profile UI sprint kalıntısı; provider/repository değişikliklerinden ayrı tutulmalı. |
| `lib/features/settings/screens/*` ve `widgets/*` | A | Settings/about/tile UI farkları, 13+/28- | Düşük-Orta | Settings UI commit adayı. |
| `lib/features/social/comments/*`, `composer/*`, `feed/*`, `post/*`, `profile/*`, `stories/*` UI | A | Sosyal ekran/widget geniş UI farkları, 500+/616- | Orta | Social rebuild/polish kalıntısı; çok geniş, ayrı branch/commit gerekir. |
| `lib/features/social_groups/screens/*` ve `widgets/*` | A | Group ekran/widget farkları, 198+/218- | Orta | Social groups UI seti; provider/repository değişikliklerinden ayrı review. |
| `lib/features/worker/screens/*` | A | Worker/job seek ekran farkları, 187+/175- | Orta | Worker UI sprint kalıntısı; model/repo değişikliklerinden ayrı. |

## Kategori B — Format/Whitespace Only

Bu dosyalarda `git diff --ignore-all-space --quiet` temiz dönüyor. Gerçek içerik
farkı görünmüyor; güvenli restore adayıdırlar.

| Dosya | Kategori | Diff Özeti | Risk | Önerilen Aksiyon |
|---|---|---|---|---|
| `lib/features/auth/providers/can_write_check_provider.dart` | B | Whitespace-only, 5+/5- | Düşük | Onayla restore edilebilir. |
| `lib/features/bakery_panel/models/recipe_quantities.dart` | B | Whitespace-only, 7+/7- | Düşük | Onayla restore edilebilir. |
| `lib/features/dealers/models/dealer_balance_summary.dart` | B | Whitespace-only, 10+/10- | Düşük | Onayla restore edilebilir. |
| `lib/features/dealers/models/dealer_pulse_snapshot.dart` | B | Whitespace-only, 8+/8- | Düşük | Onayla restore edilebilir. |
| `lib/features/dealers/models/dealer_transaction.dart` | B | Whitespace-only, 4+/4- | Düşük | Onayla restore edilebilir. |
| `lib/features/feed/models/feed_insight.dart` | B | Whitespace-only, 2+/2- | Düşük | Onayla restore edilebilir. |
| `lib/features/messages/models/job_conversation.dart` | B | Whitespace-only, 7+/7- | Düşük | Onayla restore edilebilir. |
| `lib/features/messages/models/job_message.dart` | B | Whitespace-only, 4+/4- | Düşük | Onayla restore edilebilir. |
| `lib/features/profile/providers/public_profile_detail_provider.dart` | B | Whitespace-only, 12+/12- | Düşük | Onayla restore edilebilir. |
| `lib/features/profile/repositories/local_follow_repository.dart` | B | Whitespace-only, 1+/1- | Düşük | Onayla restore edilebilir. |
| `lib/features/social/models/social_profile.dart` | B | Whitespace-only, 2+/2- | Düşük | Onayla restore edilebilir. |
| `lib/features/social/repositories/local_social_comments_repository.dart` | B | Whitespace-only, 3+/3- | Düşük | Onayla restore edilebilir. |
| `lib/features/social_groups/models/group_category.dart` | B | Whitespace-only, 8+/8- | Düşük | Onayla restore edilebilir. |
| `lib/features/worker/models/worker_profile.dart` | B | Whitespace-only, 16+/16- | Düşük | Onayla restore edilebilir. |

## Kategori C — Riskli Ürün Davranışı Değişiklikleri

Bu dosyalar model, provider, repository, service, auth guard, config veya veri
hesaplama davranışına dokunuyor. Otomatik restore ya da tek toplu commit riskli.

| Dosya | Kategori | Diff Özeti | Risk | Önerilen Aksiyon |
|---|---|---|---|---|
| `lib/core/config/app_config.dart` | C | App config farkı, 8+/4- | Yüksek | Build/runtime config etkisi; önce diff review. |
| `lib/features/auth/models/auth_user.dart` | C | Auth model farkı, 1+/4- | Yüksek | Auth contract etkisi; ayrı auth commit gerekir. |
| `lib/features/auth/repositories/auth_repository.dart` | C | Auth repository farkı, 1+/4- | Yüksek | Giriş/session davranışı etkilenebilir; restore etme. |
| `lib/features/auth/services/auth_actions.dart` | C | Auth action flow farkı, 5+/9- | Yüksek | Account/session flow etkisi; testli ayrı commit. |
| `lib/features/auth/services/auth_required_guard.dart` | C | Guest/write guard farkı, 3+/6- | Yüksek | Guard davranışı P0 risk; tek başına review. |
| `lib/features/bakery_panel/models/*` | C | Daily summary/recipe metadata model farkları, 39+/49- | Yüksek | Veri contract etkisi; migration gerekmediği doğrulanmalı. |
| `lib/features/bakery_panel/providers/*` | C | Bakery provider farkları, 12+/11- | Yüksek | State davranışı etkisi; ayrı review. |
| `lib/features/bakery_panel/repositories/*` | C | Local/Supabase bakery/recipe repo farkları, 37+/32- | Yüksek | Persistence davranışı etkisi; otomatik restore yok. |
| `lib/features/bakery_panel/services/*` | C | Calculator/share/report service farkları, 26+/10- | Yüksek | Hesaplama/rapor davranışı etkisi; testli review. |
| `lib/features/dealers/models/dealer.dart` | C | Dealer model farkı, 4+/7- | Yüksek | Bayi data contract etkisi; P0 öncesi sahiplen. |
| `lib/features/dealers/providers/dealer_providers.dart` | C | Dealer provider geniş farkı, 125+/110- | Yüksek | Bayi state/hesaplama akışı etkisi; dokunma. |
| `lib/features/dealers/repositories/*` | C | Guarded/local/Supabase dealer repo farkları, 74+/65- | Yüksek | Veri yazma/okuma etkisi; ayrı dealer data sprinti gerekir. |
| `lib/features/dealers/services/*` | C | Balance/PDF/pulse/share service farkları, 78+/66- | Yüksek | Borç-alacak/rapor/paylaşım riski; otomatik restore yok. |
| `lib/features/dealers/widgets/dealer_pulse_card.dart` | C | Pulse card davranış/veri sunumu farkı, 7+/11- | Orta-Yüksek | Pulse service ile birlikte review. |
| `lib/features/feed/models/*` | C | Feed model/post type farkları, 15+/17- | Yüksek | Persisted social data contract riski. |
| `lib/features/feed/providers/*` | C | Feed provider farkları, 45+/48- | Yüksek | Feed state/query davranışı etkisi. |
| `lib/features/feed/repositories/*` | C | Guarded/local/Supabase feed repo farkları, 98+/91- | Yüksek | Social write/read behavior; ayrı commit gerekir. |
| `lib/features/jobs/models/providers/repositories/*` | C | Job offer model/provider/repo farkları, 13+/13- | Yüksek | Job ilan data flow etkisi. |
| `lib/features/marketplace/models/providers/repositories/*` | C | Marketplace filters/listing/provider/repo farkları, 81+/98- | Yüksek | Market ilan persistence/query etkisi. |
| `lib/features/messages/models/providers/repositories/*` | C | Job messaging model/provider/repo farkları, 30+/28- | Yüksek | Mesaj persistence etkisi; ayrı review. |
| `lib/features/messaging/models/providers/repositories/*` | C | Generic messaging model/provider/repo farkları, 118+/107- | Yüksek | Chat davranışı ve veri contract riski. |
| `lib/features/notifications/models/providers/*` | C | Notification model/provider farkları, 14+/11- | Orta-Yüksek | Notification state etkisi. |
| `lib/features/profile/models/providers/repositories/services/*` | C | Profile/follow provider/repo/avatar service farkları, 60+/75- | Yüksek | Profile/follow/auth-adjacent data risk. |
| `lib/features/social/models/providers/repositories/*` | C | Social comment/provider/repo/story repo farkları, 110+/128- | Yüksek | Social data model/query/write riski. |
| `lib/features/social_groups/models/providers/repositories/*` | C | Group model/provider/repo farkları, 101+/105- | Yüksek | Group membership/write behavior riski. |
| `lib/features/worker/models/providers/repositories/*` | C | Worker/job seek model/provider/repo farkları, 43+/37- | Yüksek | Worker/job seek data contract riski. |
| `lib/main.dart` | C | App entrypoint farkı, 4+/8- | Yüksek | Boot/config davranışı etkisi; ayrı review. |

## Kategori D — Test/Dokümantasyon

Test ve smoke dosyaları davranışı doğrudan değiştirmez, ancak mevcut dirty setin
hangi sprintlerden geldiğine dair kuvvetli işaret taşır. Bunlar kod değişiklikleri
ile eşleştirilmeden restore edilmemeli.

| Dosya | Kategori | Diff Özeti | Risk | Önerilen Aksiyon |
|---|---|---|---|---|
| `.maestro/app_smoke.yaml` | D | Maestro smoke flow farkı, 7+/9- | Orta | Patrol/Maestro sprint kalıntısı; ilgili UI değişiklikleriyle eşleştir. |
| `test/app_typography_test.dart` | D | Typography contract test farkı, 5+/5- | Orta | Theme değişiklikleriyle birlikte review. |
| `test/create_profile_hydrate_submit_guard_test.dart` | D | Profile hydrate/guard test farkı, 90+/43- | Orta | Profile/auth değişiklikleriyle eşleştir. |
| `test/dealer_form_save_error_test.dart` | D | Dealer form error test geniş farkı, 124+/138- | Orta | Dealer form/repo değişiklikleriyle eşleştir. |
| `test/dealer_job_seek_write_error_test.dart` | D | Dealer/job seek guard test farkı, 53+/62- | Orta | Guard/job seek değişiklikleriyle eşleştir. |
| `test/market_v1_controlled_data_test.dart` | D | Market data test küçük fark, 4+/1- | Düşük-Orta | Marketplace data changes ile review. |
| `test/market_v1_ui_test.dart` | D | Market UI test küçük fark, 4+/1- | Düşük-Orta | Marketplace UI setine bağla. |
| `test/post_type_accent_test.dart` | D | Post type accent test farkı, 17+/16- | Orta | Social/post type değişiklikleriyle review. |
| `test/premium_card_tier_test.dart` | D | Premium card test farkı, 59+/52- | Orta | Premium UI/theme setine bağla. |
| `test/recipe_save_error_test.dart` | D | Recipe save error test farkı, 62+/68- | Orta | Recipe repo/service değişiklikleriyle review. |
| `test/social_core_stories_test.dart` | D | Social stories test küçük fark, 1+/1- | Düşük-Orta | Story repo/UI değişiklikleriyle eşleştir. |
| `test/social_donor_module_test.dart` | D | Social donor module test geniş farkı, 72+/124- | Orta | Social rebuild setine bağla. |
| `test/social_p0_delete_and_navigation_test.dart` | D | Social delete/navigation test farkı, 42+/105- | Orta | Social navigation/delete değişiklikleriyle review. |
| `test/tag_chip_test.dart` | D | Tag chip test farkı, 20+/24- | Orta | Shared chip/widget değişiklikleriyle eşleştir. |

## Kategori E — Asset/Untracked

| Dosya | Kategori | Diff Özeti | Risk | Önerilen Aksiyon |
|---|---|---|---|---|
| `assets/ChatGPT Image 24 May 2026 22_00_17.png` | E | Untracked binary/image asset | Orta | Kaynak ve kullanım yeri bulunmadan commit etme; kullanılmıyorsa silme onayı iste. |

## Önerilen Temizlik Planı

1. `Kategori B` dosyalarını ayrı onayla restore et. Bunlar gerçek içerik farkı
   taşımıyor.
2. `Kategori C` için otomatik işlem yapma. Her alt domain için diff review yap:
   auth, dealer, bakery, marketplace, social, messaging, profile, worker.
3. `Kategori A` UI/polish dosyalarını tema/premium, marketplace UI, social UI,
   dealer UI gibi domain commitlerine ayır.
4. `Kategori D` test dosyalarını ilgili kod domainleriyle eşleştir; tek başına
   test commit’i yapma.
5. `Kategori E` asset için kullanım araması yap; referans yoksa silme için onay
   iste, referans varsa asset sprintine taşı.

## Güvenli Restore Adayları

Yalnız aşağıdaki 14 whitespace-only dosya güvenli restore adayıdır:

* `lib/features/auth/providers/can_write_check_provider.dart`
* `lib/features/bakery_panel/models/recipe_quantities.dart`
* `lib/features/dealers/models/dealer_balance_summary.dart`
* `lib/features/dealers/models/dealer_pulse_snapshot.dart`
* `lib/features/dealers/models/dealer_transaction.dart`
* `lib/features/feed/models/feed_insight.dart`
* `lib/features/messages/models/job_conversation.dart`
* `lib/features/messages/models/job_message.dart`
* `lib/features/profile/providers/public_profile_detail_provider.dart`
* `lib/features/profile/repositories/local_follow_repository.dart`
* `lib/features/social/models/social_profile.dart`
* `lib/features/social/repositories/local_social_comments_repository.dart`
* `lib/features/social_groups/models/group_category.dart`
* `lib/features/worker/models/worker_profile.dart`

## Ayrı Commit Adayları

* `theme/premium-ui`: `lib/app/theme/*`, `lib/core/widgets/premium/*`,
  `test/app_typography_test.dart`, `test/premium_card_tier_test.dart`
* `dealer-domain`: `lib/features/dealers/**`, dealer tests
* `auth-profile-guard`: auth service/guard/repository, profile provider/repo,
  related guard tests
* `marketplace-domain`: marketplace models/providers/repositories/screens/widgets
  and market tests
* `social-domain`: social, social_groups, feed, stories and related tests
* `messaging-domain`: messages/messaging models/providers/repositories/screens
* `bakery-panel-domain`: bakery panel models/providers/repositories/services/screens
  and recipe tests
* `worker-jobs-domain`: jobs/worker models/providers/repositories/screens

## Dokunulmaması Gerekenler

* Repository/provider/model/service dosyaları domain sahibi olmadan restore
  edilmemeli.
* Dealer balance, dealer pulse, report builder, recipe calculator ve auth guard
  dosyaları P0 davranış riski taşıdığı için toplu cleanup içinde silinmemeli.
* Untracked asset kullanım kaynağı belirlenmeden commit edilmemeli veya silinmemeli.
* Test dosyaları ilgili kod değişikliğiyle eşleşmeden tek başına normalize
  edilmemeli.
