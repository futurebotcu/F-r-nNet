#Requires -Version 5.1
# FirinNet - Cross-user RLS smoke (Admin API + 2 gercek auth user JWT).
#
# Akis:
#   1. .env.admin.local'dan SUPABASE_URL + service_role oku.
#   2. Iki gecici test user yarat (Admin API: /auth/v1/admin/users).
#   3. Her user icin sign-in (/auth/v1/token?grant_type=password) -> access_token.
#   4. User JWT'leri ile PostgREST'e gercek RLS-aktif cagrilar at.
#   5. Negative testler (B'nin A'nin verisine yetkisi yok mu) ve positive testler.
#   6. Cleanup: Admin API ile test user delete -> CASCADE ile profiles/feed/group temiz.
#
# Guvenlik:
#   - Anahtar/key/token konsola basilmaz. Sadece status code'lar.
#   - PATCH/DELETE/INSERT istekleri SADECE script'in yarattigi test verisine.
#   - Gercek kullanici verisine (Fatih vs.) dokunulmaz; cleanup CASCADE sadece yeni user'larin id'si uzerinden.

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
        Uri             = $url
        Method          = $Method
        Headers         = $hdrs
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }
    if ($null -ne $Body) {
        $params['Body']        = ($Body | ConvertTo-Json -Compress -Depth 10)
        $params['ContentType'] = 'application/json'
    }
    try {
        $resp = Invoke-WebRequest @params
        return @{ Status = [int]$resp.StatusCode; Body = $resp.Content; Error = $false }
    } catch {
        $status = 0
        $body = ''
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

$ts = (Get-Date).ToString('yyyyMMddHHmmss')
$pwA = [Guid]::NewGuid().ToString('N')
$pwB = [Guid]::NewGuid().ToString('N')
$emailA = "firinnet_smoke_a_$ts@example.com"
$emailB = "firinnet_smoke_b_$ts@example.com"

# ============================================================
# 1) Create users
# ============================================================
$createA = Invoke-Supa -Method 'POST' -Path '/auth/v1/admin/users' -Headers @{ Authorization = "Bearer $adminKey" } -Body @{
    email = $emailA; password = $pwA; email_confirm = $true
}
$userAId = $null
if (-not $createA.Error -and $createA.Body) {
    try { $userAId = ($createA.Body | ConvertFrom-Json).id } catch { }
}
Record-Result 'Create user A (Admin API)' ($null -ne $userAId) "status=$($createA.Status)"

$createB = Invoke-Supa -Method 'POST' -Path '/auth/v1/admin/users' -Headers @{ Authorization = "Bearer $adminKey" } -Body @{
    email = $emailB; password = $pwB; email_confirm = $true
}
$userBId = $null
if (-not $createB.Error -and $createB.Body) {
    try { $userBId = ($createB.Body | ConvertFrom-Json).id } catch { }
}
Record-Result 'Create user B (Admin API)' ($null -ne $userBId) "status=$($createB.Status)"

if (-not $userAId -or -not $userBId) {
    Write-Host "ABORT: 2 user olusturulamadi" -ForegroundColor Red
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

# ============================================================
# 2) Sign-in
# ============================================================
$signA = Invoke-Supa -Method 'POST' -Path '/auth/v1/token?grant_type=password' -Headers @{} -Body @{ email = $emailA; password = $pwA }
$tokA = $null
if (-not $signA.Error -and $signA.Body) {
    try { $tokA = ($signA.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Sign-in A' ($null -ne $tokA) "status=$($signA.Status)"

$signB = Invoke-Supa -Method 'POST' -Path '/auth/v1/token?grant_type=password' -Headers @{} -Body @{ email = $emailB; password = $pwB }
$tokB = $null
if (-not $signB.Error -and $signB.Body) {
    try { $tokB = ($signB.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Sign-in B' ($null -ne $tokB) "status=$($signB.Status)"

if (-not $tokA -or -not $tokB) {
    Write-Host "ABORT: token alinamadi" -ForegroundColor Red
    [void](Invoke-Supa -Method 'DELETE' -Path "/auth/v1/admin/users/$userAId" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null)
    [void](Invoke-Supa -Method 'DELETE' -Path "/auth/v1/admin/users/$userBId" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null)
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

# ============================================================
# 3) profiles trigger doğrulama (handle_new_user)
# ============================================================
$profA = Invoke-Supa -Method 'GET' -Path "/rest/v1/profiles?id=eq.$userAId&select=id" -Headers @{ Authorization = "Bearer $tokA" } -Body $null
$hasProfA = $false
if (-not $profA.Error -and $profA.Body) {
    try {
        $jp = $profA.Body | ConvertFrom-Json
        if ($jp.Count -ge 1 -and $jp[0].id -eq $userAId) { $hasProfA = $true }
    } catch { }
}
Record-Result 'profiles[A] auto-created (handle_new_user trigger)' $hasProfA "status=$($profA.Status)"

$profB = Invoke-Supa -Method 'GET' -Path "/rest/v1/profiles?id=eq.$userBId&select=id" -Headers @{ Authorization = "Bearer $tokB" } -Body $null
$hasProfB = $false
if (-not $profB.Error -and $profB.Body) {
    try {
        $jp = $profB.Body | ConvertFrom-Json
        if ($jp.Count -ge 1 -and $jp[0].id -eq $userBId) { $hasProfB = $true }
    } catch { }
}
Record-Result 'profiles[B] auto-created (handle_new_user trigger)' $hasProfB "status=$($profB.Status)"

# ============================================================
# 4) User A: grup + üyelik + feed_post
# ============================================================
$grpA = Invoke-Supa -Method 'POST' -Path '/rest/v1/social_groups' -Headers @{
    Authorization = "Bearer $tokA"; Prefer = 'return=representation'
} -Body @{
    owner_id = $userAId; name = "SmokeGroupA_$ts"; category = 'general'; is_private = $false; max_members = 50
}
$groupAId = $null
if (-not $grpA.Error -and $grpA.Body) {
    try {
        $j = $grpA.Body | ConvertFrom-Json
        if ($j.Count -ge 1) { $groupAId = $j[0].id }
    } catch { }
}
Record-Result 'User A creates group (own owner_id)' ($null -ne $groupAId) "status=$($grpA.Status)"

if ($groupAId) {
    $joinA = Invoke-Supa -Method 'POST' -Path '/rest/v1/group_members' -Headers @{
        Authorization = "Bearer $tokA"; Prefer = 'return=minimal'
    } -Body @{ group_id = $groupAId; owner_id = $userAId; role = 'owner' }
    Record-Result 'User A joins own group as owner' ($joinA.Status -in 201,204) "status=$($joinA.Status)"
}

$postA = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_posts' -Headers @{
    Authorization = "Bearer $tokA"; Prefer = 'return=representation'
} -Body @{ owner_id = $userAId; type = 'question'; text = "SmokePostA_$ts" }
$postAId = $null
if (-not $postA.Error -and $postA.Body) {
    try {
        $j = $postA.Body | ConvertFrom-Json
        if ($j.Count -ge 1) { $postAId = $j[0].id }
    } catch { }
}
Record-Result 'User A creates own feed_post' ($null -ne $postAId) "status=$($postA.Status)"

# ============================================================
# 5) NEGATIVE: User B should be rejected
# ============================================================

# P0 fix doğrulama: B üye değilken A'nın grubuna mesaj atamamalı
if ($groupAId) {
    $msgBnonmember = Invoke-Supa -Method 'POST' -Path '/rest/v1/group_messages' -Headers @{
        Authorization = "Bearer $tokB"; Prefer = 'return=minimal'
    } -Body @{ group_id = $groupAId; owner_id = $userBId; text = "ShouldBeRejected_$ts" }
    # P0 fix öncesi 201 dönerdi; fix sonrası 403 (RLS reject)
    Record-Result 'P0 FIX: User B (non-member) cannot insert message to A group' ($msgBnonmember.Status -in 401,403,404) "status=$($msgBnonmember.Status)"
}

# feed_posts forge: B insert with owner_id=A
$forgedFeedB = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_posts' -Headers @{
    Authorization = "Bearer $tokB"
} -Body @{ owner_id = $userAId; type = 'question'; text = "ForgedByB_$ts" }
Record-Result 'User B cannot insert feed_post with owner=A' ($forgedFeedB.Status -in 401,403) "status=$($forgedFeedB.Status)"

# feed_likes forge: B owner=A
if ($postAId) {
    $forgedLikeB = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_likes' -Headers @{
        Authorization = "Bearer $tokB"
    } -Body @{ post_id = $postAId; owner_id = $userAId }
    Record-Result 'User B cannot insert feed_like with owner=A' ($forgedLikeB.Status -in 401,403) "status=$($forgedLikeB.Status)"
}

# feed_saves forge: B owner=A
if ($postAId) {
    $forgedSaveB = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_saves' -Headers @{
        Authorization = "Bearer $tokB"
    } -Body @{ post_id = $postAId; owner_id = $userAId }
    Record-Result 'User B cannot insert feed_save with owner=A' ($forgedSaveB.Status -in 401,403) "status=$($forgedSaveB.Status)"
}

# B PATCH A's feed_post (RLS reject -> 0 rows affected, content unchanged)
if ($postAId) {
    $patchB = Invoke-Supa -Method 'PATCH' -Path "/rest/v1/feed_posts?id=eq.$postAId" -Headers @{
        Authorization = "Bearer $tokB"
    } -Body @{ text = "HackedByB_$ts" }
    $getPost = Invoke-Supa -Method 'GET' -Path "/rest/v1/feed_posts?id=eq.$postAId&select=text" -Headers @{ Authorization = "Bearer $tokA" } -Body $null
    $unchanged = $false
    if (-not $getPost.Error -and $getPost.Body) {
        try {
            $j = $getPost.Body | ConvertFrom-Json
            if ($j.Count -ge 1 -and $j[0].text -eq "SmokePostA_$ts") { $unchanged = $true }
        } catch { }
    }
    Record-Result 'User B cannot UPDATE A feed_post' $unchanged "patch_status=$($patchB.Status) text_unchanged=$unchanged"
}

# B DELETE A's feed_post (RLS reject -> 0 rows affected, post still exists)
if ($postAId) {
    $delTryB = Invoke-Supa -Method 'DELETE' -Path "/rest/v1/feed_posts?id=eq.$postAId" -Headers @{ Authorization = "Bearer $tokB" } -Body $null
    $stillThere = Invoke-Supa -Method 'GET' -Path "/rest/v1/feed_posts?id=eq.$postAId&select=id" -Headers @{ Authorization = "Bearer $tokA" } -Body $null
    $exists = $false
    if (-not $stillThere.Error -and $stillThere.Body) {
        try {
            $j = $stillThere.Body | ConvertFrom-Json
            if ($j.Count -ge 1) { $exists = $true }
        } catch { }
    }
    Record-Result 'User B cannot DELETE A feed_post' $exists "delete_status=$($delTryB.Status) still_exists=$exists"
}

# ============================================================
# 6) POSITIVE
# ============================================================

if ($groupAId) {
    $joinB = Invoke-Supa -Method 'POST' -Path '/rest/v1/group_members' -Headers @{
        Authorization = "Bearer $tokB"; Prefer = 'return=minimal'
    } -Body @{ group_id = $groupAId; owner_id = $userBId; role = 'member' }
    Record-Result 'User B joins public group A (own owner_id)' ($joinB.Status -in 201,204) "status=$($joinB.Status)"
}

if ($groupAId) {
    $msgBmember = Invoke-Supa -Method 'POST' -Path '/rest/v1/group_messages' -Headers @{
        Authorization = "Bearer $tokB"; Prefer = 'return=minimal'
    } -Body @{ group_id = $groupAId; owner_id = $userBId; text = "FromB_member_$ts" }
    Record-Result 'User B (member) CAN insert message to A group' ($msgBmember.Status -in 201,204) "status=$($msgBmember.Status)"
}

$ownFeedB = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_posts' -Headers @{
    Authorization = "Bearer $tokB"; Prefer = 'return=representation'
} -Body @{ owner_id = $userBId; type = 'question'; text = "OwnByB_$ts" }
$postBId = $null
if (-not $ownFeedB.Error -and $ownFeedB.Body) {
    try {
        $j = $ownFeedB.Body | ConvertFrom-Json
        if ($j.Count -ge 1) { $postBId = $j[0].id }
    } catch { }
}
Record-Result 'User B creates own feed_post' ($null -ne $postBId) "status=$($ownFeedB.Status)"

if ($postAId) {
    $likeB = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_likes' -Headers @{
        Authorization = "Bearer $tokB"; Prefer = 'return=minimal'
    } -Body @{ post_id = $postAId; owner_id = $userBId }
    Record-Result 'User B likes A post (own owner_id)' ($likeB.Status -in 201,204) "status=$($likeB.Status)"
}

if ($postAId) {
    $saveB = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_saves' -Headers @{
        Authorization = "Bearer $tokB"; Prefer = 'return=minimal'
    } -Body @{ post_id = $postAId; owner_id = $userBId }
    Record-Result 'User B saves A post (own owner_id)' ($saveB.Status -in 201,204) "status=$($saveB.Status)"
}

# Bonus: User A's feed_post visible to B (authenticated select)
if ($postAId) {
    $bSeesA = Invoke-Supa -Method 'GET' -Path "/rest/v1/feed_posts?id=eq.$postAId&select=id" -Headers @{ Authorization = "Bearer $tokB" } -Body $null
    $sees = $false
    if (-not $bSeesA.Error -and $bSeesA.Body) {
        try {
            $j = $bSeesA.Body | ConvertFrom-Json
            if ($j.Count -ge 1) { $sees = $true }
        } catch { }
    }
    Record-Result 'User B can SEE A feed_post (authenticated select)' $sees "status=$($bSeesA.Status)"
}

# B'nin save'ini A görmemeli (feed_saves_select_self)
$aSeesBSaves = Invoke-Supa -Method 'GET' -Path "/rest/v1/feed_saves?owner_id=eq.$userBId&select=post_id" -Headers @{ Authorization = "Bearer $tokA" } -Body $null
$cantSee = $false
if (-not $aSeesBSaves.Error -and $aSeesBSaves.Body) {
    try {
        $j = $aSeesBSaves.Body | ConvertFrom-Json
        if ($j.Count -eq 0) { $cantSee = $true }
    } catch { }
}
Record-Result 'User A cannot see B feed_saves (select_self)' $cantSee "status=$($aSeesBSaves.Status)"

# ============================================================
# 7) Cleanup
# ============================================================
Write-Host ""
Write-Host "Cleanup: 2 test user delete (CASCADE feed/group/etc)..."

$delA = Invoke-Supa -Method 'DELETE' -Path "/auth/v1/admin/users/$userAId" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null
Record-Result 'Cleanup: delete user A' ($delA.Status -in 200,204) "status=$($delA.Status)"

$delB = Invoke-Supa -Method 'DELETE' -Path "/auth/v1/admin/users/$userBId" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null
Record-Result 'Cleanup: delete user B' ($delB.Status -in 200,204) "status=$($delB.Status)"

$checkProfA = Invoke-Supa -Method 'GET' -Path "/rest/v1/profiles?id=eq.$userAId&select=id" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null
$noProfA = $false
if (-not $checkProfA.Error -and $checkProfA.Body) {
    try { if ((($checkProfA.Body | ConvertFrom-Json)).Count -eq 0) { $noProfA = $true } } catch { }
}
Record-Result 'Cleanup verify: profiles[A] gone (CASCADE)' $noProfA "status=$($checkProfA.Status)"

$checkProfB = Invoke-Supa -Method 'GET' -Path "/rest/v1/profiles?id=eq.$userBId&select=id" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null
$noProfB = $false
if (-not $checkProfB.Error -and $checkProfB.Body) {
    try { if ((($checkProfB.Body | ConvertFrom-Json)).Count -eq 0) { $noProfB = $true } } catch { }
}
Record-Result 'Cleanup verify: profiles[B] gone (CASCADE)' $noProfB "status=$($checkProfB.Status)"

# Yan tablo residual: feed/group/member/message
foreach ($t in 'feed_posts','feed_likes','feed_saves','social_groups','group_members','group_messages') {
    $rA = Invoke-Supa -Method 'GET' -Path "/rest/v1/$t?owner_id=eq.$userAId&select=*" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null
    $rB = Invoke-Supa -Method 'GET' -Path "/rest/v1/$t?owner_id=eq.$userBId&select=*" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null
    $cA = -1; $cB = -1
    if (-not $rA.Error -and $rA.Body) { try { $cA = ($rA.Body | ConvertFrom-Json).Count } catch { } }
    if (-not $rB.Error -and $rB.Body) { try { $cB = ($rB.Body | ConvertFrom-Json).Count } catch { } }
    Record-Result "Cleanup verify: ${t} residue A+B = 0" (($cA -eq 0) -and ($cB -eq 0)) "A=$cA B=$cB"
}

# ============================================================
# Output
# ============================================================
Write-Host ""
Write-Host "===== CROSS-USER RLS SMOKE RESULTS ====="
$results | Format-Table -AutoSize Name, Status, Detail

$failed = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count
$total  = $results.Count
Write-Host ""
Write-Host "TOTAL: $total | FAIL: $failed"
if ($failed -eq 0) {
    Write-Host "ALL PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed FAILED" -ForegroundColor Red
    exit 1
}
