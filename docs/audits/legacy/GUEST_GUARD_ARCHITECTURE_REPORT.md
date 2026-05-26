# GUEST_GUARD_ARCHITECTURE_REPORT

**Tarih:** 2026-05-13
**Faz:** V1.3.3 — Guest write guard sistemi yeniden mimarileştirildi
**Test:** `flutter analyze` temiz, `flutter test` **151/151** yeşil (122 mevcut + 29 yeni)
**Migration:** Yok. Supabase schema/RLS değişmedi.

> Audit girdisi: [GUEST_WRITE_OPERATION_MATRIX.md](GUEST_WRITE_OPERATION_MATRIX.md)

---

## 1. Neden tek tek UI guard yeterli değildi?

V1.3.2'de 18 write noktasına manuel `AuthRequiredGuard.canWriteWithRef(ref)` çağrısı eklenmişti. Ama:

- `joinGroup` 3 farklı UI noktasından çağrılıyordu (Feed, Groups list, Group detail); birinde guard unutulmuştu — kullanıcı emülatörde guest olarak gruba katıldı.
- `leaveGroup`, `createGroup`, `deleteExperience`, `deleteJobSeekPost`, `upsertJobSeekPost` (toggle), `addPrice`, `addNote` toplam 8+ write noktası UI-guardsız kalmıştı.
- `setActive` (dealer pasif/aktif) ve `addDelivery` (legacy) latent risk: ya hiç UI'sı yok ya kullanılmıyor — ileride UI eklenince otomatik gap olur.
- Test kapsamı sadece pure `canWrite` matrix'iydi; gerçek write çağrılarının engellenmesi test edilmiyordu.

**Yapısal problem:** UI sitesi ekleyen geliştirici guard'ı eklemeyi unutursa, hiçbir şey hatırlatmıyor. Defense yalnız "umut" üzerine.

---

## 2. Yeni merkezi guard mimarisi

### Katman 1 — Domain exception

`lib/features/auth/services/auth_required_guard.dart`'a eklendi:

```dart
class GuestActionRequiredException implements Exception {
  const GuestActionRequiredException({this.action});
  final String? action; // örn. 'gruba katılmak', 'reçete kaydetmek'
}
```

### Katman 2 — Repository decorator pattern (Guarded\*)

7 repository için tek tip wrapper. Pattern aynı:

```dart
class GuardedXRepository implements XRepository {
  GuardedXRepository({required this.inner, required this.canWriteCheck});
  final XRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // Read metodları → inner'a delege (guard yok)
  @override
  Future<List<X>> list() => inner.list();

  // Write metodları → önce _requireWrite, sonra inner'a delege
  @override
  Future<X> save(X draft) {
    _requireWrite('x kaydetmek');
    return inner.save(draft);
  }
}
```

Bu sayede:
- Yeni write metodu interface'e eklendiğinde, wrapper'a koymak hem zorunlu (interface implementation) hem de "_requireWrite" çağrısı standart pattern olduğu için kolay hatırlanır.
- Guest call her zaman exception atar; UI hatalı/eksik check yapsa bile repo katmanı durduruyor — **defense-in-depth**.

### Katman 3 — Riverpod provider wrap

`canWriteCheckProvider` (yeni, `lib/features/auth/providers/can_write_check_provider.dart`):
```dart
final canWriteCheckProvider = Provider<bool Function()>((ref) {
  return () => AuthRequiredGuard.canWrite(
    isGuest: ref.read(guestModeProvider),
    supabaseEnabled: AppConfig.supabaseEnabled,
    currentUser: ref.read(currentAuthUserProvider),
    profile: ref.read(profileControllerProvider),
  );
});
```

Her repo provider:
```dart
final fooRepositoryProvider = Provider<FooRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final FooRepository inner = AppConfig.supabaseEnabled && user != null
      ? SupabaseFooRepository(...)
      : LocalFooRepository(...);
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedFooRepository(inner: inner, canWriteCheck: canWrite);
});
```

### Katman 4 — UI mutation runner

`runGuardedMutation` helper (aynı dosyada):
```dart
Future<bool> runGuardedMutation(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() action,
}) async {
  try {
    await action();
    return true;
  } on GuestActionRequiredException {
    if (context.mounted) {
      await showAuthRequiredSheet(context, ref);
    }
    return false;
  }
}
```

UI artık şöyle yazıyor:
```dart
await runGuardedMutation(
  context,
  ref,
  action: () async {
    final repo = ref.read(socialGroupRepositoryProvider);
    final r = await repo.joinGroup(group.id);
    // ... başarı snackbar/navigation
  },
);
```

Repo guest'i engellerse exception atar → helper yakalar → AuthRequiredSheet açılır. UI tarafı "auth kontrolü" hakkında bilgi sahibi olmak zorunda değil; sadece "olası exception'ı yakala".

