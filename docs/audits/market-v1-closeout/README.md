# Market V1 closeout — audit snapshot arşivi

**Snapshot tarihi:** 2026-05-15 / 2026-05-16
**Snapshot branch:** `main` @ `970de7f`
**Arşiv tarihi:** 2026-05-20 (Market V1 closeout sonrası)
**Closeout commit:** `0d210bb` (`main`)

Bu klasör, Market V1 sprintinin **öncesinde** üretilen 4 audit raporunu tarihsel
baseline olarak saklar. Hepsi 2026-05-15 / 2026-05-16 tarihli; sonraki sprintler
bu snapshot'ın hangi maddelerini çözdüğünü "before / after" karşılaştırmak için
kullanılabilir.

## Dosyalar

| Dosya | İçerik |
|---|---|
| `FEATURE_BACKEND_REALITY_MATRIX.md` | Her feature için Supabase obj × RLS × repo × smoke × verdict tablosu |
| `FIRINNET_RELEASE_BLOCKERS.md` | P0/P1/P2 release blocker matrisi (mağaza/KVKK/Android/legal) |
| `FULL_BUTTON_ACTION_MATRIX.md` | 41 ekran × buton/CTA action durumu (WORKING / AUTH / SNACKBAR / NO_OP …) |
| `INTEGRATION_GAPS_AND_FIX_PLAN.md` | Round-3 audit özet + P0/P1/P2 karar tablosu + fix önerileri |

## Market V1 sonrası çözülen maddeler

| Snapshot ID / başlık | Durum (HEAD `0d210bb` itibarıyla) | Çözen commit(ler) |
|---|---|---|
| **Marketplace bottom nav 3. tab tamamen statik mock** | ÇÖZÜLDÜ — real `market_listings` + RLS + UI + controlled data | `af4353f` (M1) + `f5e4851` (M2) + `24dc84e` (nav+controlled) + `0d210bb` (M3 polish) |
| **Marketplace `_items` const** | ÇÖZÜLDÜ — `filteredMarketListingsProvider` + `MarketplaceListingCard` | `f5e4851` |
| **`HeaderActionButton` Market tune NO_OP** | ÇÖZÜLDÜ — Filtrele butonu `MarketplaceFiltersSheet` açar | `f5e4851` |
| **Marketplace P0 (mock cleanup)** | Tabloda "tab kaldır" alternatifi vardı — V1 sonrası tab geri geldi gerçek backend ile | `24dc84e` |

## Market V1 dışı, hâlâ açık kalan maddeler

| Snapshot ID | Durum | Not |
|---|---|---|
| **P0-B (Legal Terms/Privacy "V1 taslak" banner)** | AÇIK | Hukuki nihai metin onayı + draft banner kaldırma — Market V1 kapsam dışı |
| **P0-C (Android release signing config yok)** | AÇIK | `android/key.properties` + `signingConfig.release` — release sprintine kaldı |
| **P1-G (auth_leaked_password_protection kapalı)** | AÇIK | Supabase Dashboard ayarı; kod değişikliği yok |
| **P1 (production_date UTC kayması)** | AÇIK | Asia/Istanbul normalize — bakery_panel/dealer sprintine kaldı |
| **P1 (Profile hardcoded stats)** | AÇIK | "12 Paylaşım / 186 Bağlantı" hâlâ mock — V1.1 polish |
| **P1-B (Feed yorum UI)** | ÇÖZÜLDÜ (V2 social sprint) | Donor-first social refactor, comments rebuild |
| **P0 Sosyal (Feed Local-only)** | ÇÖZÜLDÜ (V2 social sprint) | `SupabaseFeedRepository` + RLS + media |
| **P0 Sosyal (Groups Local-only)** | ÇÖZÜLDÜ (V1 social_groups sprint) | groups + members + messages tabloları |
| **P0 Jobs hardcoded mock** | ÇÖZÜLDÜ (V2 jobs sprint) | `activeJobOffersProvider` + real form |
| **P0 KVKK Hesap silme yok** | ÇÖZÜLDÜ (V1 P0) | `AccountDeleteService` + RPC |

## Önemli not

Bu dosyalar **statik snapshot**'tır. Anlık doğruluk için canlı kaynaklar
güncel olur:
- `git log` / `git blame` — gerçek değişiklik tarihçesi
- `supabase/migrations/` — uygulanmış şema değişiklikleri
- `MEMORY.md` (`claude/memory`) — kullanıcı/proje state'i
- `flutter test` — invariant'ların güncel doğruluğu

Yeni audit yapılacaksa bu klasörün dışında `docs/audits/<sprint-name>/`
altında ayrı snapshot tut.
