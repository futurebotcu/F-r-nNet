#Requires -Version 5.1
# FirinNet — Release Android App Bundle (AAB) build, Supabase modda.
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
    Write-Host "Production AAB odeme ozelligi kapali uretilmesin diye build durduruldu." -ForegroundColor Yellow
    exit 1
}

Write-Host "SUPABASE_URL present: yes"
Write-Host "SUPABASE_ANON_KEY present: yes"
Write-Host "REVENUECAT_ANDROID_API_KEY present: yes"
Write-Host "Baslat: flutter build appbundle --release"
Write-Host ""
Write-Host "NOT: Android release signing config (android/key.properties + signingConfig)" -ForegroundColor Yellow
Write-Host "     yoksa build hata verebilir veya debug imzasiyla cikar. Bu durumda" -ForegroundColor Yellow
Write-Host "     P0-4 (Android release imzasi) cozulmesi gerekir." -ForegroundColor Yellow

Push-Location $repoRoot
try {
    $urlArg = "--dart-define=SUPABASE_URL=$url"
    $keyArg = "--dart-define=SUPABASE_ANON_KEY=$key"
    $rcAndroidArg = "--dart-define=REVENUECAT_ANDROID_API_KEY=$revenueCatAndroidKey"
    & flutter build appbundle --release $urlArg $keyArg $rcAndroidArg
} finally {
    Pop-Location
}