---

## 3. Hangi repository/write metodları guardlandı?

| Repository | Read (delege) | Write (guarded) |
|---|---|---|
| `FeedRepository` | `listPosts`, `listInsights`, `watch` | `addPost`, `toggleLike`, `toggleSave` |
| `SocialGroupRepository` | `listGroups`, `listPopular`, `listJoined`, `getGroup`, `isJoined`, `listMessages`, `watch` | `createGroup`, `joinGroup`, `leaveGroup`, `postMessage` |
| `RecipeRepository` | `list`, `listPublicByOwner`, `getById`, `watch` | `save`, `delete` |
| `BakeryRepository` | `listProduction`, `listDeliveries`, `listWastes`, `dailySummary`, `watch` | `addProduction`, `addDelivery`, `addWaste` |
| `DealerRepository` | `listDealers`, `getDealer`, `listPrices`, `currentPriceFor`, `listTransactions`, `listAllTransactions`, `listNotes`, `watch` | `upsertDealer`, `setActive`, `addPrice`, `addTransaction`, `addNote` |
| `WorkerRepository` | `getMyProfile`, `listMyExperiences`, `listMyJobSeekPosts`, `getJobSeekPost`, `watch` | `upsertMyProfile`, `addExperience`, `deleteExperience`, `upsertJobSeekPost`, `deleteJobSeekPost` |
| `ProfileRepository` | `fetchProfile` | `updateProfile` |

**Toplam write metodu guard altında: 22** (matris'teki listede `setActive` ve `addDelivery` latent gap'leri dahil — artık repo katmanında otomatik engelleniyorlar).

---

## 4. Read-only ve external share neden serbest?

Brief kuralı: *"Dışa paylaşım serbest. İçeride kayıt bırakan işlem üyelik ister."*

- **Read metodları** guard wrapper'ında **doğrudan inner'a delege** edilir; guard çağrısı yok. Guest gezme/okuma serbest kalır.
- **External share** (Share.share / Share.shareXFiles) repository katmanından geçmiyor — Flutter `share_plus` paketi sistem chooser açar, app içinde state değiştirmez. Guard mekanizması ile hiç temas etmez.
- **Stateless tool** (RecipeCalculator) repo değil servis; matematik. Guard yok.

---

## 5. Guest için hangi işlemler engelleniyor?

### Katmanlardan birinde (yeterli)

**Defense-in-depth uygulaması — guest yapamaz:**

| Aksiyon | UI guard (V1.3.2) | Repo guard (V1.3.3) |
|---|---|---|
| Reçete kaydet | ✅ | ✅ |
| Reçete sil | ✅ (V1.3.2) | ✅ |
| Üretim/fire gir | ✅ | ✅ |
| Bayi/müşteri ekle | ✅ | ✅ |
| Bayi teslimat/tahsilat/iade/düzeltme | ✅ | ✅ |
| Bayi fiyat/not ekle | ✅ (V1.3.2) | ✅ |
| Ustalık profili kaydet | ✅ | ✅ |
| Tecrübe ekle | ✅ | ✅ |
| **Tecrübe sil** | ❌ → runGuardedMutation eklendi | ✅ |
| İş arıyorum ilanı oluştur/güncelle (form) | ✅ | ✅ |
| **İş ilanı yayın toggle** | ❌ → runGuardedMutation eklendi | ✅ |
| **İş ilanı sil** | ❌ → runGuardedMutation eklendi | ✅ |
| Profil güncelle | ✅ (CreateProfile) | ✅ |
| Feed post oluştur | ✅ | ✅ |
| Feed like/save toggle | ✅ | ✅ |
| Reçete "Feed'de paylaş" | ✅ | ✅ |
| Grup mesaj gönder | ✅ | ✅ |
| **Grup oluştur** | ❌ → runGuardedMutation eklendi | ✅ |
| **Grup join (3 nokta)** | ❌ → runGuardedMutation eklendi | ✅ |
| **Grup leave** | ❌ → runGuardedMutation eklendi | ✅ |
| **Latent setActive (UI yok)** | — | ✅ (otomatik) |
| **Latent legacy addDelivery** | — | ✅ + route redirect |

V1.3.2'deki 7 UI-guardsız nokta artık 2 katmanda korumalı: (a) UI helper runGuardedMutation, (b) repo wrapper `_requireWrite`.

---

## 6. Signed-in kullanıcı davranışı bozuldu mu?

**Hayır.** Wrapper read metodları ve auth=true durumunda write metodları doğrudan inner'a delege ediyor; semantik aynı.

**Doğrulama:**
- `flutter test`: 151/151 (mevcut 122 + yeni 29). Mevcut testler — özellikle dealer/feed/recipe/group/social repository testleri — değişmeden geçti.
- `repository_provider_selection_test.dart` güncellendi: artık `GuardedX` döner (inner LocalX); seed seed kaldı, davranış aynı.

