# Launch premium/listing payment davranış testleri — İZOLE lokal PostgreSQL.
#
# Kullanım (repo kökünden):
#   powershell -File supabase\tests\launch_payment_behavior\run_tests.ps1
#
# Ne yapar: geçici bir PostgreSQL cluster'ı kurar (varsayılan
# C:\tmp\firinnet-pg-audit\cluster, port 55432), Supabase mock harness'ı +
# GERÇEK migration dosyalarını uygular, davranış ve eşzamanlılık testlerini
# koşar, cluster'ı durdurup siler (-KeepCluster ile bırakır).
#
# ASLA production/paylaşılan bir veritabanına bağlanmaz (yalnız 127.0.0.1 +
# kendi kurduğu cluster).

param(
  [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
  [int]$Port = 55432,
  [string]$ClusterDir = 'C:\tmp\firinnet-pg-audit\cluster',
  [switch]$KeepCluster
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$sqlDir = Join-Path $scriptDir 'sql'
$dbName = 'firinnet_launch_test'

$initdb = Join-Path $PgBin 'initdb.exe'
$pgctl = Join-Path $PgBin 'pg_ctl.exe'
$psql = Join-Path $PgBin 'psql.exe'
foreach ($bin in @($initdb, $pgctl, $psql)) {
  if (-not (Test-Path $bin)) { throw "PostgreSQL binary yok: $bin" }
}

$migrations = @(
  (Join-Path $repoRoot 'supabase\migrations\20260712120000_store_payments_foundation_v1.sql'),
  (Join-Path $repoRoot 'supabase\migrations\20260923120000_launch_premium_and_listing_v1.sql')
)
foreach ($m in $migrations) {
  if (-not (Test-Path $m)) { throw "Migration bulunamadı: $m" }
}

function Invoke-Psql {
  param([string[]]$ExtraArgs, [string]$Label)
  & $psql -h 127.0.0.1 -p $Port -U postgres -X -q -v ON_ERROR_STOP=1 @ExtraArgs
  if ($LASTEXITCODE -ne 0) { throw "psql adımı başarısız: $Label" }
}

$started = $false
try {
  # 1) Cluster kur + başlat.
  if (Test-Path $ClusterDir) {
    try { & $pgctl -D $ClusterDir stop -m immediate | Out-Null } catch {}
    Remove-Item -Recurse -Force $ClusterDir
  }
  New-Item -ItemType Directory -Force (Split-Path -Parent $ClusterDir) | Out-Null
  & $initdb -D $ClusterDir -U postgres -A trust -E UTF8 --no-locale | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'initdb başarısız' }
  # DİKKAT: pg_ctl start burada kullanılamaz — pipe'lanırsa daemon stdout
  # handle'ını miras alır ve EOF beklenir; Start-Process -Wait ise PS 5.1'de
  # tüm süreç ağacını (daemon dahil) bekler. postgres.exe doğrudan başlatılır
  # ve pg_isready ile hazır olması beklenir.
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

  # 2) Test DB + harness + gerçek migration'lar.
  Invoke-Psql @('-d', 'postgres', '-c', "drop database if exists $dbName") 'dropdb'
  Invoke-Psql @('-d', 'postgres', '-c', "create database $dbName") 'createdb'
  Invoke-Psql @('-d', $dbName, '-f', (Join-Path $scriptDir 'harness_schema.sql')) 'harness'
  # Migration'lar tam Supabase şeması olmadan uygulanır: fonksiyon gövdeleri
  # yalnız harness dışı modüllere değinir → gövde doğrulaması kapalı.
  $env:PGOPTIONS = '-c check_function_bodies=off'
  foreach ($m in $migrations) {
    Invoke-Psql @('-d', $dbName, '-f', $m) ("migration: " + (Split-Path -Leaf $m))
    Write-Host ("Migration uygulandı: " + (Split-Path -Leaf $m))
  }
  Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue

  # 3) Sıralı davranış testleri.
  foreach ($f in @('10_event_claim_retry.sql', '12_subscription_ordering.sql',
                   '13_promo_and_privileges.sql')) {
    Invoke-Psql @('-d', $dbName, '-f', (Join-Path $sqlDir $f)) $f
    Write-Host "OK: $f"
  }

  # 4) Eşzamanlılık: A oturumu transaction'ı 3 sn açık tutar; B, A commit
  #    etmeden aynı event/promo'yu teslim eder.
  foreach ($pair in @(
      @{ a = 'conc_claim_a.sql'; b = 'conc_claim_b.sql' },
      @{ a = 'conc_promo_a.sql'; b = 'conc_promo_b.sql' })) {
    $aArgs = @('-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres', '-X', '-q',
               '-v', 'ON_ERROR_STOP=1', '-d', $dbName,
               '-f', ('"{0}"' -f (Join-Path $sqlDir $pair.a)))
    $aOut = Join-Path (Split-Path -Parent $ClusterDir) ($pair.a + '.out.log')
    $aErr = Join-Path (Split-Path -Parent $ClusterDir) ($pair.a + '.err.log')
    $procA = Start-Process -FilePath $psql -ArgumentList $aArgs `
      -NoNewWindow -PassThru `
      -RedirectStandardOutput $aOut -RedirectStandardError $aErr
    # PS 5.1: handle cache'lenmezse ExitCode $null kalır (sahte hata).
    $null = $procA.Handle
    Start-Sleep -Milliseconds 1200
    Invoke-Psql @('-d', $dbName, '-f', (Join-Path $sqlDir $pair.b)) $pair.b
    $procA.WaitForExit()
    if ($procA.ExitCode -ne 0) {
      Get-Content $aOut, $aErr -ErrorAction SilentlyContinue | Write-Host
      throw ("Eşzamanlı oturum A hata: " + $pair.a)
    }
    Write-Host ("OK: " + $pair.a + " + " + $pair.b)
  }
  Invoke-Psql @('-d', $dbName, '-f',
    (Join-Path $sqlDir '14_concurrency_asserts.sql')) '14_concurrency_asserts.sql'
  Write-Host 'OK: 14_concurrency_asserts.sql'

  Write-Host ''
  Write-Host 'ALL LAUNCH PAYMENT BEHAVIOR TESTS PASSED' -ForegroundColor Green
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
