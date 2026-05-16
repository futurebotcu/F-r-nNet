#Requires -Version 5.1
# FirinNet - Supabase admin erisim saglama testi (READ-ONLY).
# .env.admin.local okunur, anahtari konsola/log'a yazmaz, yalnizca
# Auth Admin REST API'de read-only bir endpoint cagirir.
#
# Destructive islem YAPMAZ: drop / truncate / delete-all / user delete /
# storage delete / auth user delete. Sadece /admin/users LIST.

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$envFile  = Join-Path $repoRoot '.env.admin.local'

if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env.admin.local bulunamadi: $envFile" -ForegroundColor Red
    Write-Host "Kurulum: .env.admin.local.example dosyasini .env.admin.local olarak kopyalayin." -ForegroundColor Yellow
    Write-Host "Anahtar: Supabase Dashboard -> Project Settings -> API -> service_role" -ForegroundColor Yellow
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

$url      = $config['SUPABASE_URL']
$adminKey = $config['SUPABASE_SERVICE_ROLE_KEY']

if ([string]::IsNullOrWhiteSpace($url)) {
    Write-Host "ERROR: SUPABASE_URL bos." -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrWhiteSpace($adminKey)) {
    Write-Host "ERROR: SUPABASE_SERVICE_ROLE_KEY bos." -ForegroundColor Red
    Write-Host "Supabase Dashboard -> Project Settings -> API -> service_role anahtarini kopyalayin." -ForegroundColor Yellow
    exit 1
}

Write-Host "supabase url present: yes"
Write-Host "admin key present: yes"
Write-Host "Test: Auth Admin /admin/users (page=1, per_page=1, read-only)..."

$endpoint = "$url/auth/v1/admin/users?page=1&per_page=1"
$headers = @{
    'apikey'        = $adminKey
    'Authorization' = "Bearer $adminKey"
}

try {
    $resp = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get -ErrorAction Stop
    $count = 0
    if ($resp.users) { $count = $resp.users.Count }
    Write-Host "admin API reachable: yes" -ForegroundColor Green
    Write-Host ("users listed on page 1: " + $count)
    Write-Host "Destructive islem yapilmadi."
} catch {
    Write-Host "admin API call FAILED" -ForegroundColor Red
    $status = $null
    if ($_.Exception.Response) {
        try { $status = $_.Exception.Response.StatusCode.Value__ } catch { }
    }
    if ($status) { Write-Host ("status: $status") }
    Write-Host "Olasi sebep: anahtar yanlis veya proje ref'i hatali." -ForegroundColor Yellow
    Write-Host "Anahtar Supabase Dashboard -> Project Settings -> API -> service_role'den kopyalanmalidir." -ForegroundColor Yellow
    exit 1
}
