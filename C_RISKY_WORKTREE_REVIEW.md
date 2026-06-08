# C Risky Worktree Review

## Genel Verdict

Kalan 77 dosya, önceki fazlardan kalan ama artık güvenli UI polish sınırının dışında kalan riskli ürün davranışı yüzeyi.
Bu set içinde restore veya toplu stage için yeterince güvenli bir alt küme görmedim.
Bir sonraki adım tek tek domain review ve küçük, izlenebilir commitler olmalı.

## Dosya Sayısı Özeti

* Tracked dirty: 77
* Added: 0
* Deleted: 0
* Untracked: 0

## Domain Dağılımı

* App bootstrap / config: 1
* Auth / profile / guest guard: 13
* Feed / social repository / provider: 16
* Dealer / bakery / finance logic: 19
* Marketplace / jobs repository / provider: 12
* Messaging / notification / settings service: 12
* Riskli davranışla bağlantılı tests: 0
* Worker: 4

## Risk Dağılımı

* HIGH: 57
* MEDIUM: 20
* LOW: 0

## En Riskli 10 Dosya

1. `lib/features/dealers/providers/dealer_providers.dart`
2. `lib/features/social/providers/social_providers.dart`
3. `lib/features/messaging/repositories/local_messaging_repository.dart`
4. `lib/features/dealers/repositories/supabase_dealer_repository.dart`
5. `lib/features/feed/repositories/supabase_feed_repository.dart`
6. `lib/features/feed/providers/feed_providers.dart`
7. `lib/features/social_groups/providers/social_group_providers.dart`
8. `lib/features/dealers/services/dealer_pdf_builder.dart`
9. `lib/features/social_groups/repositories/supabase_social_group_repository.dart`
10. `lib/features/marketplace/repositories/supabase_market_listing_repository.dart`

## Restore / Commit Durumu

* Restore adayı: yok
* Ayrı commit adayı: var, ama yalnız domain sahibi review sonrası
* Dokunulmaması gerekenler: repository/provider/model/service/main.dart ağırlıklı riskli set

## Phase 4B Sırası

1. Auth/profile
2. Dealer/bakery
3. Feed/social
4. Marketplace/jobs
5. Messaging/notification
6. Worker
7. App bootstrap en son

## Detaylı Tablo

