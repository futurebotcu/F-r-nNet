#Requires -Version 5.1
# FirinNet - Live smoke: job_messaging V1 (job_conversations + job_messages).
#
# Akis:
#   1. .env.admin.local'dan SUPABASE_URL + service_role oku.
#   2. Uc gecici test user yarat (A, B, C).
#   3. Sign-in -> her birine user JWT.
#   4. A: job_offer_posts insert (Usta Araniyor)
#   5. B: kendi job_offer aktif listede goruyor mu
#   6. B: A'nin offer'i icin conversation + first message acar
#   7. A: conversations listele -> convo gorur, ilk mesaj orada
#   8. A: reply mesaj gonderir
#   9. B: mesajlari listele -> 2 mesaj
#   10. C: A'nin conversation'ini okuyamaz (RLS deny)
#   11. C: B'nin conversation'ina mesaj atamaz (RLS deny)
#   12. B: C'yi recipient olarak forged convo acmaya calisir (C post sahibi degil) -> 403
#   13. B: job_seek_posts insert (Is Ariyorum)
#   14. A: B'nin job_seek'i icin convo + first message
#   15. B: A'nin job_seek convo'sunu listede gorur
#   16. A: convo'yu close eder
#   17. A: closed convo'ya mesaj atamaz (RLS deny - status='open' check)
#   18. Cleanup: A/B/C delete -> CASCADE.
#   19. MCP residue check.

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
$pwC = [Guid]::NewGuid().ToString('N')
$emailA = "firinnet_smoke_jm_a_$ts@example.com"
$emailB = "firinnet_smoke_jm_b_$ts@example.com"
$emailC = "firinnet_smoke_jm_c_$ts@example.com"

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

$createC = Invoke-Supa 'POST' '/auth/v1/admin/users' @{ Authorization = "Bearer $adminKey" } @{
    email = $emailC; password = $pwC; email_confirm = $true
}
$userCId = Get-ReturnedId $createC
Record-Result 'Auth: create user C' ($null -ne $userCId) "status=$($createC.Status)"

