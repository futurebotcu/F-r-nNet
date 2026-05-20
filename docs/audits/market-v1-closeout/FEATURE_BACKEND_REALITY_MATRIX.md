# FırınNet — Feature × Backend Reality Matrix (Round 3)

**Tarih:** 2026-05-16
**Branch:** `main` @ `970de7f`

Her feature için: kod beklediği obje + canlı varlık + RLS + repository + smoke kanıtı + verdict.

---

| Feature | Expected Supabase object | Exists live | RLS | Repository | Smoke evidence | Verdict |
|---|---|---|---|---|---|---|
| **Auth (sign-in/up/forgot/email sync)** | `auth.users` + `handle_new_user` trigger + `auth_email_sync` trigger | ✅ | n/a (auth) | `SupabaseAuthRepository` (Local fallback yok → null) | full_app_backend_smoke A1+A2; cross_user_rls auth | ✅ Gerçek |
| **Profile (display_name/account_type/email)** | `profiles` (id = auth.users.id on delete cascade) | ✅ | owner-only | `Local + Supabase + Guarded` | trigger auto-create smoke PASS | ✅ Gerçek |
| **Feed post** | `feed_posts` + snapshot trigger + counter | ✅ | authenticated select + owner CRUD | `Local + Supabase + Guarded` | smoke insert + author_name snapshot doğru | ✅ Gerçek |
| **Feed like / save** | `feed_likes` / `feed_saves` (composite PK) + counter trigger | ✅ | feed_likes select_auth(true), feed_saves select_self; insert/delete owner | aynı repo | smoke insert + counter=1 + delete | ✅ Gerçek |
| **Feed comment** | `feed_comments` (RLS hazır, is_deleted=false select, owner CRUD) | ✅ tablo | is_deleted=false visible | aynı repo (interface'te `comments` yok V1) | backend INSERT smoke PASS; UI'da YOK (snackbar) | ⚠️ Backend var, UI eksik (P1-B) |
| **Social Group create/list** | `social_groups` + snapshot owner_name + member_count trigger | ✅ | scope visible + owner CRUD | `Local + Supabase + Guarded` | smoke create + member_count=1 | ✅ Gerçek |
| **Social Group membership** | `group_members` + max_members enforce trigger + bump counter | ✅ | self / member-of-visible-group; enforce trigger | aynı repo | smoke owner-join + max_members | ✅ Gerçek |
| **Social Group messages** | `group_messages` + snapshot + visibility policy | ✅ | is_deleted=false AND visible group; member-only INSERT (P0 fix) | aynı repo | smoke insert + cross-user reject (403) | ✅ Gerçek (P0 fix sonrası) |
| **Recipe (kütüphane + visibility)** | `recipe_calculations` + metadata jsonb + is_public + published_at + trigger hesaplama | ✅ | owner CRUD + public select | `Local + Supabase + Guarded` | smoke create + trigger (water_kg/yeast_kg/...) | ✅ Gerçek |
| **Calculator** | n/a (client-side `RecipeCalculator`) | n/a | n/a | client-only | unit test 50/60/1/2/250/3 → 316 adet | ✅ Çalışıyor (offline) |
| **Bakery (üretim/fire/gün sonu/rapor)** | `bakeries`, `bakery_products`, `production_entries`, `waste_entries` + trigger (estimated_loss) | ✅ | owner CRUD | bakery + recipe repo'lar | smoke create production + waste | ✅ Gerçek |
| **Dealer (V1 + V1.2)** | `dealers` (+customer_type/working_type/contact_name) + `dealer_deliveries` + `dealer_delivery_items` + `dealer_transactions` + `dealer_prices` + `dealer_notes` + cross-owner trigger | ✅ | owner CRUD | `Local + Supabase + Guarded` | tüm chain smoke PASS (delivery + payment tx + price + note) | ✅ Gerçek |
| **Wholesale customers** | `dealers.customer_type='wholesale_customer'` paylaşılan | ✅ | owner CRUD | aynı dealer repo, filter ile | smoke (bakery_dealer ile aynı yol) | ✅ Gerçek |
| **Worker profile / experience** | `worker_profiles` (unique owner) + `worker_experiences` | ✅ | authenticated select + owner CRUD | `Local + Supabase + Guarded` | smoke upsert + add experience | ✅ Gerçek |
| **Job seek post (İş Arıyorum)** | `job_seek_posts` + RLS (is_active=true OR owner) | ✅ | aktif veya owner | worker repo + `activeJobSeekPostsProvider` | smoke create; UI provider gerçek listeyi gösterir | ✅ Gerçek |
| **"Usta Arıyor" segmenti** | YOK (tablo yok) | ❌ | — | — | — | ⏸️ V2 coming-soon kart (dürüst) |
| **JobsCard "Başvur" CTA** | YOK (mesajlaşma backend yok) | ❌ | — | — | — | ⚠️ Snackbar default (dürüst, P1-C cleanup sonrası) |
| **Marketplace** | YOK (tablo yok) | ❌ | — | — | — | ⏸️ V2 coming-soon ekran; bottom nav'dan kaldırıldı |
| **Ürün ilanı ver (Toptancı role kartı)** | YOK | ❌ | — | — | — | ⏸️ comingSoon role panel kartı |
| **Account deletion** | Edge Function `delete-account` v1 ACTIVE verify_jwt + `auth.admin.deleteUser` + CASCADE | ✅ | function caller-self only | `SupabaseAuthRepository.deleteAccount` → `functions.invoke('delete-account', body:{confirm:true})` | live smoke 7/7 (negative + positive + cascade) | ✅ Gerçek |
| **Legal (Terms / Privacy)** | YOK (hardcoded UI metni) | ❌ | — | — | — | ⚠️ V1 taslak — hukuki review (P0-B) |
| **Notifications (Feed header)** | YOK | ❌ | — | — | — | ⚠️ Snackbar "yakında" (dürüst) |

---

## Özet sayılar

- **Gerçek + Supabase-backed:** 16 feature (auth, profile, feed post/like/save, recipe, bakery, production, waste, dealer+wholesale+V1.2 extensions, worker profile+experience+job seek, account deletion, social groups full)
- **Backend hazır, UI eksik (P1):** 1 (feed comment)
- **V2 / coming-soon (dürüst):** 4 (Marketplace, "Usta Arıyor", JobsCard Başvur snackbar, Toptancı ürün ilanı kartı)
- **Hardcoded (legal review bekliyor):** 2 (Terms, Privacy)
- **Client-side only:** 1 (Calculator)

## Net cevap

| Soru | Cevap |
|---|---|
| Feed Supabase'de gerçek mi? | ✅ Evet (post/like/save/comment hepsi tablolarda; comment UI yarın) |
| Groups Supabase'de gerçek mi? | ✅ Evet (V1 + 2 P0 RLS fix sonrası) |
| Jobs (İş Arıyorum) backend gerçek mi? | ✅ Evet |
| Usta Arıyor / İş Veriyorum backend var mı? | ❌ Hayır — V2 (UI dürüst placeholder) |
| Marketplace backend var mı? | ❌ Hayır — V2 (UI coming-soon, bottom nav'dan kaldırıldı) |
| Reçete / Bayi / Worker / Hesap silme gerçek mi? | ✅ Hepsi gerçek (smoke kanıtlı) |
