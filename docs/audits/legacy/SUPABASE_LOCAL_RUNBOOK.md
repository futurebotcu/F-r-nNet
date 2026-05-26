# FırınNet — Supabase Local Dev Runbook

Local geliştirme/QA için SUPABASE_URL ve SUPABASE_ANON_KEY'i her seferinde elle yazmak yerine `.env.local` + scripts kullanırız.

## İlk kurulum (bir kerelik)

1. `.env.local.example` dosyasını `.env.local` olarak kopyalayın:
   ```powershell
   Copy-Item .env.local.example .env.local
   ```
2. Supabase Dashboard → FırınNet projesi (`sjeqwiqgwzagengdukye`) → **Project Settings → API**:
   - `URL` (örn. `https://sjeqwiqgwzagengdukye.supabase.co`) → `.env.local` içine `SUPABASE_URL=` satırına yapıştır.
   - `anon` veya `publishable` key → `.env.local` içine `SUPABASE_ANON_KEY=` satırına yapıştır.
3. **Admin/yönetici anahtarı (`service_role`) ASLA bu dosyaya koymayın.** O anahtar yalnız sunucu-tarafı işler içindir; mobile app açar açmaz secret çıkar.

`.env.local` `.gitignore` tarafından dışlanmıştır; commit/push'e girmez. `.env.local.example` ise repo'da kalır.

## Günlük kullanım

### Windows desktop'ta hızlı smoke

```powershell
.\scripts\run_supabase_windows.ps1
```

Script:
- `.env.local`'i okur (anahtarları konsola yazdırmadan).
- Boş veya eksikse açık hata mesajıyla durur.
- `flutter run -d windows --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` çağırır.

### Android cihaz / emulator

```powershell
.\scripts\run_supabase_android.ps1 -DeviceId emulator-5554
```

Cihaz ID'sini bilmiyorsanız parametresiz çağırın — script `flutter devices` çıktısını gösterir:

```powershell
.\scripts\run_supabase_android.ps1
```

### Release AAB build (Play Console için)

```powershell
.\scripts\build_release_supabase_aab.ps1
```

> ⚠️ Android release signing config (`android/key.properties` + `signingConfig`) henüz yapılmadıysa build hata verebilir veya debug imzasıyla çıkar. Bu durumda **P0-4 (Android release imzası)** maddesi çözülmeli — ayrı PR.

## Güvenlik özeti

- `.env.local` git'e girmez (`.gitignore` → `.env.*` dışlama, `!.env.local.example` istisnası).
- Scriptler değerleri konsola yazdırmaz; sadece `SUPABASE_URL present: yes` / `SUPABASE_ANON_KEY present: yes` ile var/yok bildirir.
- Scriptler `--dart-define` ile anahtarları process argümanı olarak geçirir. Process listesinde görülebilir (Windows Task Manager veya `Get-Process | Select CommandLine` benzeri); paylaşılan makinelerde bunu unutmayın.
- Admin anahtarı kullanılmaz — sadece `SUPABASE_URL` + `SUPABASE_ANON_KEY` desteklenir.

## İlgili belgeler

- `SUPABASE_MCP_CONNECTION_REPORT.md` — MCP bağlantı ve project_ref kilidi.
- `SOCIAL_SPINE_LIVE_SMOKE_REPORT.md` — DB-level smoke ve P0 fix raporu.
- `SOCIAL_SPINE_V1_IMPLEMENTATION_REPORT.md` — Feed + Sosyal Gruplar implementation detayları.

## Yaygın sorunlar

| Belirti | Olası neden | Çözüm |
|---|---|---|
| `ERROR: .env.local bulunamadi` | İlk kurulum adımı atlandı | `Copy-Item .env.local.example .env.local` |
| `ERROR: ... bos` | `.env.local` içindeki değerler boş veya placeholder | Supabase dashboard'dan değerleri yapıştır |
| App açılıyor ama Supabase enabled değil | `--dart-define` parametreleri geçmedi | Script yerine `flutter run` çağırdıysanız scripti kullanın |
| `Authentication failed` (Supabase) | Yanlış anahtar veya project ref | Dashboard'dan kopyala-yapıştır; sağdaki/soldaki boşluğu temizle |
