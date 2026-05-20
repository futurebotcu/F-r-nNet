# FırınNet — Full Button / CTA Action Matrix

**Tarih:** 2026-05-16
**Tarama:** `lib/features/**/screens/*.dart` (41 dosya) + `lib/core/widgets/premium/feed_post_card.dart`

**Status legend:**
- **WORKING** — gerçek repository çağrısı veya Edge Function
- **AUTH_REQUIRED** — AuthRequiredGuard / runGuardedMutation arkasında (guest için Sheet açar, auth için gerçek call)
- **ROUTE** — sadece `context.push/go` (zaten beklenen davranış)
- **SNACKBAR_ONLY** — sadece ScaffoldMessenger; gerçek backend YOK
- **NO_OP** — `() {}` boş callback
- **COMING_SOON** — ekran tamamı placeholder (Marketplace gibi)
- **EXTERNAL** — share_plus / url_launcher (telefon dışı)

---

## Auth + onboarding

| Screen | Button | Action | Status |
|---|---|---|---|
| splash_screen | (auto) → Auth state'e göre yönlendir | Stream listen + go | ROUTE |
| onboarding_screen | "Profil Oluştur" | push `/profile/create` | ROUTE |
| onboarding_screen | "Kayıtsız Devam" | setGuest(true) + go `/feed` | ROUTE |
| auth_entry_screen | "Giriş Yap" | push `/login` | ROUTE |
| auth_entry_screen | "Hesabım yok, üye ol" | push `/auth/role-select` | ROUTE |
| auth_entry_screen | "Kayıtsız devam et" | setGuest + go `/feed` | ROUTE |
| login_screen | Submit (email+password) | `authRepo.signIn()` → success: go panel | WORKING |
| login_screen | "Hesabın yok mu?" | push role-select | ROUTE |
| login_screen | "Şifremi unuttum" | push `/auth/forgot` | ROUTE |
| forgot_password_screen | Submit | `authRepo.resetPasswordForEmail()` | WORKING |
| role_select_screen | Ticari / Bireysel / Toptancı | push `/profile/create?role=X` | ROUTE |
| create_profile_screen | Submit | `authRepo.signUp()` + metadata | WORKING |
| create_profile_screen | "Üye olmadan gez" escape | setGuest + go `/feed` | ROUTE |

## Feed

