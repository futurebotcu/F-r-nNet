# Build Runbook — FırınNet Flutter

Bu döküman, **Supabase aktif** APK/AAB build'leri için tek otoriter referanstır.

## Neden Bu Runbook Var?

Flutter `String.fromEnvironment('SUPABASE_URL')` **compile-time** sabit okur. `.env.local` dosyası otomatik okunmaz. Eğer `flutter build apk` veya `flutter run` çağrısına `--dart-define=SUPABASE_URL=...` ve `--dart-define=SUPABASE_ANON_KEY=...` geçilmezse:

- APK içine boş string derlenir.
- `AppConfig.supabaseEnabled = false` döner.
- Uygulama Supabase'e **hiç bağlanmaz**; auth ekranı "Canlı giriş kapalı" gösterir, repository'ler local fallback'e düşer.

Bu **kod/Supabase senkron hatası değil, build-time config eksikliğidir**. Aşağıdaki scriptler `.env.local`'i okur ve dart-define'ları doğru geçirir.

## Doğru Komutlar (Windows / PowerShell)

| Amaç | Komut |
|---|---|
| Cihaz/emulator'de Supabase modda `flutter run` | `.\scripts\run_supabase_android.ps1 -DeviceId <id>` |
| Debug APK build (sideload / 2-hesap test) | `.\scripts\build_debug_supabase_apk.ps1` |
| Release AAB build (Play Store) | `.\scripts\build_release_supabase_aab.ps1` |

Hepsi `.env.local`'i okur, **anahtarları echo etmez**, eksikse fail-fast verir.

## Yanlış (Plain) Komutlar — Kullanma

```text
flutter run                         # ← dart-define yok → Supabase OFF
flutter build apk                   # ← dart-define yok → Supabase OFF + release keystore eksik fail
flutter build apk --debug           # ← dart-define yok → Supabase OFF (sessiz)
flutter build appbundle --release   # ← dart-define yok + keystore yoksa fail
```

Bu komutlar APK üretebilir ama Supabase devre dışı APK çıkarır. Repo'da olduğu süre boyunca **plain `flutter build`/`flutter run` kullanılmamalıdır**.

## .env.local Kurulumu (İlk Kez)

```text
1. .env.local.example dosyasını .env.local olarak kopyala.
2. SUPABASE_URL ve SUPABASE_ANON_KEY değerlerini doldur.
   - Supabase Dashboard → Project Settings → API → "Project URL" + "anon public" key.
3. .env.local repo'ya commit edilmez (.gitignore koruyor).
```

## Sağlık Kontrolü (APK Açıldıktan Sonra)

| Belirti | Tanı |
|---|---|
| Auth ekranında **"Canlı giriş kapalı. Kayıtsız devam edebilirsin."** görünüyor | Build dart-define eksik. Plain `flutter build` ile derlenmiş. Doğru script'le yeniden build et. |
| Google butonu disabled (`disabledBackgroundColor`) | Aynısı — `supabaseEnabled = false`. |
| Auth açılıyor ama "Onboarding" ekranına düşüyor | Yine dart-define eksik (mock/local mode); bkz. `AUTH_ROUTER_ENTRY_AUDIT.md`. |
| Auth açılıyor, Google tıkla → OAuth browser açılıyor → callback çalışmıyor | dart-define **var**; problem `firinnet://auth-callback` deep-link / Supabase redirect URL config. Bkz. `GOOGLE_APPLE_AUTH_V1_REPORT.md`. |
| `flutter build appbundle --release` "Release signing için..." hatası | Keystore yok. `ANDROID_SIGNING_RUNBOOK.md` adımlarını izle. |

## Release AAB (Play Store) İçin Ek Gereksinim

Debug APK Flutter debug keystore'uyla imzalanır; Play Store kabul etmez. Release AAB için:

1. Keystore üret + `android/key.properties` doldur (`ANDROID_SIGNING_RUNBOOK.md`).
2. `.\scripts\build_release_supabase_aab.ps1` çalıştır.

Script `.env.local` + `key.properties` ikisini de kontrol eder; biri eksikse fail-fast.

## Güvenlik Notları

- **`.env.local`** repo dışı kalır (`.gitignore: .env.*`).
- Scriptler anahtarların **varlık/yokluk** durumunu yazdırır, **değerini yazmaz**.
- `SUPABASE_ANON_KEY` public client anahtarıdır — APK'ya derlenmesi normal; RLS sunucu tarafında koruyor.
- **Service-role key veya PAT** asla APK'ya derlenmez, scriptlere parametre olarak geçmez, `.env.local`'e yazılmaz. (Bunlar yalnız MCP env'inde / sunucu tarafında kullanılır.)

## Script Konumları

```text
scripts/run_supabase_android.ps1          # flutter run (cihazda live dev)
scripts/build_debug_supabase_apk.ps1      # debug APK (sideload)
scripts/build_release_supabase_aab.ps1    # release AAB (Play Store)
```

Yeni script eklenirse aynı pattern: `.env.local` oku → fail-fast → no echo → `--dart-define` pass.
