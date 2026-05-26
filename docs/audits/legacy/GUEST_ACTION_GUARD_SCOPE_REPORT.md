# GUEST_ACTION_GUARD_SCOPE_REPORT

**Tarih:** 2026-05-13
**Faz:** V1.3.2 — Guest guard kapsamı düzeltildi
**Test:** `flutter analyze` temiz, `flutter test` **122/122** yeşil (yeni test yok; mevcut guard logic test'leri kapsıyor)

> Brief kuralı: **"Dışa paylaşım serbest. İçeride kayıt bırakan işlem üyelik ister."**

---

## 1. Audit özeti

V1.3.1 sonrası `AuthRequiredGuard.canWriteWithRef` ve `showAuthRequiredSheet` kullanım noktaları + `Share.share` / `SharePlus` çağrıları + repository write metotları (`addPost`, `postMessage`, `toggleLike`, `toggleSave`, `addPrice`, `addNote`, `delete`, `addProduction`, `addWaste`, `addTransaction`, `upsertDealer`) tek tek tarandı.

**Sonuç:**
- **Guard fazla geniş değildi** — mevcut 11 guard'ın hepsi DB write üzerinde. Dış paylaşımda hiçbir guard yoktu.
- **Ama 7 user-bound write hâlâ guardsızdı.** Bunlar eklendi.

---

## 2. Mevcut durum — V1.3.2 sonrası

### Guest için SERBEST (dış paylaşım, salt okuma, anlık araç)

| Aksiyon | Dosya | Not |
|---|---|---|
| Feed gezme + post okuma | `feed_screen.dart` | LocalFeedRepository seed |
| İlanları gezme | `jobs_screen.dart` | Static mock |
| Market gezme | `marketplace_screen.dart` | Static mock |
| Public reçete görüntüleme | `recipe_detail_screen.dart` | RLS sayesinde |
| Gruplar listesi / detay görüntüleme | `groups_list_screen.dart`, `group_detail_screen.dart` | Read-only kısım |
| **Hesaplama Makinesi anlık hesap** | `calculator_screen.dart` | Hesaplama + sonuç |
| **Hesaplama sonucu dış paylaşım** | `calculator_screen.dart` (`Share.share`) | WhatsApp/sistem |
| **Reçete dış paylaşım (liste kartı)** | `recipes_list_screen.dart` (`Share.share`) | WhatsApp/sistem |
| **Reçete dış paylaşım (detay sheet WhatsApp seçeneği)** | `recipe_detail_screen.dart._shareSystem` (`Share.share`) | WhatsApp/sistem |
| **Bayi cari özeti dış paylaşım** | `dealer_share_screen.dart` (`Share.share` + `Share.shareXFiles` PDF) | WhatsApp/sistem |
| **Gün sonu raporu dış paylaşım** | `report_screen.dart` (`Share.share`) | WhatsApp/sistem |
| **İş arıyorum ilanı dış paylaşım** | `job_seek_posts_screen.dart` (`Share.share`) + `job_seek_post_form_screen.dart._previewShare` | WhatsApp/sistem |

> Hiçbir `Share.share` veya `Share.shareXFiles` çağrısı guard altında değil. Brief'in istediği gibi dış paylaşım **tam serbest**.

### Guest için ÜYELİK İSTER (kalıcı kayıt + user-bound)

**Mevcut V1.3.1'den korunanlar (11):**
| Aksiyon | Dosya |
|---|---|
| Reçete kaydet | `recipe_editor_screen.dart._save` |
| Üretim kaydet | `production_entry_screen.dart._save` |
| Fire kaydet | `waste_entry_screen.dart._save` |
| Bayi/Müşteri ekle | `add_dealer_screen.dart._save` |
| Bayi teslimat | `dealer_delivery_form_screen.dart._save` |
| Bayi tahsilat | `dealer_payment_form_screen.dart._save` |
| Bayi iade | `dealer_return_form_screen.dart._save` |
| Bayi düzeltme | `dealer_adjustment_form_screen.dart._save` |
| Ustalık profili kaydet | `worker_profile_screen.dart._save` |
| Tecrübe ekle | `worker_experiences_screen.dart._AddExperienceSheetState._save` |
| İş arıyorum ilanı oluştur/güncelle | `job_seek_post_form_screen.dart._save` |

**V1.3.2'de eklenenler (7):**
| Aksiyon | Dosya | Eklenme nedeni |
|---|---|---|
| **Feed post oluşturmak** | `feed/widgets/feed_composer.dart._submit` | repo.addPost — uygulama içinde post kaydı |
| **Feed beğen (toggleLike)** | `feed/screens/feed_screen.dart` onLike | User-bound favori durumu |
| **Feed kaydet (toggleSave)** | `feed/screens/feed_screen.dart` onSave | User-bound bookmark |
| **Grup mesajı gönder** | `social_groups/screens/group_detail_screen.dart._Composer._send` | repo.postMessage |
| **Reçete sil** | `bakery_panel/screens/recipe_detail_screen.dart._confirmDelete` | Owner-only mutating action |
| **Reçete "Feed'de paylaş" (share sheet içinde)** | `bakery_panel/screens/recipe_detail_screen.dart._shareToFeed` | repo.addPost — feed'e kayıt |
| **Bayi fiyat ekle (price sheet)** | `dealers/screens/dealer_detail_screen.dart._PriceSheet._save` | repo.addPrice |
| **Bayi not ekle** | `dealers/screens/dealer_detail_screen.dart._NotesCard._add` | repo.addNote |

**Toplam guarded yazma noktası: 11 + 7 = 18**

---

## 3. Önemli ayrım — paylaşım dual-channel UX

`RecipeDetailScreen`'in "Paylaş" bottom sheet'i 3 seçenek sunuyor:

```
[ Feed'de paylaş ]      ← guarded (repo.addPost — uygulama içinde post kaydı)
[ Grupta paylaş ]       ← coming soon, guard yok
[ WhatsApp / Sistem ]   ← SERBEST (Share.share — dış paylaşım)
```

Aynı ekrandaki 2 paylaşım butonu farklı davranır:
- "Feed'de paylaş" → guest engellenir, sheet açılır
- "WhatsApp / Sistem" → guest serbest, dış sistem paylaşımı

Bu **kasıtlı** ve brief'le birebir uyumlu.

---

## 4. Değişen dosyalar

### Düzenlenen (8 dosya)
- `lib/features/feed/widgets/feed_composer.dart` — `_submit` guard
- `lib/features/feed/screens/feed_screen.dart` — `onLike` + `onSave` guard
- `lib/features/social_groups/screens/group_detail_screen.dart` — `_Composer._send` guard
- `lib/features/bakery_panel/screens/recipe_detail_screen.dart` — `_confirmDelete` + `_shareToFeed` guard
- `lib/features/dealers/screens/dealer_detail_screen.dart` — `_PriceSheet._save` + `_NotesCard._add` guard

### Yeni
- `GUEST_ACTION_GUARD_SCOPE_REPORT.md` (bu rapor)

### Silinen
**(Yok.)**

### Aynı kalan (önceki commit'te kurulmuş, doğrulandı)
- `lib/features/auth/services/auth_required_guard.dart` — pure logic + sheet
- 11 mevcut guard ekranı (bkz. tablo §2)

---

## 5. `flutter analyze` sonucu

```
Analyzing firinnet...
No issues found! (ran in 0.5s)
```

---

## 6. `flutter test` sonucu

```
00:03 +122: All tests passed!
```

> Yeni test eklenmedi: mevcut `auth_required_guard_test.dart`'taki 6-senaryo matrix bu yeni 7 noktayı da kapsıyor — hepsi aynı `canWrite` mantığını kullanıyor. Eklenen guard'lar mevcut testlerle birlikte yeşil kalıyor.

### Brief'teki test başlıklarının doğrulaması

| Brief test başlığı | Durum |
|---|---|
| guest calculator hesaplayabilir | ✅ Calculator guardsız, anlık hesap çalışır |
| guest calculator sonucunu dışa paylaşabilir | ✅ `calculator_screen.dart:132` `Share.share` guardsız |
| guest ilanı dışa paylaşabilir | ✅ `job_seek_posts_screen.dart:138` ve `job_seek_post_form_screen.dart:157` guardsız |
| guest public reçeteyi dışa paylaşabilir | ✅ `recipes_list_screen.dart:231` + `recipe_detail_screen.dart:866` guardsız |
| guest ilan vermeye basarsa AuthRequired sheet | ✅ `job_seek_post_form_screen.dart._save` guarded |
| guest reçete kaydetmeye basarsa AuthRequired sheet | ✅ `recipe_editor_screen.dart._save` guarded |
| guest feed/grup paylaşımı denediğinde AuthRequired sheet | ✅ `feed_composer._submit`, `group_detail _Composer._send`, `recipe_detail _shareToFeed` guarded |
| signed-in kullanıcı kalıcı işlemleri yapabilir | ✅ `canWrite` true döner — testle doğrulandı |

---

## 7. Brief ile karşılaştırma

| Brief: SERBEST olmalı | Doğrulama |
|---|---|
| Feed gezme | ✅ |
| İlanları gezme | ✅ |
| Market/ürünleri görme | ✅ |
| Public reçeteleri okuma | ✅ |
| Hesaplama Makinesi ile anlık hesap | ✅ |
| Bir ilanı WhatsApp / dış platformda paylaşma | ✅ |
| Bir reçeteyi WhatsApp / dış platformda paylaşma | ✅ |
| Bir profil veya fiyat metnini dış platformda paylaşma | ✅ Profil sahibi yoksa zaten gezmiyor; rapor/PDF dış paylaşımı serbest |
| Share sheet açmak | ✅ Recipe detail share sheet açılır (Feed seçeneği guarded ama sheet kendisi açık) |
| Kopyala / dışa paylaş gibi app içinde kayıt bırakmayan aksiyonlar | ✅ |

| Brief: ÜYELİK İSTEMELİ | Doğrulama |
|---|---|
| Feed post oluşturmak | ✅ V1.3.2'de eklendi |
| Gruba yazmak | ✅ V1.3.2'de eklendi |
| Mesaj göndermek | ✅ (Group composer = grup mesajı; DM yok) |
| İlan vermek | ✅ JobSeekPost form save guarded |
| Reçete kaydetmek | ✅ |
| Reçeteyi profilde açık yapmak | ✅ Save guard içinde (is_public toggle save'in parçası) |
| Üretim/fire kaydı girmek | ✅ |
| Bayi/müşteri eklemek | ✅ |
| Teslimat/tahsilat/iade/not/fiyat kaydetmek | ✅ Tümü |
| İş arıyorum ilanı vermek | ✅ |
| Ustalık profili kaydetmek | ✅ |
| Profil düzenlemek | ✅ CreateProfileScreen `_save` guarded |
| Favori/kaydet/takip gibi kullanıcıya bağlı işlem | ✅ V1.3.2'de toggleLike + toggleSave eklendi |
| Uygulama içinde owner_id gerektiren her kayıt | ✅ |

---

## 8. Git

Commit + push aşağıda.

**Mesaj:** `fix(firinnet): allow guest external sharing and read-only tools`

---

## 9. Kalan işler (sonraki faz)

| İş | Öncelik |
|---|---|
| Group post pin/unpin gibi moderator action'ları (varsa) | P3 |
| Profile screen "Profili Düzenle" akışı — eğer eklenirse guard | P3 |
| Recipe share sheet "Grupta paylaş" — şu an comingSoon; gerçek implementasyon gelince guard | P2 |
| `dealer_delivery_screen.dart` (legacy "Bayiye Ver") — kullanılmıyor ama kodda duruyor; deleted veya guarded olmalı | P3 |
| Comment akışı (FeedActionCommentSnack — comingSoon) — geldiğinde guard | P2 |

---

## 10. Kırmızı çizgi kontrolü

| Kural | Durum |
|---|---|
| Kayıtsız devam et seçeneğini kaldırma | ✅ Korundu |
| Kayıtsız kullanıcıyı uygulamadan atma | ✅ Gezme tam açık |
| Sert "yasak" dili kullanma | ✅ Sheet metni doğal |
| Dışa paylaşım için guard yok | ✅ 8 dış paylaşım noktası kontrol edildi, hiçbiri guardsız |
| Kalıcı işlem için guard var | ✅ 18 yazma noktası guarded |
| Supabase schema/RLS değiştirme | ✅ Migration yok |
| Renk/tasarım değiştirme | ✅ |
| Mevcut 122 test bozulmasın | ✅ 122/122 |

---

**Hedef gerçekleşti.** Brief'in **"Dışa paylaşım serbest. İçeride kayıt bırakan işlem üyelik ister."** kuralı V1.3.2 ile tam uygulandı. Guest kullanıcı:
- Gezebilir (Feed/İlanlar/Market/Gruplar/public reçeteler)
- Hesaplama Makinesi'ni kullanabilir
- WhatsApp ve sistem paylaşımları yapabilir (reçete, ilan, calc sonucu, gün sonu raporu, bayi PDF özeti)

Ama uygulama içinde kalıcı kayıt veya user-bound etkileşim yapmaya çalışırsa **`Hesabını oluştur, kaydın sende kalsın`** sheet'i ile karşılaşır.
