# FırınNet — Job Messaging Reality Report (V1)

**Tarih:** 2026-05-16
**Proje:** FırınNet · Supabase ref `sjeqwiqgwzagengdukye`
**Hedef:** İş İlanları üzerinden gerçek başvuru ve 1-1 mesajlaşma. "Başvur" snackbar yok; ilan sahibi ↔ başvuran kullanıcı arasında gerçek backend'li sohbet.

---

## TL;DR

- ✅ **İş Arıyorum** (`job_seek_posts`) mesajlaşması gerçek: ticari/toptancı kullanıcı iş arayanla `job_conversations` üzerinden sohbet başlatabilir.
- ✅ **Usta/İşçi Arıyorum** (`job_offer_posts`) başvuru mesajlaşması gerçek: bireysel kullanıcı ilana mesajla başvurur, conversation + ilk mesaj atomik atılır.
- ✅ **Live smoke 28 / 28 PASS** — A (commercial), B (individual), C (unauthorized) ile cross-user deny + dedup + closed-convo write deny dahil.
- ✅ **Snackbar fallback kaldırıldı**: `JobOpportunityCard.onApply` parent'tan verilmezse CTA hiç render edilmez (no-op yok).
- ✅ Panel "Mesajlar" kartı artık `route = /messages` (eskiden `comingSoon: true`).
- ✅ Guest yazma korumalı: `GuardedJobMessagingRepository` write metotlarında `GuestActionRequiredException` → UI `AuthRequiredSheet`.
- ✅ `flutter analyze --no-pub` clean · `flutter test --no-pub` **254 / 254** passed.

---

## Before / After

| Konu | Before | After |
|---|---|---|
| JobOpportunityCard CTA | onApply null → snackbar `jobsApplyComingSoon` | onApply null → CTA hiç render edilmez |
| job_offer kartı tıklama | snackbar (sahte) | Auth check → StartJobConversationSheet → conversation + ilk mesaj |
| job_seek kartı tıklama | snackbar (sahte) | role-aware (Ticari/Toptancı) "İletişime geç" → sheet |
| Mesajlar sayfası | yok | `/messages` ConsumerWidget — gerçek conversation listesi |
| Conversation ekranı | yok | `/messages/:id` — gerçek mesaj listesi, composer, close, soft-delete |
| Panel Mesajlar kartı | `comingSoon: true` | `route: /messages` (Commercial + Individual + Wholesaler) |
| Backend tablolar | sadece job_offer_posts + job_seek_posts | + `job_conversations`, `job_messages`, trigger, RLS, partial unique idx |

---

## 1. DB schema (migration `20260516200000_job_messaging_v1`)

### `public.job_conversations`
| Alan | Tip | Not |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `related_type` | text NOT NULL | check `in ('job_offer','job_seek')` |
| `job_offer_id` | uuid FK | → `job_offer_posts(id) on delete cascade` |
| `job_seek_post_id` | uuid FK | → `job_seek_posts(id) on delete cascade` |
| `initiator_id` | uuid NOT NULL FK | → `profiles(id) on delete cascade` |
| `recipient_id` | uuid NOT NULL FK | → `profiles(id) on delete cascade` |
| `status` | text NOT NULL default `'open'` | check `in ('open','closed')` |
| `last_message_at` | timestamptz NULL | trigger updated |
| `created_at`, `updated_at` | timestamptz | trigger `set_updated_at()` |

Constraint'ler:
- `job_conversations_distinct_parties` — `initiator_id <> recipient_id`
- `job_conversations_target_consistency` — `related_type='job_offer'` ise sadece `job_offer_id`, `related_type='job_seek'` ise sadece `job_seek_post_id` set olmalı.

Partial unique indexler:
- `uq_job_conversations_offer_initiator` — `(job_offer_id, initiator_id)` where `job_offer_id is not null`
- `uq_job_conversations_seek_initiator` — `(job_seek_post_id, initiator_id)` where `job_seek_post_id is not null`

Browse indexler: `(recipient_id, last_message_at desc)`, `(initiator_id, last_message_at desc)`.

### `public.job_messages`
| Alan | Tip | Not |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `conversation_id` | uuid NOT NULL FK | → `job_conversations(id) on delete cascade` |
| `sender_id` | uuid NOT NULL FK | → `profiles(id) on delete cascade` |
| `body` | text NOT NULL | check `length(btrim(body)) between 1 and 1000` |
| `is_deleted` | boolean NOT NULL default false | soft delete |
| `created_at` | timestamptz | default now() |

