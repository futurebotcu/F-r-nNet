# FırınNet — Full App Supabase Smoke Report

**Tarih:** 2026-05-16
**Proje:** FırınNet, Supabase ref `sjeqwiqgwzagengdukye`
**Ortam:** Windows 11 (`C:\dev\firinnet`), Flutter SDK ^3.9.2
**Hedef:** "Uygulama gerçekten çalışıyor mu?" — release/mağaza konuşmasından ÖNCE.

---

## TL;DR

- ✅ **Statik tüm yeşil:** `flutter analyze` No issues + `flutter test` **210/210** + `flutter build apk --debug` başarılı (tüm Dart kodu compile + widget tree bütünlüğü tamam).
- ✅ **Backend uçtan-uca 28/28 PASS:** Tek gerçek auth user JWT ile profiles trigger + worker + bakery + recipe + production + waste + dealer + delivery + payment + price + note + feed + like + save + comment + counter trigger + group + member + message + counter trigger + account deletion + CASCADE — hepsi UI'in çağıracağı PostgREST/Function endpoint'leri üzerinden test edildi.
- ✅ **Cleanup kusursuz:** Test user CASCADE ile temizlendi; mevcut Fatih kullanıcısı + 1 bakery satırı dokunulmadı (`auth_users_smoke_residue=0`).
- ⏸️ **UI smoke (manuel) hâlâ açık:** Kod tarafı yeşil, backend tarafı kanıtlandı, ama gerçek ekran/parmak akışı henüz kullanıcı tarafından gözle doğrulanmadı. Bu raporun "Manuel UI Runbook" bölümünü kullanıcı tamamlamalı.

> **Karar:** Backend/Supabase tarafı release konuşmaya hazır. UI smoke kullanıcı çalıştırması beklediği için "release konuşmaya hazır mıyız?" sorusu hâlâ **kısmi hayır** — manuel UI smoke kalmaya devam ediyor.

---

## Test edilen ortam

| Madde | Değer |
|---|---|
| Repo | `C:\dev\firinnet` (FırınNet / `firin_defter`) |
| Branch | `main` @ `e43ecb6` |
| Supabase project | `sjeqwiqgwzagengdukye` (eu-central-1, ACTIVE_HEALTHY, Postgres 17.6.1.121) |
| `.env.local` (anon key) | UI smoke için kullanıcı dolduracak (şu an boş) |
| `.env.admin.local` (service_role) | Dolu (admin smoke için, ignored) |
| `flutter devices` | emulator-5554 (Android), windows desktop, chrome, edge |

Bilinen sınır: Windows desktop platform config yok (`flutter build windows` → "No Windows desktop project configured"). APK build başarılı (Android compile).

---

## A. Otomatik doğrulamalar (Claude tarafından çalıştırıldı)

### A.1 Statik (210/210)

```
flutter analyze --no-pub  →  No issues found! (0.7s)
flutter test --no-pub     →  210/210 passed
flutter build apk --debug →  √ Built build/app/outputs/flutter-apk/app-debug.apk (25.6s)
```

Test kapsamı: provider selection, guarded write block, migration SQL smoke, dealer/recipe/worker model + persist round-trip, feed composer layout, role panel cards, recipe calculator, guest guard, social_spine_v1 smoke, jobs_marketplace_p0 cleanup, account_deletion_p0.

### A.2 Live backend uçtan-uca (28/28)

Script: `scripts/admin/full_app_backend_smoke.ps1`
Yöntem: Geçici test user (`firinnet_smoke_full_…@example.com`) Admin API ile yarat → sign-in JWT al → tüm yazma yollarını user JWT'siyle PostgREST üzerinden çağır → counter trigger'larını oku → delete-account function ile temizle.

