# Akademi içerik motoru davranış testleri — İZOLE lokal PostgreSQL.
#
# Kullanım (repo kökünden):
#   powershell -File supabase\tests\academy_engine\run_tests.ps1
#
# Geçici cluster kurar (port 55433), harness + GERÇEK academy migration'larını
# uygular (İKİ KEZ — idempotency kanıtı), davranış testlerini koşar, siler.

param(
  [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
  [int]$Port = 55433,
  [string]$ClusterDir = 'C:\tmp\firinnet-pg-academy\cluster',
  [switch]$KeepCluster
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$sqlDir = Join-Path $scriptDir 'sql'
$dbName = 'firinnet_academy_test'

$initdb = Join-Path $PgBin 'initdb.exe'
$pgctl = Join-Path $PgBin 'pg_ctl.exe'
$psql = Join-Path $PgBin 'psql.exe'
foreach ($bin in @($initdb, $pgctl, $psql)) {
  if (-not (Test-Path $bin)) { throw "PostgreSQL binary yok: $bin" }
}

$schemaFile = Join-Path $scriptDir 'harness_schema.sql'
$migrations = @(
  (Join-Path $repoRoot 'supabase\migrations\20260713090000_academy_bot_profiles_v1.sql'),
  (Join-Path $repoRoot 'supabase\migrations\20260929090000_academy_content_engine_v1.sql'),
  (Join-Path $repoRoot 'supabase\migrations\20260929100000_academy_sources_seed_v1.sql')
)
foreach ($m in @($schemaFile) + $migrations) {
  if (-not (Test-Path $m)) { throw "Dosya bulunamadı: $m" }
}

function Invoke-Psql {
  param([string[]]$ExtraArgs, [string]$Label)
  & $psql -h 127.0.0.1 -p $Port -U postgres -X -q -v ON_ERROR_STOP=1 @ExtraArgs
  if ($LASTEXITCODE -ne 0) { throw "psql adımı başarısız: $Label" }
}

$started = $false
try {
  if (Test-Path $ClusterDir) {
    try { & $pgctl -D $ClusterDir stop -m immediate | Out-Null } catch {}
    Remove-Item -Recurse -Force $ClusterDir
  }
  New-Item -ItemType Directory -Force (Split-Path -Parent $ClusterDir) | Out-Null
  & $initdb -D $ClusterDir -U postgres -A trust -E UTF8 --no-locale | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'initdb başarısız' }
  $srvOut = Join-Path (Split-Path -Parent $ClusterDir) 'server.out.log'
  $srvErr = Join-Path (Split-Path -Parent $ClusterDir) 'server.err.log'
  $serverProc = Start-Process -FilePath (Join-Path $PgBin 'postgres.exe') `
    -ArgumentList @('-D', ('"{0}"' -f $ClusterDir), '-p', "$Port",
                    '-c', 'listen_addresses=127.0.0.1') `
    -NoNewWindow -PassThru `
    -RedirectStandardOutput $srvOut -RedirectStandardError $srvErr
  $pgIsReady = Join-Path $PgBin 'pg_isready.exe'
  $ready = $false
  for ($i = 0; $i -lt 60; $i++) {
    if ($serverProc.HasExited) { throw "postgres çöktü (log: $srvErr)" }
    & $pgIsReady -h 127.0.0.1 -p $Port | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Milliseconds 500
  }
  if (-not $ready) { throw "postgres hazır olmadı (log: $srvErr)" }
  $started = $true
  Write-Host "Cluster ayakta: 127.0.0.1:$Port ($ClusterDir)"

  Invoke-Psql @('-d', 'postgres', '-c', "drop database if exists $dbName") 'dropdb'
  Invoke-Psql @('-d', 'postgres', '-c', "create database $dbName") 'createdb'
  $env:PGOPTIONS = '-c check_function_bodies=off'
  Invoke-Psql @('-d', $dbName, '-f', $schemaFile) 'harness'
  Write-Host 'Harness yüklendi'
  foreach ($m in $migrations) {
    Invoke-Psql @('-d', $dbName, '-f', $m) ("migration: " + (Split-Path -Leaf $m))
    Write-Host ("Migration uygulandı: " + (Split-Path -Leaf $m))
  }
  # İdempotency kanıtı: engine + sources seed İKİNCİ KEZ uygulanır — hata
  # yok, seed kopyası yok (01/07 testleri sayıları doğrular).
  Invoke-Psql @('-d', $dbName, '-f', $migrations[1]) 'engine (2. kez)'
  Invoke-Psql @('-d', $dbName, '-f', $migrations[2]) 'sources (2. kez)'
  Write-Host 'Migrationlar 2. kez uygulandı (idempotency)'
  Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue

  $sequential = @('01_seed_idempotent.sql', '02_rls_privileges.sql',
                  '03_queue.sql', '04_publish.sql', '05_humor_guards.sql',
                  '06_dm_rules.sql', '07_sources_seed.sql')
  foreach ($f in $sequential) {
    Invoke-Psql @('-d', $dbName, '-f', (Join-Path $sqlDir $f)) $f
    Write-Host "OK: $f"
  }

  Write-Host ''
  Write-Host 'ALL ACADEMY ENGINE TESTS PASSED' -ForegroundColor Green
}
finally {
  if ($started) {
    try { & $pgctl -D $ClusterDir stop -m fast | Out-Null } catch {}
    if (-not $KeepCluster) {
      Remove-Item -Recurse -Force $ClusterDir -ErrorAction SilentlyContinue
    }
  }
  Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue
}