Trigger: `trg_job_messages_bump_conversation` — `after insert` → `bump_job_conversation_last_message` SECURITY DEFINER fn `last_message_at` ve `updated_at` günceller.

---

## 2. RLS security

### `job_conversations`
| Policy | Etki |
|---|---|
| `job_conversations_select_participant` | sadece `initiator_id = auth.uid() OR recipient_id = auth.uid()` |
| `job_conversations_insert_initiator` | `initiator_id = auth.uid()` AND `recipient_id <> auth.uid()` AND **post sahibi cinsten doğrulanmış**: `job_offer` ise `p.owner_id = recipient_id` ve `p.is_active = true`; `job_seek` ise aynı |
| `job_conversations_update_participant` | participant `status` değiştirebilir; USING + WITH CHECK aynı participant şartı |
| DELETE | **policy yok** → hard delete client'tan kapalı; sadece CASCADE |

### `job_messages`
| Policy | Etki |
|---|---|
| `job_messages_select_participant` | conversation participantı ise görür |
| `job_messages_insert_sender` | `sender_id = auth.uid()` AND participant AND **conversation.status = 'open'** |
| `job_messages_update_owner_softdelete` | `sender_id = auth.uid()` — soft delete'e izin |
| DELETE | **policy yok** → hard delete kapalı |

### Disiplin
- ❌ `with check (true)` yok
- ❌ `using (true)` yok
- ❌ anon DML grant yok
- ✅ Bump fn SECURITY DEFINER + `search_path=public` + `revoke execute from public/anon/authenticated`
- ✅ `grant select, insert, update on public.{job_conversations,job_messages} to authenticated` (DELETE grant YOK)

---

## 3. Flutter wiring

### Yeni klasör: `lib/features/messages/`
| Dosya | Rol |
|---|---|
| `models/job_conversation.dart` | id, relatedType, fk'lar, status, lastMessageAt, fromRow/toInsertRow |
| `models/job_message.dart` | id, conversationId, senderId, body, isDeleted, displayBody placeholder |
| `repositories/job_messaging_repository.dart` | abstract API: listMyConversations, listMessages, startForJobOffer/Seek, sendMessage, softDeleteMessage, closeConversation, watch |
| `repositories/local_job_messaging_repository.dart` | in-memory; dedup, kendi ilanına başvuru reddi, closed convo write reddi |
| `repositories/supabase_job_messaging_repository.dart` | Supabase impl; conversation lookup → insert dedup; ilan başlığını ayrı sorguyla doldurur |
| `repositories/guarded_job_messaging_repository.dart` | guest write reddi (`GuestActionRequiredException`); read pass-through |
| `providers/job_messaging_providers.dart` | `jobMessagingRepositoryProvider`, `jobMessagingChangesProvider`, `myJobConversationsProvider`, `jobMessagesProvider(family)` |
| `screens/messages_list_screen.dart` | `/messages` — premium scaffold, kart liste, kapalı badge, empty state (guest/auth) |
| `screens/job_conversation_screen.dart` | `/messages/:id` — mesaj kabarcıkları, composer, close eylemi, soft-delete sender-only |
| `widgets/start_job_conversation_sheet.dart` | bottom sheet; ilk mesaj 1..1000; auth/guest/own-post hatalarını ayrı snackbar'larla işler |

### Mevcut dosya düzenlemeleri
- `lib/core/widgets/premium/job_opportunity_card.dart`: `onApply` null ise CTA **render edilmez** (eski snackbar fallback silindi). `applyLabel`/`applyIcon`/`applyEnabled` opsiyonel paramlar.
- `lib/features/jobs/screens/jobs_screen.dart`: `_JobOfferCard` ve `_JobSeekCard` `ConsumerWidget`'a dönüştü; role-aware CTA (commercial/wholesaler için seek "İletişime geç", individual için offer "Başvur"); kendi ilanına CTA gizlenir.
- `lib/features/dashboard/services/role_panel_cards.dart`: Commercial + Individual `cardMessages` ve Wholesaler `cardIncomingMessages` artık `route: AppRoutes.messages` (eskiden `comingSoon: true`).
- `lib/app/router/app_router.dart`: yeni `/messages` + `/messages/:id` routes; `MessagesListScreen` + `JobConversationScreen` builder'ları.
- `lib/core/constants/app_strings.dart`: messaging copy (sheet title/subtitle, composer hint, closed banner, vs.).

