#Requires -Version 5.1
# FirinNet - Live smoke: job_offer_posts + market_listings (V1 sprint sonrasi).
#
# Akis:
#   1. .env.admin.local'dan SUPABASE_URL + service_role oku.
#   2. Iki gecici test user yarat (Admin API + email_confirm).
#   3. Sign-in -> her ikisi icin user JWT.
#   4. User A: job_offer_posts insert/select/update/delete + setActive
#   5. User B: A'nin offer'ina cross-owner insert/update/delete reject (403/204+unchanged)
#      B: kendi offer'i + listActive okuyabilmeli
#   6. User A: market_listings insert/select/update/delete + setActive
#   7. User B: A'nin listing'ine cross-owner reject
#      B: kendi listing'i + listActive okuyabilmeli
#   8. Cleanup: Admin API user delete (CASCADE -> profiles + offer + listing).
#   9. Sonuc: ayri tabloda PASS/FAIL.
#
# Guvenlik:
#   - service_role konsola yazilmaz; "present: yes" masking.
#   - Test user uuid acik logged DEGIL.

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$envFile  = Join-Path $repoRoot '.env.admin.local'

if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env.admin.local yok" -ForegroundColor Red
    exit 1
}

$config = @{}
foreach ($line in (Get-Content $envFile -Encoding UTF8)) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -le 0) { continue }
    $k = $trimmed.Substring(0, $idx).Trim()
    $v = $trimmed.Substring($idx + 1).Trim()
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        $v = $v.Substring(1, $v.Length - 2)
    }
    $config[$k] = $v
}
$baseUrl  = $config['SUPABASE_URL']
$adminKey = $config['SUPABASE_SERVICE_ROLE_KEY']
if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($adminKey)) {
    Write-Host "ERROR: env eksik" -ForegroundColor Red
    exit 1
}
Write-Host "supabase url present: yes"
Write-Host "admin key present: yes"

$results = New-Object System.Collections.ArrayList
function Record-Result {
    param([string]$Name, [bool]$Pass, [string]$Detail = '')
    [void]$results.Add([PSCustomObject]@{
        Name   = $Name
        Status = $(if ($Pass) { 'PASS' } else { 'FAIL' })
        Detail = $Detail
    })
}

function Invoke-Supa {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers,
        [object]$Body
    )
    $url = "$baseUrl$Path"
    $hdrs = @{}
    foreach ($k in $Headers.Keys) { $hdrs[$k] = $Headers[$k] }
    if (-not $hdrs.ContainsKey('apikey')) { $hdrs['apikey'] = $adminKey }
    $params = @{
        Uri = $url; Method = $Method; Headers = $hdrs
        UseBasicParsing = $true; ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $params['Body']        = ($Body | ConvertTo-Json -Compress -Depth 10)
        $params['ContentType'] = 'application/json'
    }
    try {
        $resp = Invoke-WebRequest @params
        return @{ Status = [int]$resp.StatusCode; Body = $resp.Content; Error = $false }
    } catch {
        $status = 0; $body = ''
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch { }
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $stream.Position = 0
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $reader.Close()
            } catch { }
        }
        return @{ Status = $status; Body = $body; Error = $true }
    }
}

function Get-ReturnedId {
    param($Response)
    if ($Response.Error -or -not $Response.Body) { return $null }
    try {
        $j = $Response.Body | ConvertFrom-Json
        if ($j -is [array] -and $j.Count -ge 1) { return $j[0].id }
        if ($j.id) { return $j.id }
    } catch { }
    return $null
}

$ts = (Get-Date).ToString('yyyyMMddHHmmss')
$pwA = [Guid]::NewGuid().ToString('N')
$pwB = [Guid]::NewGuid().ToString('N')
$emailA = "firinnet_smoke_rf_a_$ts@example.com"
$emailB = "firinnet_smoke_rf_b_$ts@example.com"

# ============================================================
# Auth setup
# ============================================================
$createA = Invoke-Supa 'POST' '/auth/v1/admin/users' @{ Authorization = "Bearer $adminKey" } @{
    email = $emailA; password = $pwA; email_confirm = $true
}
$userAId = Get-ReturnedId $createA
Record-Result 'Auth: create user A' ($null -ne $userAId) "status=$($createA.Status)"

$createB = Invoke-Supa 'POST' '/auth/v1/admin/users' @{ Authorization = "Bearer $adminKey" } @{
    email = $emailB; password = $pwB; email_confirm = $true
}
$userBId = Get-ReturnedId $createB
Record-Result 'Auth: create user B' ($null -ne $userBId) "status=$($createB.Status)"