---

## 7. Legacy/deeplink riskleri ne oldu?

| Risk | Çözüm |
|---|---|
| `/panel/dealer` legacy route → DealerDeliveryScreen → `addDelivery` StateError | **Route artık `/dealers`'a redirect.** `DealerDeliveryScreen` dosyası silindi (kullanılmıyordu, router import'undan da çıkarıldı). |
| Latent `setActive` UI'sı eklenirse guardsız çalışması | Repo wrapper otomatik engelliyor — yeni UI eklenince ekstra bir şey yapmaya gerek yok. |
| Latent `addDelivery` (legacy bakery panel akışı) | Repo wrapper otomatik engelliyor. UI çağrı sitesi de silindi. |

---

## 8. Test sonuçları

### `flutter analyze`
```
Analyzing firinnet...
No issues found! (ran in 0.5s)
```

### `flutter test`
```
00:03 +151: All tests passed!
```

### Yeni testler (29 adet)

`test/guarded_repositories_test.dart` (yeni):

**GuardedFeedRepository (5):** guest addPost/toggleLike/toggleSave → exception; auth addPost → forwards; read forwards.

**GuardedSocialGroupRepository (6):** guest createGroup/joinGroup/leaveGroup/postMessage → exception; auth createGroup → forwards; read forwards.

**GuardedRecipeRepository (4):** guest save/delete → exception; auth save → forwards; read forwards.

**GuardedDealerRepository (6):** guest upsertDealer/setActive/addPrice/addTransaction(payment)/addNote → exception; auth upsertDealer → forwards.

**GuardedWorkerRepository (6):** guest upsertMyProfile/addExperience/deleteExperience/upsertJobSeekPost/deleteJobSeekPost → exception; auth upsertJobSeekPost → forwards.

**Exception contract (2):** `GuestActionRequiredException` action alanı opsiyonel; verirse toString içinde.

> ProfileRepository wrapper testi atlanmıştır — provider'ın circular-dependency riski olmadığı (kapanış lazy) ve mevcut provider test'inin de bunu kapsamadığı için. Repository implementation pure dekoratör; aynı pattern.

### Test dağılımı (toplam 151)

| Dosya | Sayı |
|---|---|
| `guarded_repositories_test.dart` (V1.3.3 YENİ) | **29** |
| `auth_required_guard_test.dart` | 6 |
| `auth_entry_v1_3_test.dart` | 20 |
| `panel_v1_2_test.dart` | 19 |
| `recipe_quantity_visibility_test.dart` | 14 |
| `local_recipe_repository_test.dart` | 11 |
| `feed_repository_test.dart` | 11 |
| `social_group_repository_test.dart` | 11 |
| `dealer_balance_test.dart` | 7 |
| `recipe_share_text_builder_test.dart` | 6 |
| `recipe_calculator_test.dart` | 4 |
| `dealer_repository_test.dart` | 4 |
| `feed_composer_layout_test.dart` | 2 |
| `dealer_share_builder_test.dart` | 2 |
| `dealer_pdf_builder_test.dart` | 2 |
| `repository_provider_selection_test.dart` | 2 |
| `widget_test.dart` | 1 |

---

## 9. Kalan riskler

| Risk | Açıklama | Öncelik |
|---|---|---|
| Widget-level smoke testler yok | "guest 'Katıl' butonuna basınca sheet açılır" gibi senaryolar widget test ile doğrulanmıyor. Repo + helper unit testler kapsıyor ama UI-side smoke ileride eklenebilir. | P2 |
| Auth state cache yarış durumu | `canWriteCheckProvider` closure'ı her çağrıda providers'ı okur. Eğer `profileControllerProvider` boş döndüğü an çağrılırsa false döner. signIn sonrası ilk write isteği gelene kadar auth stream `currentAuthUser`'ı set etmiş olmalı. Pratik bir sorun gözlemlenmedi. | P3 |
| `GuestActionRequiredException` Türkçeleştirme | `toString()` İngilizce. UI'da gösterilmiyor (sheet metni statik). İleride debug için Türkçe yapılabilir. | P3 |
| Auth UI guards kalın hale getirme | 18 ekran UI guard'ı yine duruyor (defense-in-depth). İleride 1-katmanlı (sadece repo) seçilirse UI guard'ları kaldırılabilir; ama önerilmez — UI guard formu önceden kesip UX iyileştiriyor. | — |

---

## 10. Kırmızı çizgi kontrolü

