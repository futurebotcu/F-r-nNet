# FırınNet — UI No-Op Cleanup Report

**Tarih:** 2026-05-16
**Repo:** `C:\dev\firinnet`
**Branch:** `main`
**Kapsam:** Kullanıcıya görünen ama "tıklanıyor, hiçbir şey olmuyor" hissini yaratan P1 no-op CTA'larının temizlenmesi. Release/signing/store konuşması YOK.

> İlgili önceki bulgular: `FULL_PRODUCT_AUDIT_REPORT.md` P1 listesi (A–F), `FULL_BUTTON_ACTION_MATRIX.md` no-op özet.

---

## Executive Summary

Tüm 5 hedef P1 no-op kapatıldı. Profile ekranındaki 5 sahte tile listesi tamamen kaldırıldı, hesap silme butonu kendi "Tehlikeli alan" kartında danger-vurgulu hâle getirildi, Feed search ve Bakery panel calendar icon'ları sessiz no-op'tan kaldırıldı, JobOpportunityCard "Başvur" butonu artık dürüst snackbar veriyor.

| Kontrol | Sonuç |
|---|---|
| `flutter analyze --no-pub` | ✅ No issues found! |
| `flutter test --no-pub` | ✅ 210/210 passed |
| `_noop` / `onPressed: () {}` / `onTap: () {}` grep | ✅ 1 yorum-referans (gerçek kod yok) |
| `debugPrint / print( / service_role` (lib/) | ✅ Sadece açıklayıcı yorum mention |

---

## Fixed buttons

| ID | Konum | Önce | Sonra |
|---|---|---|---|
| **P1-C** | `lib/core/widgets/premium/job_opportunity_card.dart` "Başvur" | `onPressed: onApply ?? () {}` (sessiz no-op) | `onApply ?? () => snackbar(jobsApplyComingSoon)` — "Başvuru yakında — V2'de iletişim ve mesajlaşma açılacak." |
| **P1-F** | `lib/features/profile/screens/profile_screen.dart` "Hesabımı Sil" | `TextButton.icon` düşük vurgu | Yeni `_DangerZoneCard`: danger border + uyarı satırı + `OutlinedButton.icon` danger color, kalın border, büyük font. Yeni `SectionLabel('Tehlikeli alan')` üst başlık. |

## Hidden in V1

| ID | Konum | Önce | Sonra |
|---|---|---|---|
| **P1-A** | `profile_screen.dart` "Hesap" SectionLabel + `_AccountList` (5 NO-OP tile: İşletme Bilgileri / Ürünlerim / Raporlarım / E-posta / Ayarlar) | Tıklanıyor, hiçbir şey olmuyor | Section tamamen kaldırıldı. `_AccountList`, `_AccountTile`, `_Item` class'ları silindi. Bu 4 işlev zaten panel/recipes/report'tan erişilebilir; profil ekranı sadece "kim olduğunu" gösterir + tehlikeli alan sunar. E-posta gelecekte Hero'ya `MetricPill` ile eklenebilir. |
| **P1-D** | `bakery_panel_screen.dart` header `Icons.calendar_month_outlined` | `onTap: () {}` boş | `HeaderActionButton` tamamen kaldırıldı; `actions` parametresi `FirinNetHeader`'a hiç verilmiyor. Tarih zaten alt başlıkta. |
| **P1-E** | `feed_screen.dart` header `Icons.search_rounded` | `onTap: _noop` (top-level `_noop()` fonksiyonu) | `HeaderActionButton` kaldırıldı + `_noop` function silindi. Header'da Groups shortcut + Profile avatar kaldı. |

## Coming-soon (dürüst)

Bu PR'da yeni "coming-soon" eklenmedi; mevcut dürüst snackbar'lar korundu:

