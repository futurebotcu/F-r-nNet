#Requires -Version 5.1
# FirinNet — Debug APK build, Supabase modda.
#
# .env.local oku, --dart-define ile gecir, anahtarlari asla yazdirma.
# Bu script'in varlik amaci: `flutter build apk --debug` cagrildiginda
# dart-define eksik kaldiginda APK'da supabaseEnabled=false derleniyor.
# Kullanici "Canli giris kapali" goruyor, sorun Supabase/sync degil,
# build-time config eksikligi. Bunu engellemek icin:
#
#   YANLIS:  flutter build apk --debug
#   DOGRU:   .\scripts\build_debug_supabase_apk.ps1
#
# Bkz: docs/BUILD_RUNBOOK.md

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

if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($key)) {
    Write-Host "ERROR: .env.local icinde SUPABASE_URL veya SUPABASE_ANON_KEY bos." -ForegroundColor Red
    Write-Host "       Anahtarsiz APK build'i engellendi (supabaseEnabled=false APK uretirdi)." -ForegroundColor Yellow
    exit 1
}

# Anahtarlarin varligi raporlanir, degerleri ASLA yazdirilmaz.
Write-Host "SUPABASE_URL present: yes"
Write-Host "SUPABASE_ANON_KEY present: yes"
Write-Host "Baslat: flutter build apk --debug (dart-define ile)"

Push-Location $repoRoot
try {
    $urlArg = "--dart-define=SUPABASE_URL=$url"
    $keyArg = "--dart-define=SUPABASE_ANON_KEY=$key"
    & flutter build apk --debug $urlArg $keyArg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Flutter build FAILED with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host ""
    Write-Host "Debug APK ready:" -ForegroundColor Green
    Write-Host "  build/app/outputs/flutter-apk/app-debug.apk"
    Write-Host "Supabase defines: present"
} finally {
    Pop-Location
}