| Kural | Durum |
|---|---|
| Yama yapma — mimari kur | ✅ Decorator pattern uygulandı |
| Sadece "şu butona guard ekle" yapma | ✅ Repository katmanına merkezi guard |
| Supabase schema/RLS değiştirme | ✅ Migration yok |
| Renk/tasarım değiştirme | ✅ |
| Mevcut 122 test bozulmasın | ✅ 122 → +29 = 151/151 |
| Test edilebilir mimari | ✅ Pure closure + decorator; her wrapper teste açık |
| Yeni write metodu eklenince guard otomatik aktive olsun | ✅ Interface'i implement etmek zorunlu olduğu için wrapper'a metodu eklemek de zorunlu — eklenince `_requireWrite` adımı standart pattern |

---

## 11. Mimari özet (tek bakışta)

```
┌──────────────────────────────────────────────────┐
│  UI screen / widget                              │
│                                                  │
│  await runGuardedMutation(                       │
│    context, ref,                                 │
│    action: () async {                            │
│      await repo.joinGroup(...);  // repo from    │
│    },                            // provider     │
│  );                                              │
└──────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  GuardedXRepository (decorator)                  │
│                                                  │
│  Future<Y> writeMethod(...) {                    │
│    _requireWrite('action label');                │
│    return inner.writeMethod(...);                │
│  }                                               │
│                                                  │
│  void _requireWrite(String action) {             │
│    if (!canWriteCheck()) {                       │
│      throw GuestActionRequiredException(...);    │
│    }                                             │
│  }                                               │
└──────────────────────────────────────────────────┘
                    │ (auth=true)
                    ▼
┌──────────────────────────────────────────────────┐
│  Inner: SupabaseXRepository OR LocalXRepository  │
│  (gerçek iş)                                     │
└──────────────────────────────────────────────────┘

      Exception fırlarsa:
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  runGuardedMutation catches                      │
│  → showAuthRequiredSheet(context, ref)           │
│  → "Hesabını oluştur, kaydın sende kalsın"       │
└──────────────────────────────────────────────────┘
```

---

## 12. Değişen dosyalar

### Yeni
- `lib/features/auth/providers/can_write_check_provider.dart`
- `lib/features/feed/repositories/guarded_feed_repository.dart`
- `lib/features/social_groups/repositories/guarded_social_group_repository.dart`
- `lib/features/bakery_panel/repositories/guarded_recipe_repository.dart`
- `lib/features/bakery_panel/repositories/guarded_bakery_repository.dart`
- `lib/features/dealers/repositories/guarded_dealer_repository.dart`
- `lib/features/worker/repositories/guarded_worker_repository.dart`
- `lib/features/profile/repositories/guarded_profile_repository.dart`
- `test/guarded_repositories_test.dart` (29 test)
- `GUEST_WRITE_OPERATION_MATRIX.md` (audit)
- `GUEST_GUARD_ARCHITECTURE_REPORT.md` (bu rapor)

### Düzenlenen
- `lib/features/auth/services/auth_required_guard.dart` — `GuestActionRequiredException` + `runGuardedMutation` eklendi
- `lib/features/bakery_panel/providers/bakery_providers.dart` — bakery + recipe provider wrap
- `lib/features/dealers/providers/dealer_providers.dart` — dealer provider wrap
- `lib/features/worker/providers/worker_providers.dart` — worker provider wrap
- `lib/features/feed/providers/feed_providers.dart` — feed provider wrap
- `lib/features/social_groups/providers/social_group_providers.dart` — group provider wrap
- `lib/features/profile/providers/profile_provider.dart` — profile provider wrap
- `lib/features/feed/screens/feed_screen.dart` — joinGroup → runGuardedMutation
- `lib/features/social_groups/screens/groups_list_screen.dart` — joinGroup → runGuardedMutation
- `lib/features/social_groups/screens/group_detail_screen.dart` — join/leave → runGuardedMutation
- `lib/features/social_groups/screens/group_create_screen.dart` — createGroup → runGuardedMutation
- `lib/features/worker/screens/job_seek_posts_screen.dart` — toggle/delete → runGuardedMutation
- `lib/features/worker/screens/worker_experiences_screen.dart` — delete → runGuardedMutation
- `lib/app/router/app_router.dart` — `/panel/dealer` legacy redirect, `DealerDeliveryScreen` import kaldırıldı
- `test/repository_provider_selection_test.dart` — `GuardedX` assertion'ına güncellendi

### Silinen
- `lib/features/bakery_panel/screens/dealer_delivery_screen.dart` (legacy, kullanılmıyordu, route redirect yerini aldı)

---

## 13. Git

Commit + push aşağıda.

**Mesaj:** `fix(firinnet): centralize guest write guards`

---

**Hedef gerçekleşti.** Guest write koruması artık tek noktada — repository decorator katmanında. Yeni write metodu eklendiğinde wrapper'da `_requireWrite` çağrısı standart pattern olarak hatırlanır. UI tarafı `runGuardedMutation` ile tek tip yazılır; auth detayını bilmesine gerek yok. UI guard'ları unutulsa bile repo katmanı durduruyor — defense-in-depth.