- Feed header notifications (`feed_screen.dart`) — snackbar "yakında" (eski davranış)
- Feed post Comment / Share / Tag (`feed_post_card.dart`) — snackbar (yorum tablosu Supabase'de mevcut ama UI V2)
- Marketplace (`marketplace_screen.dart`) — coming-soon kart (önceki PR)
- Jobs "Usta Arıyor" segmenti — coming-soon kart (önceki PR)

## Still V2 (kabul, dürüst raporlanıyor)

- **Feed yorum UI** (`feed_comments` tablo hazır, UI snackbar) — P1-B raporlandı ama bu turda kapsam dışı. Comment sheet/screen ayrı PR'da yapılır.
- **Mesajlaşma backend** — "Başvur" snackbar dürüst V2 mesajı veriyor; backend ayrı PR.
- **Marketplace backend** — bilinçli coming-soon.

## Files changed

| Dosya | Tür | Açıklama |
|---|---|---|
| `lib/core/constants/app_strings.dart` | M | 3 yeni copy: `jobsApplyComingSoon`, `profileSectionDanger`, `profileDangerHint` |
| `lib/core/widgets/premium/job_opportunity_card.dart` | M | `onApply` null ise snackbar default |
| `lib/features/feed/screens/feed_screen.dart` | M | Search HeaderActionButton + top-level `_noop()` kaldırıldı |
| `lib/features/bakery_panel/screens/bakery_panel_screen.dart` | M | Calendar HeaderActionButton kaldırıldı |
| `lib/features/profile/screens/profile_screen.dart` | M | Account list section kaldırıldı; `_DangerZoneCard` eklendi; eski `_AccountList`/`_AccountTile`/`_Item` class'ları silindi |
| `UI_NOOP_CLEANUP_REPORT.md` | A | Bu rapor |

Toplam 5 lib/ dosyası + 1 rapor.

## analyze / test result

```
flutter analyze --no-pub  →  No issues found! (0.8s)
flutter test --no-pub     →  210 / 210 passed
```

### Grep tarama

- `_noop|onPressed: () {}|onTap: () {}` → 1 eşleşme: `feed_screen.dart:89` yorum içinde "V1'de _noop'tu" şeklinde (yorum, gerçek kod değil).
- `debugPrint|print(|service_role|SUPABASE_SERVICE` (lib/ altında) → 2 dosya, ikisi de **yorum bağlamında**:
  - `profile_screen.dart` "service_role kullanılmaz" açıklaması
  - `auth_repository.dart` doc'unda service_role mention
  - **Hiçbir gerçek kullanım yok**.

Hardcoded JWT / Bearer service_role literal: yok.

## Remaining manual UI smoke items (P0-A — kullanıcı tarafı)

Bu PR sadece kod tarafını temizledi. **Manuel UI smoke (A-K runbook)** hâlâ açık:
- Cihaz/emülator çalıştırma + parmak akışı
- RenderFlex overflow uyarısı kontrolü
- Yeni `_DangerZoneCard` görsel doğrulama
- Account list kaldırıldıktan sonra profil ekranı estetik kontrol

Çalıştırma: `.\scripts\run_supabase_android.ps1 -DeviceId emulator-5554`
Detay runbook: `UI_SMOKE_RUNBOOK_AK.md`.

## Kalan açık iş

- **P0-A** Manuel UI smoke (kullanıcı tarafı)
- **P0-B** Legal Terms/Privacy nihai metin (hukuki review)
- **P0-C** Android release signing config
- **P1-B** Feed yorum UI (sheet/screen + repository hookup — ayrı PR)
- **P1-G** Supabase Dashboard → Auth → leaked password protection enable (Auth ayarı)
- **P2-x** RLS initplan + V2 backend'ler + audit log + soft-delete

## Karar

Bu PR'dan sonra **görünen hiçbir buton sessiz no-op değil**. Kullanıcı tıklarsa ya gerçek bir şey olur, ya dürüst bir snackbar görür, ya da buton hiç yoktur. Yamalı hissi P1 listesinden tamamen kapatıldı.
