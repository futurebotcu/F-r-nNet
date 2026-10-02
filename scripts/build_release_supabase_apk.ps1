#Requires -Version 5.1
# FirinNet — Release APK build, Supabase modda (telefona dogrudan kurulum /
# son kontrol icin). build_release_supabase_aab.ps1 ile ayni kurallar:
# .env.local oku, --dart-define ile gecir, anahtarlari yazdirma.

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile  = Join-Path $repoRoot '.env.local'

if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env.local bulunamadi: $envFile" -ForegroundColor Red
    Write-Host "Kurulum: .env.local.example dosyasini .env.local olarak kopyalayin ve degerleri ekleyin." -ForegroundColor Yellow
    exit 1
}

$config = @{}
foreach ($line in (Get-Content $envFile -Encoding UTF8)) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    if ($trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -le 0) { continue }
    $k = $trimmed.Substring(0, $idx).Trim()
    $v = $trimmed.Substring($idx + 1).Trim()
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or
        ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        $v = $v.Substring(1, $v.Length - 2)
    }
    $config[$k] = $v
}

$url = $config['SUPABASE_URL']
$key = $config['SUPABASE_ANON_KEY']
$revenueCatAndroidKey = $config['REVENUECAT_ANDROID_API_KEY']

if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($key)) {
    Write-Host "ERROR: .env.local icinde SUPABASE_URL veya SUPABASE_ANON_KEY bos." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($revenueCatAndroidKey)) {
    Write-Host "ERROR: .env.local icinde REVENUECAT_ANDROID_API_KEY bos." -ForegroundColor Red
    Write-Host "Release APK odeme ozelligi kapali uretilmesin diye build durduruldu." -ForegroundColor Yellow
    exit 1
}

Write-Host "SUPABASE_URL present: yes"
Write-Host "SUPABASE_ANON_KEY present: yes"
Write-Host "REVENUECAT_ANDROID_API_KEY present: yes"
Write-Host "Baslat: flutter build apk --release"

Push-Location $repoRoot
try {
    $urlArg = "--dart-define=SUPABASE_URL=$url"
    $keyArg = "--dart-define=SUPABASE_ANON_KEY=$key"
    $rcAndroidArg = "--dart-define=REVENUECAT_ANDROID_API_KEY=$revenueCatAndroidKey"
    & flutter build apk --release $urlArg $keyArg $rcAndroidArg
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