---

## 4. Role-aware UI davranışı

| Rol | job_offer (`Usta Arıyor`) | job_seek (`İş Arıyor`) | Kendi ilanı |
|---|---|---|---|
| Bireysel | "Başvur" → sheet (offer) | CTA gizli | CTA gizli |
| Ticari | CTA gizli (zaten kendi/benzer ilan veriyor) | "İletişime geç" → sheet (seek) | CTA gizli |
| Toptancı | aynı (Ticari) | "İletişime geç" → sheet (seek) | CTA gizli |
| Guest | "Başvur" → AuthRequiredSheet | "İletişime geç" → AuthRequiredSheet | — |

Not: Guest için CTA görünür ama tıklandığında auth gate açar; bu sayede CTA'nın varlığı keşfedilebilir kalır.

---

## 5. Guest / auth davranışı

- **Pre-check (UI)**: `AuthRequiredGuard.canWriteWithRef(ref)` `false` → `showAuthRequiredSheet(...)`.
- **Defense-in-depth (repo)**: `GuardedJobMessagingRepository.startFor*/sendMessage/softDeleteMessage/closeConversation` write yetkisi yoksa `GuestActionRequiredException` atar; UI `runGuardedMutation` veya sheet bunu yakalar.
- **Liste/okuma** guest için pass-through, ama Supabase auth yoksa `Local` impl gelir — guest mode'da boş liste döner.
- **AccountDelete + signOut sonrası** mevcut RLS auth.uid()'i null görür; tüm conversation/message kalemleri görünmez (`SELECT participant policy` deny).

---

## 6. Tests (Dart)

`test/job_messaging_v1_test.dart` — **26 / 26 PASS**. Test gruplari:

| Grup | Test sayısı | Kapsam |
|---|---|---|
| `JobConversation model` | 2 | fromRow + toInsertRow + `otherPartyId` |
| `JobMessage model` | 2 | fromRow + soft delete placeholder |
| `LocalJobMessagingRepository` | 7 | start (offer + seek), dedup reuse, own-post reject, sendMessage, soft delete sender-only, close → send throws |
| `GuardedJobMessagingRepository` | 3 | guest write throws, read pass-through, auth user pass-through |
| `UI source smoke` | 4 | StartJobConversationSheet import + kullanım, snackbar fallback yok, role_panel route, router /messages |
| `Migration SQL smoke` | 8 | RLS enabled, participant select, cross-owner insert, status=open msg insert, sender-only update, no `with check (true)`, partial unique idx, distinct/target constraints |

Tam suite: `flutter test --no-pub` → **254 / 254 passed**.

`flutter analyze --no-pub` → No issues.

---

## 7. Live smoke (3-user, gerçek JWT)

`scripts/admin/job_messaging_live_smoke.ps1` — **28 / 28 PASS**. Setup:
- A = commercial-style poster, B = individual-style applicant, C = unauthorized 3rd party.

| # | Test | Sonuç |
|---|---|---|
| 1–6 | Auth: create + sign-in A/B/C | ✅ 200 |
| 7 | A inserts `job_offer_posts` | ✅ 201 |
| 8 | B initiates `job_conversations` (offer + A=recipient) | ✅ 201 |
| 9 | B inserts first `job_messages` | ✅ 201 |
| 10 | A lists conversations → sees B's convo | ✅ 200 |
| 11 | A reads B's message | ✅ 200 |
| 12 | A replies (sender=A, body) | ✅ 201 |
| 13 | B reads → 2 messages | ✅ 200 |
| **14** | **C lists conversations → does NOT see A/B convo** | ✅ 200 (RLS empty) |
| **15** | **C reads A/B messages → empty** | ✅ 200 (RLS empty) |
| **16** | **C cannot insert message in A/B convo** | ✅ **403** |
| **17** | **B cannot forge convo with C as recipient (C not post owner)** | ✅ **403** |
| **18** | **B cannot self-target convo (initiator=recipient)** | ✅ **403** |
| 19 | B inserts `job_seek_posts` | ✅ 201 |
| 20 | A initiates job_seek convo | ✅ 201 |
| 21 | A inserts first message | ✅ 201 |
| 22 | B sees A's job_seek convo | ✅ 200 |
| 23 | A closes offer convo | ✅ patch 204, status=closed |
| **24** | **B cannot write to closed convo** | ✅ **403** |
| **25** | **B cannot create 2nd convo for same offer (dedup)** | ✅ **409** (partial unique idx) |
| 26–28 | Cleanup user A/B/C CASCADE | ✅ 200 / 204 |