| Modül | Test | Sonuç |
|---|---|---|
| Auth | create test user (Admin API) | ✅ 200 |
| Auth | sign-in | ✅ 200 |
| Profile | auto-created via `handle_new_user` | ✅ 200 |
| Worker | upsert worker_profile | ✅ 201 |
| Worker | add worker_experience | ✅ 201 |
| Worker | create job_seek_post | ✅ 201 |
| Bakery | create bakery | ✅ 201 |
| Bakery | add bakery_product | ✅ 201 |
| Recipe | create recipe_calculation | ✅ 201 |
| Production | add production_entry | ✅ 201 |
| Waste | add waste_entry | ✅ 201 |
| Dealer | create dealer | ✅ 201 |
| Dealer | create dealer_delivery | ✅ 201 |
| Dealer | add dealer_delivery_item | ✅ 201 |
| Dealer | create payment dealer_transaction | ✅ 201 |
| Dealer | add dealer_price | ✅ 201 |
| Dealer | add dealer_note | ✅ 201 |
| Feed | create feed_post | ✅ 201 |
| Feed | like own post | ✅ 201 |
| Feed | save own post | ✅ 201 |
| Feed | comment own post | ✅ 201 |
| Feed | counter trigger (like=1, comment=1) | ✅ 200 |
| Group | create social_group | ✅ 201 |
| Group | owner join group_members | ✅ 201 |
| Group | post group_message | ✅ 201 |
| Group | member_count trigger (=1) | ✅ 200 |
| Account | delete-account function | ✅ 200 + `{ok:true}` |
| Account | user 404 after delete | ✅ 404 |

**TOTAL: 28 / 28 PASS · FAIL: 0**

### A.3 Cleanup teyit (MCP execute_sql)

```
auth_users_smoke_residue   : 0
profiles_smoke_residue     : 0
bakeries_total             : 1   ← Fatih korunmuş
dealers_total              : 0
dealer_transactions_total  : 0
worker_profiles_total      : 0
worker_experiences_total   : 0
job_seek_posts_total       : 0
recipe_calculations_total  : 0
feed_posts_total           : 0
social_groups_total        : 0
auth_users_total           : 1   ← Fatih korunmuş
```

CASCADE kusursuz; test verisi sıfır kaldı, gerçek kullanıcı verisine dokunulmadı.

### A.4 Secret hijyeni

- `service_role` konsola/log'a yazılmadı (script "present: yes" masking).
- Test user UUID'i bilinçli olarak yazdırılmadı.
- `.env.admin.local` ve `.env.local` git'te yok (ignored, line 60/64).
- Flutter `lib/` altında hardcoded JWT pattern (`eyJ…`) yok; `Bearer service_role` literal yok (`test/account_deletion_p0_test.dart` ile koruma altında).

---

## B. Manuel UI Smoke Runbook (kullanıcı tarafı)

Ben bu adımları çalıştıramam (gerçek pencerede tıklama gerek). Aşağıdaki adımları sen çalıştır, her madde için OK / FAIL not al. FAIL varsa logu kopyala.

### Ön hazırlık

1. `.env.local` doldur: Supabase Dashboard → Project Settings → API → URL + anon (publishable) key. service_role ASLA bu dosyaya konmaz.
2. Çalıştır (Windows için Windows desktop platform config gerekirse Android emulator kullan):
   ```powershell
   .\scripts\run_supabase_android.ps1 -DeviceId emulator-5554
   ```
   (veya `run_supabase_windows.ps1`, sonra "No Windows desktop project configured" hatası alırsan `flutter create --platforms=windows .` çalıştırıp tekrar dene — kullanıcı kararı.)

### Akış checklist

**A. App startup**
- [ ] `.env.local` doluyken: Splash → AuthEntry → "Giriş Yap / Üye Ol / Kayıtsız Devam" gözüküyor mu?
- [ ] `.env.local` boşken: AuthEntry açılır, "Canlı giriş kapalı. Kayıtsız devam edebilirsin." banner görünür mü?
- [ ] Fatal exception / red error screen yok mu?

**B. Auth**
- [ ] Mevcut Fatih kullanıcısıyla "Giriş Yap" → email + password → başarılı mı?
- [ ] Giriş sonrası `/feed` ekranına geçiyor mu?
- [ ] Profile → "Profilden Çık" → AuthEntry'e dönüyor mu?
- [ ] "Kayıtsız Devam" → guest mode aktif, feed seed (Local) görünüyor mu?

