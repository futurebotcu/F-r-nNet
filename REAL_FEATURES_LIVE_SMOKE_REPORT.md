# FırınNet — Real Features Live Smoke (job_offer_posts + market_listings)

**Tarih:** 2026-05-16
**Proje:** FırınNet, ref `sjeqwiqgwzagengdukye`
**Sprint commit:** `29c42dd` (yeni 2 tablo: `job_offer_posts`, `market_listings`)
**Script:** `scripts/admin/real_features_live_smoke.ps1` (yeni)
**Önceki tur:** "dolaylı" verify (MCP cleanup + statik test) — bu turda **gerçek 2-user JWT cross-owner smoke** yapıldı.

---

## TL;DR

- ✅ **24 / 24 PASS** — tüm cross-owner deny + owner-only CRUD + check constraint validation + cascade temizliği geçti.
- ✅ MCP cleanup teyit: smoke residue **0**, Fatih kullanıcısı + 1 bakery dokunulmadı.
- ✅ `flutter analyze` No issues + `flutter test` **228 / 228** passed.
- ✅ Hardcoded JWT (`eyJ…`) `lib/test/scripts/supabase/*` taramasında yok.
- ✅ 29c42dd commit'i artık **dolaylı değil, doğrudan canlı kanıtla** push'a hazır.

---

## Akış

`scripts/admin/real_features_live_smoke.ps1`:
1. Admin API ile 2 geçici test user (A + B), email `firinnet_smoke_rf_{a,b}_<ts>@example.com`
2. Her ikisi için sign-in → access_token
3. User A her tablo için INSERT + SELECT + UPDATE/toggle + DELETE
4. User B cross-owner attack vektörleri (forge owner_id + UPDATE + DELETE)
5. Check constraint validation (geçersiz category + listing_type)
6. Admin API ile user delete → CASCADE → profiles + job_offer_posts + market_listings + feed_comments
7. MCP `execute_sql` ile bağımsız residue verify

## Sonuçlar (24 / 24)

### Auth setup (4)
| Test | Sonuç | Detay |
|---|---|---|
| Auth: create user A (Admin API) | ✅ PASS | 200 |
| Auth: create user B (Admin API) | ✅ PASS | 200 |
| Auth: sign-in A | ✅ PASS | 200 |
| Auth: sign-in B | ✅ PASS | 200 |

### `job_offer_posts` smoke (8)
| Test | Sonuç | Detay |
|---|---|---|
| A insert own | ✅ PASS | 201 |
| A reads own offer | ✅ PASS | 200 |
| B reads active offers (authenticated select) | ✅ PASS | 200 |
| **B cannot insert with owner=A** (cross-owner forge) | ✅ PASS | **403** |
| **B cannot UPDATE A offer** | ✅ PASS | PATCH 204 ama RLS filter 0 row; title unchanged |
| **B cannot DELETE A offer** | ✅ PASS | DELETE 204 ama still_exists=True |
| A toggle inactive → public select'ten gizlenir | ✅ PASS | stillActive=False |
| A deletes own offer | ✅ PASS | 204 |

### `market_listings` smoke (10)
| Test | Sonuç | Detay |
|---|---|---|
| A insert own | ✅ PASS | 201 |
| A reads own listing | ✅ PASS | 200 |
| B reads active listings (authenticated select) | ✅ PASS | 200 |
| **B cannot insert with owner=A** | ✅ PASS | **403** |
| **B cannot UPDATE A listing** | ✅ PASS | PATCH 204 ama unchanged |
| **B cannot DELETE A listing** | ✅ PASS | DELETE 204 ama still_exists=True |
| Invalid `category='invalid_category_xxx'` rejected | ✅ PASS | 400 (check constraint) |
| Invalid `listing_type='invalid_type_xxx'` rejected | ✅ PASS | 400 (check constraint) |
| A toggle inactive → public select'ten gizlenir | ✅ PASS | stillActive=False |
| A deletes own listing | ✅ PASS | 204 |

### Cleanup (2)
| Test | Sonuç | Detay |
|---|---|---|
| Cleanup: delete user A (CASCADE) | ✅ PASS | 200 |
| Cleanup: delete user B (CASCADE) | ✅ PASS | 200 |

**TOTAL: 24 / 24 PASS · 0 FAIL.**

---

## MCP bağımsız teyit

```
auth_users_total           : 1   ← Fatih korunmuş
auth_users_smoke_residue   : 0
profiles_total             : 1
profiles_smoke_residue     : 0
job_offer_posts_total      : 0
market_listings_total      : 0
feed_comments_total        : 0
fatih_bakeries             : 1   ← Fatih bakery'si korunmuş
```

CASCADE zinciri (`auth.users → profiles → owner_id'li tablolar`) kusursuz çalıştı.

---

## Flutter quality (re-run)

```
flutter analyze --no-pub  →  No issues found! (1.5s)
flutter test --no-pub     →  228 / 228 passed (8s)
```

## Secret hijyeni

- `eyJ[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]+` JWT pattern `lib/test/scripts/supabase/*` taramasında **No matches**.
- Script "present: yes" masking ile çalışıyor; service_role konsola/log'a yazılmadı.
- Test user UUID'leri açıkça yazdırılmadı.

## Önceki "dolaylı" verify ile farkı

| Madde | Önceki tur | Bu tur |
|---|---|---|
| Inline PowerShell smoke | ❌ syntax fail | — |
| Ayrı script | yok | ✅ `real_features_live_smoke.ps1` (24 test) |
| Cross-owner forge (owner_id=A, JWT=B) | sadece statik test | ✅ canlı 403 |
| Cross-owner UPDATE/DELETE deny | yok | ✅ canlı (204 + unchanged + still_exists) |
| Check constraint (category/listing_type) | yok | ✅ canlı 400 |
| toggle is_active → public hide | yok | ✅ canlı stillActive=False |
| Owner own CRUD happy path | yok | ✅ canlı 201/200/204 |
| Cleanup CASCADE | MCP teyit | ✅ Script + MCP teyit |

Bu turda **dolaylı kanıt → doğrudan canlı kanıt**'a geçildi.

---

## Karar

29c42dd commit'i artık tam canlı kanıtla push'a hazır:
- Backend tarafı 24 / 24 gerçek cross-owner RLS smoke geçti
- Owner-only CRUD, public select, toggle ve check constraint hepsi doğru çalışıyor
- Fatih kullanıcısı dokunulmadı, residue 0
- Compile + test yeşili

Commit/push **yapılmadı** (kullanıcı talimatı). Bu rapor + script untracked.