| Screen | Button | Action | Status |
|---|---|---|---|
| feed_screen | Composer (Paylaş) | `runGuardedMutation` → `repo.addPost()` | AUTH_REQUIRED + WORKING |
| feed_screen | Composer "Vazgeç" | setState collapse | NO_OP-OK |
| feed_screen | Search icon header | `_noop()` | **NO_OP** |
| feed_screen | Profile avatar (header) | push `/profile` | ROUTE |
| feed_screen | Notifications icon | snackbar "yakında" | **SNACKBAR_ONLY** |
| feed_screen | Group highlight join CTA | `runGuardedMutation` → `repo.joinGroup()` | AUTH_REQUIRED + WORKING |
| feed_screen | "Tüm Gruplar" | go `/groups` | ROUTE |
| feed_post_card | Like (kalp) | callback → `repo.toggleLike()` | AUTH_REQUIRED + WORKING |
| feed_post_card | Save (bookmark) | callback → `repo.toggleSave()` | AUTH_REQUIRED + WORKING |
| feed_post_card | Comment | snackbar `feedActionCommentSnack` | **SNACKBAR_ONLY** |
| feed_post_card | Share | snackbar `feedActionShareSnack` | **SNACKBAR_ONLY** |
| feed_post_card | Tag tap (#) | snackbar `feedActionTagSnack` | **SNACKBAR_ONLY** |
| feed_post_card | Group highlight chip | push `/groups/{id}` | ROUTE |

## Groups

| Screen | Button | Action | Status |
|---|---|---|---|
| groups_list_screen | FAB "+" yeni grup | push `/groups/create` | ROUTE |
| groups_list_screen | Search bar | setState filter | NO_OP-OK (yerel filtre) |
| groups_list_screen | Category chip | setState filter | NO_OP-OK |
| groups_list_screen | Group kart | push `/groups/{id}` | ROUTE |
| groups_list_screen | Join CTA | `runGuardedMutation` → joinGroup | AUTH_REQUIRED + WORKING |
| group_create_screen | "Grubu Oluştur" | `runGuardedMutation` → createGroup | AUTH_REQUIRED + WORKING |
| group_detail_screen | Join / Leave | `runGuardedMutation` → join/leaveGroup | AUTH_REQUIRED + WORKING |
| group_detail_screen | Mesaj gönder | `runGuardedMutation` → postMessage | AUTH_REQUIRED + WORKING |

## Jobs

| Screen | Button | Action | Status |
|---|---|---|---|
| jobs_screen | "+" header | `AuthRequiredGuard.canWriteWithRef` + push `/worker/job-seek/new` | AUTH_REQUIRED |
| jobs_screen | "Usta Arıyor" segment | setState toggle (placeholder ekran) | NO_OP-OK |
| jobs_screen | "İş Arıyor" segment | setState toggle → real provider | WORKING |
| (İş Arıyor liste) | JobOpportunityCard "Başvur" | callback boş (`onApply` parent vermez) | **NO_OP** (V2 mesajlaşma) |

## Marketplace

| Screen | Button | Action | Status |
|---|---|---|---|
| marketplace_screen | (button yok) | sadece coming-soon kartı | **COMING_SOON** |

Bottom nav'dan kaldırıldı; `/market` deep link açılırsa coming-soon gösterir.

## Worker (Bireysel panel)

| Screen | Button | Action | Status |
|---|---|---|---|
| worker_profile_screen | Kaydet | `repo.upsertMyProfile()` (guarded) | AUTH_REQUIRED + WORKING |
| worker_experiences_screen | "+" yeni tecrübe | bottom sheet | NO_OP-OK (sheet açar) |
| worker_experiences_screen | Sil (kart üzerinde) | confirmDelete + `repo.deleteExperience` | AUTH_REQUIRED + WORKING |
| job_seek_posts_screen | "+" yeni ilan | push `/worker/job-seek/new` | ROUTE |
| job_seek_posts_screen | Edit kart | push `/worker/job-seek/{id}/edit` | ROUTE |
| job_seek_post_form_screen | Kaydet | `repo.upsertJobSeekPost` (guarded) | AUTH_REQUIRED + WORKING |
| job_seek_post_form_screen | Önizleme | dialog | NO_OP-OK |

## Bakery panel (Ticari)

| Screen | Button | Action | Status |
|---|---|---|---|
| bakery_panel_screen | Calendar header icon | `() {}` boş | **NO_OP** |
| bakery_panel_screen | "Reçeteler" kartı | push `/recipes` | ROUTE |
| bakery_panel_screen | "Üretim Gir" | push `/panel/production` | ROUTE |
| bakery_panel_screen | "Fire Gir" | push `/panel/waste` | ROUTE |
| bakery_panel_screen | "Gün Sonu" | push `/panel/end-of-day` | ROUTE |
| bakery_panel_screen | "Rapor Al" | push `/panel/report` | ROUTE |
| bakery_panel_screen | "Bayilerim" özet | push `/dealers` | ROUTE |
| recipes_list_screen | FAB "+" yeni reçete | push `/recipes/new` | ROUTE |
| recipes_list_screen | Reçete kart | push `/recipes/{id}` | ROUTE |
| recipe_detail_screen | Edit | push `/recipes/{id}/edit` | ROUTE |
| recipe_detail_screen | Public/private toggle | `repo.upsertRecipe(isPublic: …)` | AUTH_REQUIRED + WORKING |
| recipe_detail_screen | WhatsApp paylaş | `share_plus` | EXTERNAL |
| recipe_editor_screen | Kaydet | `repo.upsertRecipe` (guarded) | AUTH_REQUIRED + WORKING |
| calculator_screen | Hesapla | client-side `RecipeCalculator` | WORKING (offline) |
| production_entry_screen | Kaydet | `bakeryRepo.addProductionEntry` (guarded) | AUTH_REQUIRED + WORKING |
| waste_entry_screen | Kaydet | `bakeryRepo.addWasteEntry` (guarded) | AUTH_REQUIRED + WORKING |
| end_of_day_screen | Kaydet/özetle | bakery summary | WORKING |
| report_screen | PDF/Share | `pdf` + `share_plus` | EXTERNAL |

## Dealer (Bayi)

| Screen | Button | Action | Status |
|---|---|---|---|
| dealer_list_screen | "+" yeni bayi | push `/dealers/new` | ROUTE |
| dealer_list_screen | Search/Filter chips | setState | NO_OP-OK |
| dealer_list_screen | Bayi kart | push `/dealers/{id}` | ROUTE |
| add_dealer_screen | Kaydet | `dealerRepo.upsertDealer` (guarded) | AUTH_REQUIRED + WORKING |
| dealer_detail_screen | "Ürün Ver" chip | push `/dealers/{id}/delivery` | ROUTE |
| dealer_detail_screen | "İade Al" chip | push `/dealers/{id}/return` | ROUTE |
| dealer_detail_screen | "Ödeme Al" chip | push `/dealers/{id}/payment` | ROUTE |
| dealer_detail_screen | "Düzeltme" chip | push `/dealers/{id}/adjustment` | ROUTE |
| dealer_detail_screen | "Hesap Paylaş" chip | push `/dealers/{id}/share` | ROUTE |
| dealer_detail_screen | "Fiyat ekle" sheet | dealerRepo.addPrice (guarded) | AUTH_REQUIRED + WORKING |
| dealer_detail_screen | Not ekle | dealerRepo.addNote (guarded) | AUTH_REQUIRED + WORKING |
| dealer_delivery_form_screen | Kaydet | dealerRepo.createDelivery (guarded) | AUTH_REQUIRED + WORKING |
| dealer_payment_form_screen | Kaydet | dealerRepo.createTx(type:payment) | AUTH_REQUIRED + WORKING |
| dealer_return_form_screen | Kaydet | dealerRepo.createTx(type:return) | AUTH_REQUIRED + WORKING |
| dealer_adjustment_form_screen | Kaydet | dealerRepo.createTx(type:adjustment) | AUTH_REQUIRED + WORKING |
| dealer_share_screen | Metin kopyala | Clipboard | EXTERNAL |
| dealer_share_screen | WhatsApp paylaş | share_plus | EXTERNAL |
| dealer_share_screen | PDF oluştur | pdf + share_plus | EXTERNAL |
| wholesale_customers_screen | "+" yeni müşteri | push `/wholesale/customers/new` | ROUTE |

## Profile + Account

| Screen | Button | Action | Status |
|---|---|---|---|
| profile_screen | Hero / Stats / Public recipes section | display | — |
| profile_screen | Account list tiles (5 satır: "İşletme Bilgileri", "Ürünlerim", "Raporlarım", "E-posta", "Ayarlar") | `onTap: () {}` boş | **NO_OP × 5** |
| profile_screen | "Tüm reçetelerim" trailing | push `/recipes` | ROUTE |
| profile_screen | Public recipe row tap | push `/recipes/{id}` | ROUTE |
| profile_screen | **"Profilden Çık"** | signOut + setGuest(false) + go `/auth` | WORKING |
| profile_screen | **"Hesabımı Sil"** | 2-step confirm dialog + Edge Function | WORKING |

## Legal

| Screen | Button | Action | Status |
|---|---|---|---|
| terms_screen | (sadece okuma) | — | — |
| privacy_screen | (sadece okuma) | — | — |
| (login footer) | Terms link | push `/legal/terms` | ROUTE |
| (login footer) | Privacy link | push `/legal/privacy` | ROUTE |

---

## Özet (sahte / yarım buton listesi)

### NO_OP (gerçek tehlikeli)
1. `bakery_panel_screen` Calendar icon (header) — boş `() {}`
2. `feed_screen` Search icon (header) — `_noop()`
3. `profile_screen` Account list tiles × 5 (İşletme Bilgileri, Ürünlerim, Raporlarım, E-posta, Ayarlar) — boş `() {}`
4. **`jobs_screen` JobOpportunityCard "Başvur" CTA** — `onApply` parent vermez (V2 mesajlaşma yok)

### SNACKBAR_ONLY (dürüst ama kullanıcıya yapay)
5. `feed_screen` notifications icon — "yakında" snackbar
6. `feed_post_card` Comment / Share / Tag butonları — 3 snackbar (yorum tablosu hazır ama UI yok)

### COMING_SOON (dürüst placeholder)
7. `marketplace_screen` (tamamı)
8. `jobs_screen` "Usta Arıyor" segmenti (placeholder kart)

### EXTERNAL (paylaşım/clipboard)
9. recipe_detail / dealer_share / report — share_plus, pdf, Clipboard

### WORKING + AUTH_REQUIRED (defense-in-depth)
Tüm yazma yolları (post, like, save, group, message, recipe save, dealer CRUD, worker save, account delete) `runGuardedMutation` veya `AuthRequiredGuard.canWriteWithRef` arkasında. Guest deneyince `AuthRequiredSheet` açılır.

## Karar

- **Sahte/no-op (P1):** profile_screen account list 5 tile + bakery panel calendar + feed search → toplam 7 buton kullanıcıyı kandırma riskli. UI tıklanır ama hiçbir şey olmaz.
- **Snackbar-only (P1):** Feed comment / share / tag — yorum tablosu Supabase'de **var**, UI'da yok; "yakında" mesajı dürüst ama yorum sosyal akışın gerçek değeri için P1.
- **JobsCard Başvur (P2):** mesajlaşma backend yok → callback boş; V2 scope.
- **Marketplace coming-soon (kabul):** bottom nav'dan kaldırıldı; dürüst.
- **Diğer her şey ya WORKING ya ROUTE.**