if (-not $userAId -or -not $userBId -or -not $userCId) {
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

$signC = Invoke-Supa 'POST' '/auth/v1/token?grant_type=password' @{} @{ email = $emailC; password = $pwC }
$tokC = $null
if (-not $signC.Error -and $signC.Body) {
    try { $tokC = ($signC.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Auth: sign-in C' ($null -ne $tokC) "status=$($signC.Status)"

if (-not $tokA -or -not $tokB -or -not $tokC) {
    [void](Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userAId" @{ Authorization = "Bearer $adminKey" } $null)
    [void](Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userBId" @{ Authorization = "Bearer $adminKey" } $null)
    [void](Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userCId" @{ Authorization = "Bearer $adminKey" } $null)
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

$hAins = @{ Authorization = "Bearer $tokA"; Prefer = 'return=representation' }
$hBins = @{ Authorization = "Bearer $tokB"; Prefer = 'return=representation' }
$hCins = @{ Authorization = "Bearer $tokC"; Prefer = 'return=representation' }

# ============================================================
# JOB_OFFER PATH (A posts, B applies, C unauthorized)
# ============================================================

# 1) A creates job_offer
$jo = Invoke-Supa 'POST' '/rest/v1/job_offer_posts' $hAins @{
    owner_id = $userAId
    title = "Usta Araniyor Smoke $ts"
    role_title = 'Ekmek Ustasi'
    city = 'Ankara'
    is_active = $true
}
$joId = Get-ReturnedId $jo
Record-Result 'JobOffer: A insert own' ($null -ne $joId) "status=$($jo.Status)"

# 2) B starts conversation for A's offer
$bConvo = $null
$bConvoId = $null
if ($joId) {
    $bConvo = Invoke-Supa 'POST' '/rest/v1/job_conversations' $hBins @{
        related_type = 'job_offer'
        job_offer_id = $joId
        initiator_id = $userBId
        recipient_id = $userAId
        status = 'open'
    }
    $bConvoId = Get-ReturnedId $bConvo
    Record-Result 'JobOffer convo: B initiates' ($null -ne $bConvoId) "status=$($bConvo.Status)"
}

# 3) B sends first message
if ($bConvoId) {
    $bMsg1 = Invoke-Supa 'POST' '/rest/v1/job_messages' $hBins @{
        conversation_id = $bConvoId
        sender_id = $userBId
        body = "Merhaba, basvurmak istiyorum. $ts"
    }
    Record-Result 'JobOffer msg: B first message' ($bMsg1.Status -in 200,201) "status=$($bMsg1.Status)"
}

# 4) A lists conversations - should see B's convo
$aConvos = Invoke-Supa 'GET' "/rest/v1/job_conversations?select=id,initiator_id,recipient_id,status" @{ Authorization = "Bearer $tokA" } $null
$aSeesConvo = $false
if (-not $aConvos.Error -and $aConvos.Body) {
    try {
        $arr = $aConvos.Body | ConvertFrom-Json
        $aSeesConvo = (@($arr | Where-Object { $_.id -eq $bConvoId })).Count -ge 1
    } catch { }
}
Record-Result 'JobOffer convo: A sees B initiated convo' $aSeesConvo "status=$($aConvos.Status)"

# 5) A reads messages
if ($bConvoId) {
    $aMsgs = Invoke-Supa 'GET' "/rest/v1/job_messages?conversation_id=eq.$bConvoId&select=id,body,sender_id" @{ Authorization = "Bearer $tokA" } $null
    $aSeesMsg = $false
    if (-not $aMsgs.Error -and $aMsgs.Body) {
        try {
            $arr = $aMsgs.Body | ConvertFrom-Json
            $aSeesMsg = ($arr.Count -eq 1 -and $arr[0].sender_id -eq $userBId)
        } catch { }
    }
    Record-Result 'JobOffer msg: A sees B message' $aSeesMsg "status=$($aMsgs.Status)"
}

# 6) A replies
if ($bConvoId) {
    $aReply = Invoke-Supa 'POST' '/rest/v1/job_messages' $hAins @{
        conversation_id = $bConvoId
        sender_id = $userAId
        body = "Tesekkurler, gorusebiliriz. $ts"
    }
    Record-Result 'JobOffer msg: A reply' ($aReply.Status -in 200,201) "status=$($aReply.Status)"
}

# 7) B reads (should see 2 messages)
if ($bConvoId) {
    $bMsgs = Invoke-Supa 'GET' "/rest/v1/job_messages?conversation_id=eq.$bConvoId&select=id,sender_id" @{ Authorization = "Bearer $tokB" } $null
    $count2 = $false
    if (-not $bMsgs.Error -and $bMsgs.Body) {
        try { $count2 = (($bMsgs.Body | ConvertFrom-Json).Count -eq 2) } catch { }
    }
    Record-Result 'JobOffer msg: B reads 2 messages' $count2 "status=$($bMsgs.Status)"
}

# 8) C cannot READ A/B conversation - empty list
$cConvos = Invoke-Supa 'GET' "/rest/v1/job_conversations?select=id" @{ Authorization = "Bearer $tokC" } $null
$cListEmpty = $false
if (-not $cConvos.Error -and $cConvos.Body) {
    try {
        $arr = $cConvos.Body | ConvertFrom-Json
        $cListEmpty = (@($arr | Where-Object { $_.id -eq $bConvoId })).Count -eq 0
    } catch { }
}
Record-Result 'JobOffer convo: C cannot read (not participant)' $cListEmpty "status=$($cConvos.Status)"

# 9) C cannot read messages in A/B convo - RLS empty result
if ($bConvoId) {
    $cMsgs = Invoke-Supa 'GET' "/rest/v1/job_messages?conversation_id=eq.$bConvoId&select=id" @{ Authorization = "Bearer $tokC" } $null
    $cMsgsEmpty = $false
    if (-not $cMsgs.Error -and $cMsgs.Body) {
        try { $cMsgsEmpty = (($cMsgs.Body | ConvertFrom-Json).Count -eq 0) } catch { }
    }
    Record-Result 'JobOffer msg: C cannot read (RLS empty)' $cMsgsEmpty "status=$($cMsgs.Status)"
}

# 10) C cannot insert message in A/B convo - 403
if ($bConvoId) {
    $cForgedMsg = Invoke-Supa 'POST' '/rest/v1/job_messages' $hCins @{
        conversation_id = $bConvoId
        sender_id = $userCId
        body = "Hacked by C $ts"
    }
    Record-Result 'JobOffer msg: C cannot insert (cross-convo)' ($cForgedMsg.Status -in 401,403) "status=$($cForgedMsg.Status)"
}

# 11) B cannot forge convo with C as recipient (C is not owner of any post)
$bForgedConvo = Invoke-Supa 'POST' '/rest/v1/job_conversations' $hBins @{
    related_type = 'job_offer'
    job_offer_id = $joId
    initiator_id = $userBId
    recipient_id = $userCId
    status = 'open'
}
Record-Result 'JobOffer convo: B cannot forge recipient=C' ($bForgedConvo.Status -in 401,403) "status=$($bForgedConvo.Status)"

# 12) B cannot self-target conversation (initiator = recipient = B)
$bSelfConvo = Invoke-Supa 'POST' '/rest/v1/job_conversations' $hBins @{
    related_type = 'job_offer'
    job_offer_id = $joId
    initiator_id = $userBId
    recipient_id = $userBId
    status = 'open'
}
Record-Result 'JobOffer convo: B cannot self-target' ($bSelfConvo.Status -in 400,401,403,409) "status=$($bSelfConvo.Status)"

# ============================================================
# JOB_SEEK PATH (B posts, A initiates contact)
# ============================================================

# 13) B creates job_seek
$js = Invoke-Supa 'POST' '/rest/v1/job_seek_posts' $hBins @{
    owner_id = $userBId
    title = "Is Ariyorum Smoke $ts"
    city = 'Istanbul'
    is_active = $true
}
$jsId = Get-ReturnedId $js
Record-Result 'JobSeek: B insert own' ($null -ne $jsId) "status=$($js.Status)"

# 14) A starts convo for B's job_seek
$aConvoSeek = $null
$aConvoSeekId = $null
if ($jsId) {
    $aConvoSeek = Invoke-Supa 'POST' '/rest/v1/job_conversations' $hAins @{
        related_type = 'job_seek'
        job_seek_post_id = $jsId
        initiator_id = $userAId
        recipient_id = $userBId
        status = 'open'
    }
    $aConvoSeekId = Get-ReturnedId $aConvoSeek
    Record-Result 'JobSeek convo: A initiates' ($null -ne $aConvoSeekId) "status=$($aConvoSeek.Status)"
}

# 15) A sends first message
if ($aConvoSeekId) {
    $aFirstMsg = Invoke-Supa 'POST' '/rest/v1/job_messages' $hAins @{
        conversation_id = $aConvoSeekId
        sender_id = $userAId
        body = "Bizimle calismak ister misin? $ts"
    }
    Record-Result 'JobSeek msg: A first message' ($aFirstMsg.Status -in 200,201) "status=$($aFirstMsg.Status)"
}

# 16) B sees the convo
$bConvosAfter = Invoke-Supa 'GET' "/rest/v1/job_conversations?select=id" @{ Authorization = "Bearer $tokB" } $null
$bSeesSeekConvo = $false
if (-not $bConvosAfter.Error -and $bConvosAfter.Body) {
    try {
        $arr = $bConvosAfter.Body | ConvertFrom-Json
        $bSeesSeekConvo = (@($arr | Where-Object { $_.id -eq $aConvoSeekId })).Count -ge 1
    } catch { }
}
Record-Result 'JobSeek convo: B sees A initiated convo' $bSeesSeekConvo "status=$($bConvosAfter.Status)"

# ============================================================
# Close conversation + closed-write deny
# ============================================================

# 17) A closes the offer convo
if ($bConvoId) {
    $closeResp = Invoke-Supa 'PATCH' "/rest/v1/job_conversations?id=eq.$bConvoId" @{ Authorization = "Bearer $tokA" } @{ status = 'closed' }
    $verifyClose = Invoke-Supa 'GET' "/rest/v1/job_conversations?id=eq.$bConvoId&select=status" @{ Authorization = "Bearer $tokA" } $null
    $isClosed = $false
    if (-not $verifyClose.Error -and $verifyClose.Body) {
        try {
            $arr = $verifyClose.Body | ConvertFrom-Json
            $isClosed = ($arr.Count -ge 1 -and $arr[0].status -eq 'closed')
        } catch { }
    }
    Record-Result 'Close convo: A closes own offer convo' $isClosed "patch_status=$($closeResp.Status) closed=$isClosed"
}

# 18) B cannot insert message in closed convo
if ($bConvoId) {
    $bClosedMsg = Invoke-Supa 'POST' '/rest/v1/job_messages' $hBins @{
        conversation_id = $bConvoId
        sender_id = $userBId
        body = "Closed convo write $ts"
    }
    Record-Result 'Close convo: B cannot write to closed' ($bClosedMsg.Status -in 401,403) "status=$($bClosedMsg.Status)"
}

# 19) Dedup: B cannot create second convo for same offer (partial unique index)
if ($joId) {
    $bDup = Invoke-Supa 'POST' '/rest/v1/job_conversations' $hBins @{
        related_type = 'job_offer'
        job_offer_id = $joId
        initiator_id = $userBId
        recipient_id = $userAId
        status = 'open'
    }
    Record-Result 'Dedup: B cannot create 2nd convo for same offer' ($bDup.Status -in 400,409,500) "status=$($bDup.Status)"
}

# ============================================================
# Cleanup
# ============================================================
$delUA = Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userAId" @{ Authorization = "Bearer $adminKey" } $null
Record-Result 'Cleanup: delete user A (CASCADE)' ($delUA.Status -in 200,204) "status=$($delUA.Status)"

$delUB = Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userBId" @{ Authorization = "Bearer $adminKey" } $null
Record-Result 'Cleanup: delete user B (CASCADE)' ($delUB.Status -in 200,204) "status=$($delUB.Status)"

$delUC = Invoke-Supa 'DELETE' "/auth/v1/admin/users/$userCId" @{ Authorization = "Bearer $adminKey" } $null
Record-Result 'Cleanup: delete user C (CASCADE)' ($delUC.Status -in 200,204) "status=$($delUC.Status)"

# ============================================================
# Output
# ============================================================
Write-Host ""
Write-Host "===== JOB MESSAGING LIVE SMOKE RESULTS ====="
$results | Format-Table -AutoSize Name, Status, Detail
$failed = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
Write-Host ""
Write-Host "TOTAL: $($results.Count) | FAIL: $failed"
if ($failed -eq 0) {
    Write-Host "ALL PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed FAILED" -ForegroundColor Red
    exit 1
}
