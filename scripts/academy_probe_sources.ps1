# FırınNet Akademi — aday kaynak canlı SALT-OKUNUR doğrulama probu.
# docs/academy/sources_candidates.json okur; her aday için robots.txt +
# probe URL'lerini dener (GET, sınırlı), feed/sitemap tespit eder ve
# docs/academy/source_verification.json makinece okunabilir raporunu yazar.
# HİÇBİR yazma/oturum/form işlemi yapmaz; login/CAPTCHA/paywall aşmaz.

param(
  [string]$Candidates = 'docs/academy/sources_candidates.json',
  [string]$OutFile = 'docs/academy/source_verification.json',
  [int]$TimeoutSec = 15,
  [int]$DelayMs = 300
)

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UA = 'FirinNetAcademyBot/0.1 (+https://firinnet.app; kaynak-dogrulama; iletisim: destek@firinnet.app)'

$data = Get-Content $Candidates -Raw -Encoding UTF8 | ConvertFrom-Json
$results = @()

function Probe-Url {
  param([string]$Url)
  $r = [ordered]@{ url = $Url; ok = $false; status = $null;
                   content_type = $null; kind = 'unknown'; note = $null }
  try {
    $resp = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec $TimeoutSec `
      -MaximumRedirection 5 -UserAgent $UA -UseBasicParsing
    $r.status = [int]$resp.StatusCode
    $r.content_type = [string]$resp.Headers['Content-Type']
    $body = if ($resp.Content -is [byte[]]) {
      [Text.Encoding]::UTF8.GetString($resp.Content[0..[Math]::Min($resp.Content.Length-1, 65535)])
    } else { $resp.Content.Substring(0, [Math]::Min($resp.Content.Length, 65536)) }
    $r.ok = $true
    if ($body -match '<rss[\s>]' -or $body -match '<feed[\s>]') {
      $r.kind = 'feed'
      $items = ([regex]::Matches($body, '<(item|entry)[\s>]')).Count
      $hasTitle = $body -match '<title>'
      $hasDate = $body -match '(pubDate|published|updated|dc:date)'
      $r.note = "items=$items title=$hasTitle date=$hasDate"
      if ($items -lt 1) { $r.kind = 'feed_empty' }
    } elseif ($body -match '<(urlset|sitemapindex)[\s>]') {
      $r.kind = 'sitemap'
      $r.note = 'locs=' + ([regex]::Matches($body, '<loc>')).Count
    } elseif ($body -match '(?i)<html') {
      $r.kind = 'html'
    }
  } catch {
    $r.note = $_.Exception.Message
    if ($_.Exception.Response) {
      try { $r.status = [int]$_.Exception.Response.StatusCode } catch {}
    }
  }
  return $r
}

foreach ($s in $data.sources) {
  Write-Host ("Probe: " + $s.slug)
  $entry = [ordered]@{
    slug = $s.slug; name = $s.name; domain = $s.domain
    country = $s.country; lang = $s.lang; type = $s.type
    commercial = $s.commercial; topics = $s.topics
    robots = $null; probes = @(); verdict = 'candidate'
    verdict_reason = ''; probed_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  # robots.txt (salt-okunur; kaba sinyal — worker tam kural uygular)
  $robots = Probe-Url ("https://" + $s.domain + "/robots.txt")
  if ($robots.ok) {
    $entry.robots = 'present'
  } else { $entry.robots = 'missing_or_error' }
  Start-Sleep -Milliseconds $DelayMs

  $bestKind = 'none'
  foreach ($u in $s.probe) {
    $p = Probe-Url $u
    $entry.probes += $p
    if ($p.kind -eq 'feed') { $bestKind = 'feed' }
    elseif ($p.kind -eq 'sitemap' -and $bestKind -ne 'feed') {
      $bestKind = 'sitemap' }
    elseif ($p.kind -eq 'html' -and $bestKind -eq 'none') {
      $bestKind = 'html' }
    Start-Sleep -Milliseconds $DelayMs
  }

  # Karar: feed (başlık+tarih+item'lı) → active_feed adayı;
  # sitemap/html erişilebilir → active_html adayı (metin çıkarımı worker'da
  # kanıtlanana dek 'reachable'); hiçbiri → degraded.
  switch ($bestKind) {
    'feed'    { $entry.verdict = 'reachable_feed'
                $entry.verdict_reason = 'çalışan RSS/Atom bulundu' }
    'sitemap' { $entry.verdict = 'reachable_sitemap'
                $entry.verdict_reason = 'sitemap erişilebilir (içerik çıkarımı ayrıca kanıtlanmalı)' }
    'html'    { $entry.verdict = 'reachable_html'
                $entry.verdict_reason = 'sayfa erişilebilir; feed bulunamadı' }
    default   { $entry.verdict = 'unreachable'
                $entry.verdict_reason = 'hiçbir probe URL erişilemedi' }
  }
  $results += $entry
}

$summary = [ordered]@{
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  candidates_total = $results.Count
  reachable_feed = @($results | Where-Object { $_.verdict -eq 'reachable_feed' }).Count
  reachable_sitemap = @($results | Where-Object { $_.verdict -eq 'reachable_sitemap' }).Count
  reachable_html = @($results | Where-Object { $_.verdict -eq 'reachable_html' }).Count
  unreachable = @($results | Where-Object { $_.verdict -eq 'unreachable' }).Count
  note = 'reachable_* = erişim kanıtı; AKTİF kaynak sayılmak için worker içerik çıkarımı (başlık+kanonik URL+tarih+metin) ayrıca kanıtlanmalıdır. Lisans/kullanım koşulu onayı DEĞİLDİR.'
}
$report = [ordered]@{ summary = $summary; sources = $results }
$json = $report | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($OutFile, $json, (New-Object Text.UTF8Encoding($false)))
Write-Host ''
Write-Host ("SUMMARY feed={0} sitemap={1} html={2} unreachable={3} / {4}" -f
  $summary.reachable_feed, $summary.reachable_sitemap,
  $summary.reachable_html, $summary.unreachable, $summary.candidates_total)