### MCP residue check (post-cleanup)

```
auth_users_total           : 1   ← Fatih korunmuş
auth_users_smoke_residue   : 0
profiles_total             : 1
profiles_smoke_residue     : 0
job_conversations_total    : 0
job_messages_total         : 0
job_offer_posts_total      : 0
job_seek_posts_total       : 0
fatih_bakeries             : 1
```

CASCADE zinciri (`auth.users → profiles → job_offer_posts/job_seek_posts → job_conversations → job_messages`) kusursuz çalıştı.

---

## 8. Secret hijyeni

- `service_role`/`SUPABASE_SERVICE_ROLE` referansları sadece:
  - `supabase/functions/delete-account/index.ts` → `Deno.env.get`
  - `scripts/admin/*.ps1` → `.env.admin.local`'dan okuma
  - Belgelendirme yorumları
- `eyJ[A-Za-z0-9_-]{20,}` JWT pattern `lib/` + `test/` + `scripts/` + `supabase/` taramasında **No matches**.
- Test user UUID/şifre konsola yazılmadı; smoke script "present: yes" masking ile.
- Test user'lar (`firinnet_smoke_jm_*@example.com`) CASCADE ile silindi; residue 0.

---

## 9. Kalan sınırlar / known gaps

- **Realtime push yok**: yeni mesaj geldiğinde otomatik canlanma yok; ekran açıldıkça `FutureProvider.invalidate` ile yenilenir. V1.1'de `supabase_flutter` realtime channel eklenebilir.
- **Bildirim altyapısı yok**: FCM/email notification entegrasyonu V2.
- **İlan/karşı taraf bilgisi `relatedTitle`/`otherPartyName`** Supabase impl'inde liste ekranı için ayrı sorgularla doldurulur (join API yerine basit IN-filter). Performans şu an için yeterli; V1.1'de view/relation tek query'ye indirilebilir.
- **Profile sayfasında ayrı "Mesajlarım" tile yok**: Panel role kartları yeterli gözüktü; gerekirse `_AccountList` benzeri bir bölüm eklenir.
- **Manuel UI smoke yapılmadı** (P0-A hala kullanıcı tarafı).

---

## 10. Manuel UI smoke notu

Önerilen akış (3 cihaz veya 3 hesap, 1 cihaz):
1. **A (Ticari)** sign-up + `Usta Arıyor İlanı Ver` → ilan yayında.
2. **B (Bireysel)** sign-up → İlanlar tab → A'nın offerına "Başvur" → sheet → mesaj gönder.
3. **B**: Panel → Mesajlar kartı → conversation listesinde A ile sohbet → mesaj geçmişi.
4. **A**: Panel → Mesajlar kartı → B ile sohbet → cevap yaz.
5. **B (Bireysel)** ayrı: `İş Arıyorum İlanı Ver` → ilan yayında.
6. **A**: İlanlar → İş Arıyor segmenti → B'nin kartında "İletişime geç" → sheet → mesaj.
7. **Guest**: oturum kapat → İlanlar → "Başvur" tıkla → AuthRequiredSheet.
8. **A**: conversation ekranı → sağ üst kilit ikonu → "Sohbeti kapat" → B'nin composer disabled olduğunu gör.
9. **B (kapalı convo)**: composer disabled, "Bu sohbet kapatıldı" banner görünür.

---

## 11. Pre-commit son durumu

```
flutter analyze --no-pub  → No issues found! (0.7s)
flutter test --no-pub     → 254 / 254 passed
Live smoke (3-user)       → 28 / 28 PASS
MCP residue check          → 0 (Fatih korunmuş)
Secret literal             → No matches
```

**Commit/push yapılmadı** (kullanıcı talimatı). Bu rapor + yeni dosyalar untracked. Phase 8 commit önerisi için kullanıcı onayı bekleniyor.