if (-not $userAId -or -not $userBId) {
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

$signA = Invoke-Supa 'POST' '/auth/v1/token?grant_type=password' @{} @{ email = $emailA; password = $pwA }
$tokA = $null
if (-not $signA.Error -and $signA.Body) {
    try { $tokA = ($signA.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Auth: sign-in A' ($null -ne $tokA) "status=$($signA.Status)"

$signB = Invoke-Supa 'POST' '/auth/v1/token?grant_type=password' @{} @{ email = $emailB; password = $pwB }
$tokB = $null
if (-not $signB.Error -and $signB.Body) {
    try { $tokB = ($signB.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Auth: sign-in B' ($null -ne $tokB) "status=$($signB.Status)"

if (-not $tokA -or -not $tokB) {
    [void](Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userAId" @{ Authorization = "Bearer $adminKey" } $null)
    [void](Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userBId" @{ Authorization = "Bearer $adminKey" } $null)
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

$hA = @{ Authorization = "Bearer $tokA"; Prefer = 'return=representation' }
$hAmin = @{ Authorization = "Bearer $tokA"; Prefer = 'return=minimal' }
$hB = @{ Authorization = "Bearer $tokB"; Prefer = 'return=representation' }
$hBmin = @{ Authorization = "Bearer $tokB"; Prefer = 'return=minimal' }

# ============================================================
# JOB_OFFER_POSTS SMOKE
# ============================================================

# 1) A insert — ASCII basliklar (PowerShell 5.1 Windows-1254 -> JSON UTF-8 uyumu icin)
$jo1 = Invoke-Supa 'POST' '/rest/v1/job_offer_posts' $hA @{
    owner_id = $userAId
    title = "Tas Firin Ustasi Araniyor $ts"
    role_title = 'Ekmek Ustasi'
    city = 'Ankara'
    is_active = $true
}
$jo1Id = Get-ReturnedId $jo1
Record-Result 'JobOffer: A insert own' ($null -ne $jo1Id) "status=$($jo1.Status)"

# 2) A kendi offer select
if ($jo1Id) {
    $jo1Get = Invoke-Supa 'GET' "/rest/v1/job_offer_posts?id=eq.$jo1Id&select=id,title,author_name" @{ Authorization = "Bearer $tokA" } $null
    $hasA = $false
    if (-not $jo1Get.Error -and $jo1Get.Body) {
        try { $hasA = (($jo1Get.Body | ConvertFrom-Json).Count -eq 1) } catch { }
    }
    Record-Result 'JobOffer: A reads own offer' $hasA "status=$($jo1Get.Status)"
}

# 3) B active offer'ı select edebilir (authenticated)
$joActiveByB = Invoke-Supa 'GET' '/rest/v1/job_offer_posts?is_active=eq.true&select=id' @{ Authorization = "Bearer $tokB" } $null
$bSeesActive = $false
if (-not $joActiveByB.Error -and $joActiveByB.Body) {
    try {
        $arr = $joActiveByB.Body | ConvertFrom-Json
        $bSeesActive = (@($arr | Where-Object { $_.id -eq $jo1Id })).Count -ge 1
    } catch { }
}
Record-Result 'JobOffer: B reads active offers (auth select)' $bSeesActive "status=$($joActiveByB.Status)"

# 4) B kendi job_offer insert dener owner_id=A → 403
$forgedB = Invoke-Supa 'POST' '/rest/v1/job_offer_posts' $hB @{
    owner_id = $userAId
    title = "Forged by B $ts"
    role_title = 'Hack'
    is_active = $true
}
Record-Result 'JobOffer: B cannot insert with owner=A' ($forgedB.Status -in 401,403) "status=$($forgedB.Status)"

# 5) B, A'nın offer'ını UPDATE dener → RLS 0 row affected (post unchanged)
if ($jo1Id) {
    $patchB = Invoke-Supa 'PATCH' "/rest/v1/job_offer_posts?id=eq.$jo1Id" @{ Authorization = "Bearer $tokB" } @{
        title = "HackedByB $ts"
    }
    $getAfter = Invoke-Supa 'GET' "/rest/v1/job_offer_posts?id=eq.$jo1Id&select=title" @{ Authorization = "Bearer $tokA" } $null
    $unchanged = $false
    if (-not $getAfter.Error -and $getAfter.Body) {
        try {
            $arr = $getAfter.Body | ConvertFrom-Json
            $unchanged = ($arr.Count -ge 1 -and $arr[0].title -eq "Tas Firin Ustasi Araniyor $ts")
        } catch { }
    }
    Record-Result 'JobOffer: B cannot UPDATE A offer' $unchanged "patch_status=$($patchB.Status) unchanged=$unchanged"
}

# 6) B, A'nın offer'ını DELETE dener → still exists
if ($jo1Id) {
    $delB = Invoke-Supa 'DELETE' "/rest/v1/job_offer_posts?id=eq.$jo1Id" @{ Authorization = "Bearer $tokB" } $null
    $stillThere = Invoke-Supa 'GET' "/rest/v1/job_offer_posts?id=eq.$jo1Id&select=id" @{ Authorization = "Bearer $tokA" } $null
    $exists = $false
    if (-not $stillThere.Error -and $stillThere.Body) {
        try { $exists = (($stillThere.Body | ConvertFrom-Json).Count -ge 1) } catch { }
    }
    Record-Result 'JobOffer: B cannot DELETE A offer' $exists "delete_status=$($delB.Status) still_exists=$exists"
}

# 7) A toggles inactive → listActive'da görünmez
if ($jo1Id) {
    $toggleA = Invoke-Supa 'PATCH' "/rest/v1/job_offer_posts?id=eq.$jo1Id" @{
        Authorization = "Bearer $tokA"
    } @{ is_active = $false }

    $activeAfter = Invoke-Supa 'GET' "/rest/v1/job_offer_posts?is_active=eq.true&select=id" @{ Authorization = "Bearer $tokB" } $null
    $stillActive = $true
    if (-not $activeAfter.Error -and $activeAfter.Body) {
        try {
            $arr = $activeAfter.Body | ConvertFrom-Json
            $stillActive = (@($arr | Where-Object { $_.id -eq $jo1Id })).Count -ge 1
        } catch { }
    }
    Record-Result 'JobOffer: A toggle inactive hides from public' (-not $stillActive) "patch_status=$($toggleA.Status) stillActive=$stillActive"
}

# 8) A kendi offer'ını DELETE
if ($jo1Id) {
    $delA = Invoke-Supa 'DELETE' "/rest/v1/job_offer_posts?id=eq.$jo1Id" @{ Authorization = "Bearer $tokA" } $null
    Record-Result 'JobOffer: A deletes own offer' ($delA.Status -eq 204) "status=$($delA.Status)"
}

# ============================================================
# MARKET_LISTINGS SMOKE
# ============================================================

# 1) A insert
$ml1 = Invoke-Supa 'POST' '/rest/v1/market_listings' $hA @{
    owner_id = $userAId
    title = "Spiral mikser $ts"
    category = 'ekipman'
    listing_type = 'product'
    price = 50000
    is_active = $true
}
$ml1Id = Get-ReturnedId $ml1
Record-Result 'MarketListing: A insert own' ($null -ne $ml1Id) "status=$($ml1.Status)"

# 2) A kendi listing select
if ($ml1Id) {
    $ml1Get = Invoke-Supa 'GET' "/rest/v1/market_listings?id=eq.$ml1Id&select=id,title" @{ Authorization = "Bearer $tokA" } $null
    $hasA = $false
    if (-not $ml1Get.Error -and $ml1Get.Body) {
        try { $hasA = (($ml1Get.Body | ConvertFrom-Json).Count -eq 1) } catch { }
    }
    Record-Result 'MarketListing: A reads own listing' $hasA "status=$($ml1Get.Status)"
}

# 3) B active listing select
$mlActiveByB = Invoke-Supa 'GET' '/rest/v1/market_listings?is_active=eq.true&select=id' @{ Authorization = "Bearer $tokB" } $null
$bSeesActiveML = $false
if (-not $mlActiveByB.Error -and $mlActiveByB.Body) {
    try {
        $arr = $mlActiveByB.Body | ConvertFrom-Json
        $bSeesActiveML = (@($arr | Where-Object { $_.id -eq $ml1Id })).Count -ge 1
    } catch { }
}
Record-Result 'MarketListing: B reads active listings (auth select)' $bSeesActiveML "status=$($mlActiveByB.Status)"

# 4) B forged owner_id=A → 403
$forgedMLB = Invoke-Supa 'POST' '/rest/v1/market_listings' $hB @{
    owner_id = $userAId
    title = "Forged by B $ts"
    category = 'ekipman'
    listing_type = 'product'
}
Record-Result 'MarketListing: B cannot insert with owner=A' ($forgedMLB.Status -in 401,403) "status=$($forgedMLB.Status)"

# 5) B UPDATE A's listing → unchanged
if ($ml1Id) {
    $patchMLB = Invoke-Supa 'PATCH' "/rest/v1/market_listings?id=eq.$ml1Id" @{ Authorization = "Bearer $tokB" } @{
        title = "HackedByB $ts"
    }
    $getAfter = Invoke-Supa 'GET' "/rest/v1/market_listings?id=eq.$ml1Id&select=title" @{ Authorization = "Bearer $tokA" } $null
    $unchanged = $false
    if (-not $getAfter.Error -and $getAfter.Body) {
        try {
            $arr = $getAfter.Body | ConvertFrom-Json
            $unchanged = ($arr.Count -ge 1 -and $arr[0].title -eq "Spiral mikser $ts")
        } catch { }
    }
    Record-Result 'MarketListing: B cannot UPDATE A listing' $unchanged "patch_status=$($patchMLB.Status) unchanged=$unchanged"
}

# 6) B DELETE A's listing → still exists
if ($ml1Id) {
    $delMLB = Invoke-Supa 'DELETE' "/rest/v1/market_listings?id=eq.$ml1Id" @{ Authorization = "Bearer $tokB" } $null
    $stillThere = Invoke-Supa 'GET' "/rest/v1/market_listings?id=eq.$ml1Id&select=id" @{ Authorization = "Bearer $tokA" } $null
    $exists = $false
    if (-not $stillThere.Error -and $stillThere.Body) {
        try { $exists = (($stillThere.Body | ConvertFrom-Json).Count -ge 1) } catch { }
    }
    Record-Result 'MarketListing: B cannot DELETE A listing' $exists "delete_status=$($delMLB.Status) still_exists=$exists"
}

# 7) Category validation — invalid value
$mlBadCat = Invoke-Supa 'POST' '/rest/v1/market_listings' $hA @{
    owner_id = $userAId
    title = "BadCat $ts"
    category = 'invalid_category_xxx'
    listing_type = 'product'
}
Record-Result 'MarketListing: invalid category rejected' ($mlBadCat.Status -in 400,409,422,500) "status=$($mlBadCat.Status)"

# 8) listing_type validation — invalid
$mlBadType = Invoke-Supa 'POST' '/rest/v1/market_listings' $hA @{
    owner_id = $userAId
    title = "BadType $ts"
    category = 'ekipman'
    listing_type = 'invalid_type_xxx'
}
Record-Result 'MarketListing: invalid listing_type rejected' ($mlBadType.Status -in 400,409,422,500) "status=$($mlBadType.Status)"

# 9) A toggle inactive
if ($ml1Id) {
    $toggleMLA = Invoke-Supa 'PATCH' "/rest/v1/market_listings?id=eq.$ml1Id" @{
        Authorization = "Bearer $tokA"
    } @{ is_active = $false }

    $activeAfter = Invoke-Supa 'GET' '/rest/v1/market_listings?is_active=eq.true&select=id' @{ Authorization = "Bearer $tokB" } $null
    $stillActive = $true
    if (-not $activeAfter.Error -and $activeAfter.Body) {
        try {
            $arr = $activeAfter.Body | ConvertFrom-Json
            $stillActive = (@($arr | Where-Object { $_.id -eq $ml1Id })).Count -ge 1
        } catch { }
    }
    Record-Result 'MarketListing: A toggle inactive hides from public' (-not $stillActive) "patch_status=$($toggleMLA.Status) stillActive=$stillActive"
}

# 10) A delete own listing
if ($ml1Id) {
    $delMLA = Invoke-Supa 'DELETE' "/rest/v1/market_listings?id=eq.$ml1Id" @{ Authorization = "Bearer $tokA" } $null
    Record-Result 'MarketListing: A deletes own listing' ($delMLA.Status -eq 204) "status=$($delMLA.Status)"
}

# ============================================================
# Cleanup
# ============================================================
$delUA = Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userAId" @{ Authorization = "Bearer $adminKey" } $null
Record-Result 'Cleanup: delete user A (CASCADE)' ($delUA.Status -in 200,204) "status=$($delUA.Status)"

$delUB = Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userBId" @{ Authorization = "Bearer $adminKey" } $null
Record-Result 'Cleanup: delete user B (CASCADE)' ($delUB.Status -in 200,204) "status=$($delUB.Status)"

# ============================================================
# Output
# ============================================================
Write-Host ""
Write-Host "===== REAL FEATURES LIVE SMOKE RESULTS ====="
$results | Format-Table -AutoSize Name, Status, Detail
$failed = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count
Write-Host ""
Write-Host "TOTAL: $($results.Count) | FAIL: $failed"
if ($failed -eq 0) {
    Write-Host "ALL PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed FAILED" -ForegroundColor Red
    exit 1
}
