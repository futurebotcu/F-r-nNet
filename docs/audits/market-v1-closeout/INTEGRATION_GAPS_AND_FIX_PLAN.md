# FırınNet — Integration Gaps & Fix Plan (Round 3)

**Tarih:** 2026-05-16
**Branch:** `main` @ `970de7f`
**Kapsam:** Audit çıktısı net iş listesi. Release/signing **konuşmadan önce** kalan gerçek pürüzler.

---

## P0 / P1 / P2 Karar Tablosu

### P0 — Release blocker (kullanıcıya görünen / güvenlik / sahte içerik / fatal)

| ID | Alan | Sorun | Evidence | User impact | Fix recommendation |
|---|---|---|---|---|---|
| **P0-A** | Manuel UI smoke yapılmadı | Ekran/parmak doğrulaması yok | `UI_SMOKE_RUNBOOK_AK.md` A-K | RenderFlex overflow / fatal exception bilinmiyor | Sen runbook'u çalıştır, sonucu paylaş |
| **P0-B** | Legal Terms/Privacy taslak | "V1 taslak" banner duruyor | `terms_screen.dart` / `privacy_screen.dart` | KVKK/yasal risk; mağaza review | Hukuki nihai metin onayı + banner kaldır |
| **P0-C** | Android release signing config yok | `android/key.properties` + `signingConfig.release` tanımlı değil | repo audit | Release build debug imzasıyla çıkar | Keystore üret + signing config ekle |

### P1 — Ürün kalitesi (kullanıcı kalitesi)

| ID | Alan | Sorun | Evidence | User impact | Fix recommendation |
|---|---|---|---|---|---|
| **P1-B** | Feed yorum UI eksik | `feed_comments` tablo + RLS hazır, UI snackbar | `feed_post_card.dart` Comment CTA | Sosyal akış değerinin yarısı eksik | Comment sheet/screen ekle + `feed_comments` repository hookup |
| **P1-G** | `auth_leaked_password_protection` kapalı | Supabase Auth setting | advisor WARN | Compromised password kabul edilir | Dashboard → Auth → enable HIBP |

> **Round-3'te çözüldü:** P1-A (Profile NO-OP × 5), P1-C (JobsCard Başvur snackbar), P1-D (bakery calendar), P1-E (feed search), P1-F (Hesabımı Sil danger zone).

### P2 — Polish / V2

| ID | Alan | Sorun |
|---|---|---|
| **P2-A** | Realtime yok | Başka cihazda atılan post/mesaj otomatik gelmiyor |
| **P2-B** | Feed/Group/Job filtering UI eksik | Search bar var, scope dar |
| **P2-C** | Marketplace backend | V2 (ayrı PR) |
| **P2-D** | Jobs "Usta Arıyor" backend | V2 (ayrı PR) |
| **P2-E** | Mesajlaşma backend | "Başvur" CTA + paneldeki "Mesajlar" kartı buna bağlı |
| **P2-F** | `auth_rls_initplan` 22 policy WARN | `auth.uid()` → `(select auth.uid())` (scale perf) |
| **P2-G** | Soft-delete 30-gün geri al | Account deletion hard-delete |
| **P2-H** | Audit log (silme/IP/timestamp) | V2 compliance |
| **P2-I** | Re-authentication silmeden önce | Daha güvenli UX |

---

## Top-5 sıradaki düzeltme

| Sıra | İş | Tip | Tahmini iş | Bağlılık |
|---|---|---|---|---|
| 1 | **Manuel UI smoke (A-K)** | P0-A | 30-60 dk kullanıcı | `.env.local` doldur + cihaz |
| 2 | **Legal nihai metin** (P0-B) | P0-B | Hukuki review + banner kaldır | Avukat onayı |
| 3 | **Android release signing config** | P0-C | 30 dk + keystore üretimi | Keystore secret yönetimi |
| 4 | **Feed yorum UI (P1-B)** | P1-B | 2-3 saat (sheet + repo + provider) | `feed_comments` zaten hazır |
| 5 | **Leaked password setting** | P1-G | 1 dk dashboard tıklaması | Yok |

---

## Çözülen gap'ler (audit sonrası kapanan)

- ✅ Social spine Supabase'e geçti (4 commit: `a2c25d2`, `a82097c`, `1aa15f9`)
- ✅ 2 P0 RLS bug (group_messages insert alias bypass + group_members select recursion) → fix migration uygulandı
- ✅ Cross-user RLS smoke 22/22 gerçek RLS test
- ✅ Hesap silme Edge Function + UI (KVKK/Play uyumlu) → `e43ecb6`
- ✅ Backend uçtan-uca smoke kanıtlandı → `78205c2`
- ✅ Jobs/Marketplace mock cleanup → `930aa3a`
- ✅ UI no-op cleanup (5 P1) → `970de7f`
- ✅ Repo + secret hijyeni
- ✅ `flutter analyze` No issues + `flutter test` 210/210 + APK build başarılı

---

## Konuşmaya hazır mıyız?

| Konu | Durum |
|---|---|
| Backend/Supabase | ✅ Release-quality |
| Kod compile + test | ✅ Yeşil |
| Sosyal omurga (feed/groups/RLS/account-delete) | ✅ Çalışıyor |
| UI no-op / yamalı hissi | ✅ Temizlendi (Round-3) |
| Manuel UI smoke | ⏸️ Açık |
| Legal taslak | ⏸️ Açık |
| Android signing | ⏸️ Açık |
| Marketplace / mesajlaşma / Usta Arıyor | ⏸️ V2 (bilinçli, dürüst placeholder) |

**Net karar:** Backend ve UI gerçekliği release-konuşmaya hazır. **Eksik:** 3 P0 (UI smoke + Legal + Android signing) + 1 P1 büyük (Feed yorum UI). Bu 4 madde tamamlanırsa mağaza review'a yakın.

> Bu auditten sonra artık "sanıyoruz" değil, kanıtla konuşuyoruz: backend 28/28, RLS 22/22, account-delete 7/7, test 210/210, APK build OK, button reality matrix net, hiçbir görünen buton sessiz no-op değil.