**C. Feed**
- [ ] Feed sayfası ilk açılışta: yeni hesap için empty state "Henüz paylaşım yok…" mı, eski hesap için liste mi?
- [ ] Composer → metin yaz → tip seç → Paylaş → post listede görünüyor mu? (`author_name=Fatih`, `author_role=Usta Fırıncı` snapshot trigger)
- [ ] Beğen → kalp dolu, sayaç 1 → tekrar tıkla → 0
- [ ] Kaydet → bookmark dolu → tekrar → boş
- [ ] App'i tamamen kapat + tekrar aç + giriş → post hâlâ orada mı?

**D. Groups**
- [ ] Groups tab açılıyor mu?
- [ ] FAB → yeni grup oluştur → form (ad/kategori/şehir/public/limit) → kaydet
- [ ] Detail ekran açılıyor mu? `owner_name=Fatih`, `member_count=1`
- [ ] Mesaj yaz → liste güncelleniyor mu? `author_name=Fatih`
- [ ] Groups listesine dön → yeni grup görünüyor mu?

**E. Jobs**
- [ ] Jobs tab açılıyor mu?
- [ ] "Usta Arıyor" segmenti: coming-soon kartı mı görünüyor? (mock fırın ilanı YOK)
- [ ] "İş Arıyor" segmenti: empty state mi gösteriyor ("Henüz aktif iş arayan ilanı yok.")?
- [ ] "+" butonu → AuthRequired bottom sheet (guest) veya `/worker/job-seek/new` form (auth) açılıyor mu?

**F. Marketplace**
- [ ] Bottom nav'da Market tab YOK ✅ (Feed / Gruplar / İlanlar / Panel = 4 tab)
- [ ] Doğrudan URL ile `/market`'a git → coming-soon kartı çıkıyor mu? Sahte ürün/satıcı/fiyat YOK olmalı.

**G. Recipe / Calculator**
- [ ] Panel → Reçeteler → ekran açılıyor mu?
- [ ] Yeni reçete oluştur → kaydet → listede görünüyor mu?
- [ ] Public/private toggle çalışıyor mu? Profil ekranında public reçete görünüyor mu?
- [ ] Calculator açılıyor mu, default 50/60/1/2/250/3 hesabı 316 adet veriyor mu?

**H. Dealer / Wholesale**
- [ ] Panel → Bayi Paneli → liste açılıyor mu?
- [ ] FAB → bayi ekle → form → kaydet
- [ ] Bayi detail → "Ürün Ver" → form → kaydet → bakiye doğru mu?
- [ ] "Ödeme Al" → bakiye düşüyor mu?
- [ ] "İade Al" → bakiye doğru mu?
- [ ] "Düzeltme" → bakiye doğru mu?

**I. Worker (Bireysel)**
- [ ] Panel → Ustalık Bilgilerim → ekran açılıyor mu?
- [ ] Profil kaydet → tekrar girince yüklenir mi?
- [ ] Çalışma Geçmişim → ekle/sil çalışıyor mu?
- [ ] İş Arıyorum İlanı Ver → form → aktif/pasif toggle çalışıyor mu?

**J. Account deletion UI**
- [ ] Profile → "Hesabımı Sil" butonu (kırmızı) görünüyor mu?
- [ ] Tıkla → dialog: "Bu işlem geri alınamaz" + TextField + "HESABIMI SİL" yazana kadar disabled buton
- [ ] Yanlış kelime yazınca buton disabled kalır mı?
- [ ] "Vazgeç" tıklayınca dialog kapanır mı?
- [ ] **GERÇEK FATIH KULLANICISIYLA SİLME YAPMA**. Test için ayrı bir geçici hesap oluştur, onunla dene.
  - [ ] Doğru keyword + onay → loading dialog → AuthEntry'e dönüş + "Hesabın silindi." snackbar
  - [ ] Tekrar giriş yapmayı dene → hesabın yok diye reddeder mi?