### App Bootstrap / Config

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/main.dart` | App bootstrap / config | Bootstrap init + system UI color wiring | MEDIUM | Evet | Kısmi | Daha fazla manual review |

### Auth / Profile / Guest Guard

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/features/auth/models/auth_user.dart` | Auth / profile / guest guard | Auth model contract / serialization dokunuşu | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/auth/repositories/auth_repository.dart` | Auth / profile / guest guard | Auth repository write/read akışı | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/auth/services/auth_actions.dart` | Auth / profile / guest guard | Delete/signout action akışı + dialog UI wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/auth/services/auth_required_guard.dart` | Auth / profile / guest guard | Guest guard UI/flow ve CTA wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/auth/utils/auth_error_translator.dart` | Auth / profile / guest guard | Error translation/copy mapping | MEDIUM | Kısmi | Kısmi | Domain sprintine bırak |
| `lib/features/profile/models/public_profile_detail.dart` | Auth / profile / guest guard | Public profile model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/profile/providers/follow_providers.dart` | Auth / profile / guest guard | Follow state invalidation / provider wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/profile/providers/profile_provider.dart` | Auth / profile / guest guard | Profile snapshot + provider wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/profile/repositories/guarded_follow_repository.dart` | Auth / profile / guest guard | Follow write-guard repository wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/profile/repositories/guarded_profile_repository.dart` | Auth / profile / guest guard | Profile write-guard repository wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/profile/repositories/supabase_follow_repository.dart` | Auth / profile / guest guard | Supabase follow persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/profile/repositories/supabase_profile_repository.dart` | Auth / profile / guest guard | Supabase profile persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/profile/services/avatar_upload_service.dart` | Auth / profile / guest guard | Avatar upload flow helper | HIGH | Evet | Kısmi | Daha fazla manual review |

### Feed / Social

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/features/feed/models/feed_post.dart` | Feed / social repository / provider | Feed model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/feed/models/post_type.dart` | Feed / social repository / provider | Post type enum / mapping | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/feed/providers/feed_providers.dart` | Feed / social repository / provider | Feed state invalidation + paging/provider wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/feed/repositories/guarded_feed_repository.dart` | Feed / social repository / provider | Feed write guard wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/feed/repositories/local_feed_repository.dart` | Feed / social repository / provider | Local feed persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/feed/repositories/supabase_feed_repository.dart` | Feed / social repository / provider | Supabase feed persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social/models/social_comment.dart` | Feed / social repository / provider | Social comment model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/social/providers/social_providers.dart` | Feed / social repository / provider | Social provider graph / invalidation | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social/repositories/supabase_social_comments_repository.dart` | Feed / social repository / provider | Supabase comment persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social/stories/repositories/local_social_stories_repository.dart` | Feed / social repository / provider | Local stories persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social/stories/repositories/supabase_social_stories_repository.dart` | Feed / social repository / provider | Supabase stories persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social_groups/models/social_group.dart` | Feed / social repository / provider | Social group model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/social_groups/providers/social_group_providers.dart` | Feed / social repository / provider | Group provider state / invalidation | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social_groups/repositories/guarded_social_group_repository.dart` | Feed / social repository / provider | Social group write guard wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social_groups/repositories/local_social_group_repository.dart` | Feed / social repository / provider | Local group persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/social_groups/repositories/supabase_social_group_repository.dart` | Feed / social repository / provider | Supabase group persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |

### Dealer / Bakery / Finance

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/features/bakery_panel/models/daily_summary.dart` | Dealer / bakery / finance logic | Daily summary model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/bakery_panel/models/recipe_metadata.dart` | Dealer / bakery / finance logic | Recipe metadata model / parsing | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/bakery_panel/providers/bakery_providers.dart` | Dealer / bakery / finance logic | Bakery provider state / invalidation | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/bakery_panel/repositories/local_bakery_repository.dart` | Dealer / bakery / finance logic | Local bakery persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/bakery_panel/repositories/local_recipe_repository.dart` | Dealer / bakery / finance logic | Local recipe persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/bakery_panel/repositories/supabase_bakery_repository.dart` | Dealer / bakery / finance logic | Supabase bakery persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/bakery_panel/repositories/supabase_recipe_repository.dart` | Dealer / bakery / finance logic | Supabase recipe persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/bakery_panel/services/recipe_calculator.dart` | Dealer / bakery / finance logic | Recipe calculation helper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/bakery_panel/services/recipe_share_text_builder.dart` | Dealer / bakery / finance logic | Share text builder / copy helper | MEDIUM | Kısmi | Kısmi | Domain sprintine bırak |
| `lib/features/bakery_panel/services/report_builder.dart` | Dealer / bakery / finance logic | Report generation helper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/models/dealer.dart` | Dealer / bakery / finance logic | Dealer model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/dealers/providers/dealer_providers.dart` | Dealer / bakery / finance logic | Dealer state / invalidation / metrics wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/repositories/guarded_dealer_repository.dart` | Dealer / bakery / finance logic | Dealer write guard wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/repositories/local_dealer_repository.dart` | Dealer / bakery / finance logic | Local dealer persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/repositories/supabase_dealer_repository.dart` | Dealer / bakery / finance logic | Supabase dealer persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/services/dealer_balance_service.dart` | Dealer / bakery / finance logic | Balance/debt-credit calculation helper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/services/dealer_pdf_builder.dart` | Dealer / bakery / finance logic | PDF/report export builder | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/services/dealer_pulse_service.dart` | Dealer / bakery / finance logic | Dealer pulse/metrics helper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/dealers/services/dealer_share_builder.dart` | Dealer / bakery / finance logic | Dealer share text builder | HIGH | Evet | Kısmi | Daha fazla manual review |

### Marketplace / Jobs

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/features/marketplace/data/marketplace_taxonomy.dart` | Marketplace / jobs repository / provider | Taxonomy / category constants | MEDIUM | Kısmi | Kısmi | Domain sprintine bırak |
| `lib/features/marketplace/models/market_filters.dart` | Marketplace / jobs repository / provider | Filter model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/marketplace/models/market_listing.dart` | Marketplace / jobs repository / provider | Listing model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/marketplace/providers/market_listing_providers.dart` | Marketplace / jobs repository / provider | Listing provider state / invalidation | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/marketplace/repositories/guarded_market_listing_repository.dart` | Marketplace / jobs repository / provider | Marketplace write guard wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/marketplace/repositories/local_market_listing_repository.dart` | Marketplace / jobs repository / provider | Local listing persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/marketplace/repositories/supabase_market_listing_repository.dart` | Marketplace / jobs repository / provider | Supabase listing persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/jobs/models/job_offer_post.dart` | Marketplace / jobs repository / provider | Job offer model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/jobs/providers/job_offer_providers.dart` | Marketplace / jobs repository / provider | Job offer provider state / invalidation | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/jobs/repositories/guarded_job_offer_repository.dart` | Marketplace / jobs repository / provider | Job offer write guard wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/jobs/repositories/local_job_offer_repository.dart` | Marketplace / jobs repository / provider | Local job offer persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/jobs/repositories/supabase_job_offer_repository.dart` | Marketplace / jobs repository / provider | Supabase job offer persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |

### Messaging / Notification

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/features/messages/providers/job_messaging_providers.dart` | Messaging / notification / settings service | Job messaging provider wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messages/repositories/local_job_messaging_repository.dart` | Messaging / notification / settings service | Local job messaging persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messages/repositories/supabase_job_messaging_repository.dart` | Messaging / notification / settings service | Supabase job messaging persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messaging/models/conversation.dart` | Messaging / notification / settings service | Conversation model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/messaging/models/message.dart` | Messaging / notification / settings service | Message model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/messaging/providers/messaging_providers.dart` | Messaging / notification / settings service | Messaging provider graph / invalidation | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messaging/repositories/guarded_messaging_repository.dart` | Messaging / notification / settings service | Messaging write guard wrapper | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messaging/repositories/local_messaging_repository.dart` | Messaging / notification / settings service | Local messaging persistence + unread logic | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messaging/repositories/messaging_repository.dart` | Messaging / notification / settings service | Messaging repository contract | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/messaging/repositories/supabase_messaging_repository.dart` | Messaging / notification / settings service | Supabase messaging persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/notifications/models/app_notification.dart` | Messaging / notification / settings service | Notification model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/notifications/providers/notification_providers.dart` | Messaging / notification / settings service | Notification provider wiring | HIGH | Evet | Kısmi | Daha fazla manual review |

### Worker

| Dosya | Domain | Diff Özeti | Risk Seviyesi | Davranış Değiştiriyor mu? | Test Kapsamı Var mı? | Önerilen Aksiyon |
|---|---|---|---|---|---|---|
| `lib/features/worker/models/job_seek_post.dart` | Worker | Job seek model contract | MEDIUM | Evet | Kısmi | Domain sprintine bırak |
| `lib/features/worker/providers/worker_providers.dart` | Worker | Worker provider wiring | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/worker/repositories/local_worker_repository.dart` | Worker | Local worker persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |
| `lib/features/worker/repositories/supabase_worker_repository.dart` | Worker | Supabase worker persistence behavior | HIGH | Evet | Kısmi | Daha fazla manual review |

