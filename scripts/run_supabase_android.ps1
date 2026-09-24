#Requires -Version 5.1
# FirinNet — Android cihaz/emulator'de Supabase modda flutter run.
# Kullanim:
#   .\scripts\run_supabase_android.ps1 -DeviceId emulator-5554
#   .\scripts\run_supabase_android.ps1              (cihaz listesi gosterir)

param(
    [string]$DeviceId
)

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
    exit 1
}

Write-Host "SUPABASE_URL present: yes"
Write-Host "SUPABASE_ANON_KEY present: yes"
Write-Host "REVENUECAT_ANDROID_API_KEY present: yes"

if (-not $DeviceId) {
    Write-Host ""
    Write-Host "DeviceId belirtilmedi. Mevcut cihazlar:" -ForegroundColor Yellow
    Push-Location $repoRoot
    try { & flutter devices } finally { Pop-Location }
    Write-Host ""
    Write-Host "Kullanim: .\scripts\run_supabase_android.ps1 -DeviceId <id>" -ForegroundColor Yellow
    Write-Host "Ornek:   .\scripts\run_supabase_android.ps1 -DeviceId emulator-5554" -ForegroundColor Yellow
    exit 1
}

Write-Host "Baslat: flutter run -d $DeviceId"

Push-Location $repoRoot
try {
    $urlArg = "--dart-define=SUPABASE_URL=$url"
    $keyArg = "--dart-define=SUPABASE_ANON_KEY=$key"
    $rcAndroidArg = "--dart-define=REVENUECAT_ANDROID_API_KEY=$revenueCatAndroidKey"
    & flutter run -d $DeviceId $urlArg $keyArg $rcAndroidArg
} finally {
    Pop-Location
}