**K. Logs (Flutter console)**
- [ ] Build/run sırasında fatal exception VAR/YOK mu?
- [ ] RenderFlex overflow uyarısı VAR/YOK mu?
- [ ] Supabase'ten 400/401/403 hata (beklenmedik) çıkıyor mu?
- [ ] Hot reload / hot restart çalışıyor mu?

### Sonuç formatı (bana yapıştır)

```
A: OK / FAIL
B: OK / FAIL
C: OK / FAIL
D: OK / FAIL
E: OK / FAIL
F: OK / FAIL
G: OK / FAIL
H: OK / FAIL
I: OK / FAIL
J: OK / FAIL (test hesabıyla)
K: log özet (kritik hata varsa kopyala)
```

---

## C. Kalan gerçek çalışma blocker'ları

| Madde | Tip | Etki |
|---|---|---|
| Manuel UI smoke (A-K) yapılmadı | İş | Ekran/parmak akışında bilinmeyen var; backend kanıtlandı |
| Windows desktop platform config yok | Setup | `flutter run -d windows` direkt çalışmaz; emülatörle `run_supabase_android.ps1` çalışır |
| `auth_rls_initplan` 22 policy WARN | Perf | Apply'ı bloklamaz; scale'de yavaşlık |
| `auth_leaked_password_protection` kapalı | Auth setting | Supabase Dashboard → Auth ayarı |

**Yok:**
- ❌ Yeni P0 security blocker yok (RLS testleri 22/22 ve account deletion smoke 7/7 geçti).
- ❌ Schema mismatch / kırık migration yok (tüm 28 yazma yolu çalıştı).
- ❌ Flutter compile error yok (APK build başarılı).

---

## D. Release konuşmaya hazır mıyız?

| Madde | Durum |
|---|---|
| Backend / Supabase | ✅ Hazır (28/28 backend smoke + 22/22 RLS smoke + cleanup CASCADE OK) |
| Flutter compile + test | ✅ Hazır (210/210 + APK build) |
| Hesap silme | ✅ Hazır (function + UI + live smoke) |
| Marketplace mock temizliği | ✅ Hazır |
| Jobs gerçek veri bağlantısı | ✅ Hazır |
| Sosyal omurga RLS | ✅ Hazır (2 P0 fix sonrası) |
| **Manuel UI smoke** | ⏸️ **Kullanıcı tarafında bekliyor** |
| Android release signing | ❌ Açık P0 |
| Privacy/Terms taslak banner | ❌ Açık P0 (legal onay sonrası) |

**Net karar:** Backend + kod yeşil. Mağaza/release konuşmadan ÖNCE kalan iki gerçek iş:
1. **Manuel UI smoke** (yukarıdaki runbook A-K).
2. **Android release signing config** (ayrı PR).

UI smoke geçerse + signing tamamlanırsa + Privacy/Terms taslak banner eklenirse release konuşulabilir. Şu an UI smoke açık olduğu için "release hazır" demek yanlış.

---

## E. Dosyalar (commit edilmedi, kullanıcı kuralı gereği)

Bu raporla birlikte oluşturulan ama henüz commit edilmemiş dosyalar:
- `FULL_APP_SUPABASE_UI_SMOKE_REPORT.md` (bu rapor)
- `scripts/admin/full_app_backend_smoke.ps1` (uçtan-uca runner)

Diğer mevcut commit'lerden gelen ilgili dosyalar (push'lu):
- `scripts/admin/cross_user_rls_smoke.ps1`
- `scripts/admin/account_deletion_smoke.ps1`
- `scripts/admin/check_admin_access.ps1`
- `scripts/run_supabase_windows.ps1` / `run_supabase_android.ps1` / `build_release_supabase_aab.ps1`
- `SUPABASE_ADMIN_RUNBOOK.md`, `SUPABASE_LOCAL_RUNBOOK.md`

Commit/push talimatın olmadan **yapılmadı**.
