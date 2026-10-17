# B2B S3 (talep geçmişi RPC + guard'lar + sayfalama + bildirim) davranış ve
# RLS smoke testleri — İZOLE lokal PostgreSQL 18.
#
# Kullanım (repo kökünden):
#   powershell -File supabase\tests\b2b_requests_s3\run_tests.ps1
#
# Ne yapar: geçici bir cluster kurar (C:\tmp\firinnet-pg-b2b\cluster, port
# 55434), production şema replikası + GERÇEK B2B migration zinciri + launch
# migration'ları + S3 migration'ını (idempotency için 2 kez) uygular, RLS/
# davranış/eşzamanlılık testlerini koşar, cluster'ı durdurup siler.
# ASLA production/paylaşılan bir veritabanına bağlanmaz.

param(
  [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
  [int]$Port = 55434,
  [string]$ClusterDir = 'C:\tmp\firinnet-pg-b2b\cluster',
  [switch]$KeepCluster
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$sqlDir = Join-Path $scriptDir 'sql'
$dbName = 'firinnet_b2b_s3_test'
$mig = Join-Path $repoRoot 'supabase\migrations'

$initdb = Join-Path $PgBin 'initdb.exe'
$pgctl = Join-Path $PgBin 'pg_ctl.exe'
$psql = Join-Path $PgBin 'psql.exe'
foreach ($bin in @($initdb, $pgctl, $psql)) {
  if (-not (Test-Path $bin)) { throw "PostgreSQL binary yok: $bin" }
}

$replica = Join-Path $repoRoot 'supabase\tests\launch_payment_behavior\prod_replica_schema.sql'
$s3 = Join-Path $mig '20261017120000_b2b_s3_requests_v1.sql'
$steps = @(
  @{ f = $replica; l = 'prod_replica_schema' },
  @{ f = (Join-Path $scriptDir '00_harness_b2b.sql'); l = '00_harness_b2b' },
  @{ f = (Join-Path $mig '20260617170000_b2b_market_v1.sql'); l = 'b2b_market_v1' },
  @{ f = (Join-Path $mig '20260617173000_b2b_market_v1_1_anon_rpc.sql'); l = 'b2b_v1_1_anon_rpc' },
  @{ f = (Join-Path $mig '20260618120000_b2b_v1_closing.sql'); l = 'b2b_v1_closing' },
  @{ f = (Join-Path $mig '20260618140000_b2b_closed_reply_guard.sql'); l = 'b2b_closed_reply_guard' },
  @{ f = (Join-Path $mig '20260618160000_b2b_quote_leads.sql'); l = 'b2b_quote_leads' },
  @{ f = (Join-Path $mig '20260618180000_b2b_lead_followup.sql'); l = 'b2b_lead_followup' },
  @{ f = (Join-Path $scriptDir '01_notify_b2b_live_subset.sql'); l = '01_notify_b2b_live_subset' },
  @{ f = (Join-Path $mig '20260622160000_b2b_reply_hardening.sql'); l = 'b2b_reply_hardening' },
  @{ f = (Join-Path $mig '20260712100000_supplier_entitlement_foundation_v1.sql'); l = 'supplier_entitlement_foundation_v1' },
  @{ f = (Join-Path $mig '20260923120000_launch_premium_and_listing_v1.sql'); l = 'launch_premium_and_listing_v1' },
  @{ f = (Join-Path $mig '20260925090000_supplier_launch_campaign_v1.sql'); l = 'supplier_launch_campaign_v1' },
  @{ f = $s3; l = 'S3 migration (1/2)' },
  @{ f = $s3; l = 'S3 migration (2/2 idempotency)' },
  @{ f = (Join-Path $scriptDir '02_harness_post.sql'); l = '02_harness_post (service_role grants)' }
)
foreach ($s in $steps) {
  if (-not (Test-Path $s.f)) { throw "Dosya bulunamadı: $($s.f)" }
}

function Invoke-Psql {
  param([string[]]$ExtraArgs, [string]$Label)
  & $psql -h 127.0.0.1 -p $Port -U postgres -X -q -v ON_ERROR_STOP=1 @ExtraArgs
  if ($LASTEXITCODE -ne 0) { throw "psql adımı başarısız: $Label" }
}

$started = $false
$serverProc = $null
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
  foreach ($s in $steps) {
    Invoke-Psql @('-d', $dbName, '-f', $s.f) $s.l
    Write-Host ("Uygulandı: " + $s.l)
  }
  Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue

  $sequential = @('10_seed.sql', '11_guards_and_transitions.sql',
                  '12_history_rpc.sql', '13_paging_and_counts.sql',
                  '14_notifications.sql')
  foreach ($f in $sequential) {
    Invoke-Psql @('-d', $dbName, '-o', 'NUL', '-f', (Join-Path $sqlDir $f)) $f
    Write-Host "OK: $f"
  }

  # Eşzamanlılık: A transaction'ı 3 sn açık tutar; B aynı kaynağa yazar.
  foreach ($pair in @(
      @{ a = 'conc_accept_a.sql'; b = 'conc_accept_b.sql' },
      @{ a = 'conc_dup_reply_a.sql'; b = 'conc_dup_reply_b.sql' })) {
    $pa = Start-Process -FilePath $psql -NoNewWindow -PassThru `
      -ArgumentList @('-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres', '-X', '-q',
                      '-d', $dbName, '-f', (Join-Path $sqlDir $pair.a))
    Start-Sleep -Milliseconds 800
    & $psql -h 127.0.0.1 -p $Port -U postgres -X -q -d $dbName -f (Join-Path $sqlDir $pair.b)
    $pa.WaitForExit()
    Write-Host ("Eşzamanlılık çifti koştu: " + $pair.a + " / " + $pair.b)
  }
  Invoke-Psql @('-d', $dbName, '-f', (Join-Path $sqlDir '15_concurrency_asserts.sql')) '15_concurrency_asserts'
  Write-Host 'OK: 15_concurrency_asserts.sql'

  Write-Host ''
  Write-Host 'ALL B2B S3 TESTS PASSED' -ForegroundColor Green
}
finally {
  if ($started -and -not $KeepCluster) {
    try { & $pgctl -D $ClusterDir stop -m fast | Out-Null } catch {}
    if ($serverProc -and -not $serverProc.HasExited) {
      try { $serverProc.WaitForExit(10000) | Out-Null } catch {}
    }
    try { Remove-Item -Recurse -Force $ClusterDir } catch {}
  }
}
