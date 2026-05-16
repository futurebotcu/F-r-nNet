#Requires -Version 5.1
# FirinNet — Windows desktop'ta Supabase modda flutter run.
# .env.local'i okur, --dart-define ile gecirir, anahtarlari yazdirmaz.

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
    Write-Host "Supabase Project Settings -> API'den URL ve anon (publishable) anahtari kopyalayin." -ForegroundColor Yellow
    exit 1
}

Write-Host "SUPABASE_URL present: yes"
Write-Host "SUPABASE_ANON_KEY present: yes"
Write-Host "Baslat: flutter run -d windows"

Push-Location $repoRoot
try {
    $urlArg = "--dart-define=SUPABASE_URL=$url"
    $keyArg = "--dart-define=SUPABASE_ANON_KEY=$key"
    & flutter run -d windows $urlArg $keyArg
} finally {
    Pop-Location
}
