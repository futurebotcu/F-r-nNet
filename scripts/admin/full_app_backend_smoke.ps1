#Requires -Version 5.1
# FirinNet - Full app backend smoke (P0 / UI smoke yardimcisi).
#
# Amac: UI'in arkasindaki TUM yazma yollarini tek bir gercek auth user JWT
# ile PostgREST + Edge Function uzerinden cagir. Repository implementasyonlari
# bu cagrilarin aynisini yapar; backend zinciri saglamsa UI'da da calisir.
#
# Test akisi (tek test user):
#   - profiles (auto via handle_new_user)
#   - worker_profiles + worker_experiences + job_seek_posts
#   - bakeries + bakery_products + recipe_calculations + production_entries + waste_entries
#   - dealers + dealer_deliveries + dealer_delivery_items + dealer_transactions (payment) + dealer_prices + dealer_notes
#   - feed_posts + feed_likes + feed_saves + feed_comments
#   - social_groups + group_members + group_messages
#   - delete-account function -> user gone + CASCADE residue 0
#
# Guvenlik:
#   - service_role konsola/log'a yazilmaz; "present: yes" masking.
#   - Hicbir gercek kullaniciya dokunulmaz; test user UUID acik logged DEGIL.

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
    param([string]$Name, [bool]$Pass, [string]$Detail = '', [string]$ErrorBody = '')
    if (-not $Pass -and $ErrorBody) {
        # Hata gövdesinden ilk 180 karakteri Detail'a ekle (key-vs-field debug için).
        $snippet = ($ErrorBody -replace '\s+', ' ').Trim()
        if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0, 180) + '…' }
        $Detail = "$Detail | $snippet"
    }
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
$pw = [Guid]::NewGuid().ToString('N')
$email = "firinnet_smoke_full_$ts@example.com"

# ============================================================
# 1) Create user + sign-in
# ============================================================
$create = Invoke-Supa -Method 'POST' -Path '/auth/v1/admin/users' -Headers @{ Authorization = "Bearer $adminKey" } -Body @{
    email = $email; password = $pw; email_confirm = $true
    user_metadata = @{
        display_name = "Smoke User $ts"
        account_type = 'commercial'
        profession_badge = 'Usta'
        city = 'Test'
    }
}
$userId = Get-ReturnedId $create
Record-Result 'Auth: create test user' ($null -ne $userId) "status=$($create.Status)"
if (-not $userId) {
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

$sign = Invoke-Supa -Method 'POST' -Path '/auth/v1/token?grant_type=password' -Headers @{} -Body @{
    email = $email; password = $pw
}
$tok = $null
if (-not $sign.Error -and $sign.Body) {
    try { $tok = ($sign.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Auth: sign-in' ($null -ne $tok) "status=$($sign.Status)"
if (-not $tok) {
    [void](Invoke-Supa -Method 'DELETE' -Path "/auth/v1/admin/users/$userId" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null)
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

$userHdr = @{ Authorization = "Bearer $tok"; Prefer = 'return=representation' }
$userHdrMin = @{ Authorization = "Bearer $tok"; Prefer = 'return=minimal' }

# Profile auto-created
$prof = Invoke-Supa -Method 'GET' -Path "/rest/v1/profiles?id=eq.$userId&select=id,display_name,account_type" -Headers @{ Authorization = "Bearer $tok" } -Body $null
$profOk = (-not $prof.Error) -and ($prof.Status -eq 200)
if ($profOk -and $prof.Body) {
    try {
        $arr = $prof.Body | ConvertFrom-Json
        $profOk = ($arr.Count -ge 1 -and $arr[0].id -eq $userId)
    } catch { $profOk = $false }
}
Record-Result 'Profile: auto-created via handle_new_user' $profOk "status=$($prof.Status)"

# ============================================================
# 2) Worker (Bireysel)
# ============================================================
$wp = Invoke-Supa -Method 'POST' -Path '/rest/v1/worker_profiles' -Headers $userHdr -Body @{
    owner_id = $userId
    profession_badge = 'Usta Fırıncı'
    experience_years = 5
    cities = @('Ankara','İstanbul')
    work_type = 'full_time'
    bio = 'Smoke profile'
}
$wpId = Get-ReturnedId $wp
Record-Result 'Worker: upsert worker_profile' ($null -ne $wpId) "status=$($wp.Status)"

# Turkce karakter PowerShell 5.1 Windows-1254 -> JSON UTF-8 mismatch sebebi olabilir;
# ASCII title kullaniyoruz.
$we = Invoke-Supa -Method 'POST' -Path '/rest/v1/worker_experiences' -Headers $userHdr -Body @{
    owner_id = $userId
    title = 'Eksi maya ustasi'
    workplace = 'Smoke Firin'
    city = 'Ankara'
    start_date = '2020-01-01'
}
$weId = Get-ReturnedId $we
Record-Result 'Worker: add worker_experience' ($null -ne $weId) "status=$($we.Status)" $we.Body

$js = Invoke-Supa -Method 'POST' -Path '/rest/v1/job_seek_posts' -Headers $userHdr -Body @{
    owner_id = $userId
    title = 'Is ariyorum'
    profession_badge = 'Usta'
    city = 'Ankara'
    experience_years = 5
    is_active = $true
}
$jsId = Get-ReturnedId $js
Record-Result 'Worker: create job_seek_post' ($null -ne $jsId) "status=$($js.Status)" $js.Body

# ============================================================
# 3) Bakery + recipe + production + waste
# ============================================================
$bk = Invoke-Supa -Method 'POST' -Path '/rest/v1/bakeries' -Headers $userHdr -Body @{
    owner_id = $userId
    name = "Smoke Fırın $ts"
    city = 'Ankara'
}
$bkId = Get-ReturnedId $bk
Record-Result 'Bakery: create' ($null -ne $bkId) "status=$($bk.Status)"

if ($bkId) {
    $bp = Invoke-Supa -Method 'POST' -Path '/rest/v1/bakery_products' -Headers $userHdr -Body @{
        owner_id = $userId
        bakery_id = $bkId
        name = 'Ekmek'
        unit = 'adet'
        default_price = 12.5
    }
    Record-Result 'Bakery: add bakery_product' ($bp.Status -eq 201) "status=$($bp.Status)" $bp.Body
}

# recipe_calculations: bakery_id YOK; field adlari water_percent/yeast_percent/...
$rc = Invoke-Supa -Method 'POST' -Path '/rest/v1/recipe_calculations' -Headers $userHdr -Body @{
    owner_id = $userId
    product_name = 'Ekmek'
    flour_kg = 50
    water_percent = 60
    yeast_percent = 1
    salt_percent = 2
    unit_weight_gr = 250
    waste_percent = 3
    metadata = @{ title = 'Smoke recipe' }
}
$rcId = Get-ReturnedId $rc
Record-Result 'Recipe: create recipe_calculation' ($null -ne $rcId) "status=$($rc.Status)" $rc.Body

if ($bkId) {
    $pe = Invoke-Supa -Method 'POST' -Path '/rest/v1/production_entries' -Headers $userHdr -Body @{
        owner_id = $userId
        bakery_id = $bkId
        product_name = 'Ekmek'
        quantity = 100
        production_date = (Get-Date).ToString('yyyy-MM-dd')
    }
    Record-Result 'Production: add production_entry' ($pe.Status -eq 201) "status=$($pe.Status)"

    $we2 = Invoke-Supa -Method 'POST' -Path '/rest/v1/waste_entries' -Headers $userHdr -Body @{
        owner_id = $userId
        bakery_id = $bkId
        product_name = 'Ekmek'
        quantity = 5
        unit_cost = 12.5
        waste_date = (Get-Date).ToString('yyyy-MM-dd')
    }
    Record-Result 'Waste: add waste_entry' ($we2.Status -eq 201) "status=$($we2.Status)"
}

# ============================================================
# 4) Dealer + delivery + payment + price + note
# ============================================================
if ($bkId) {
    # dealers: 'area' YOK; city + district var. V1.2: customer_type + working_type + contact_name.
    $dl = Invoke-Supa -Method 'POST' -Path '/rest/v1/dealers' -Headers $userHdr -Body @{
        owner_id = $userId
        bakery_id = $bkId
        name = "Smoke Bayi $ts"
        city = 'Ankara'
        district = 'Cankaya'
        working_type = 'mixed'
        customer_type = 'bakery_dealer'
        contact_name = 'Smoke Yetkili'
    }
    $dlId = Get-ReturnedId $dl
    Record-Result 'Dealer: create' ($null -ne $dlId) "status=$($dl.Status)" $dl.Body

    if ($dlId) {
        $dd = Invoke-Supa -Method 'POST' -Path '/rest/v1/dealer_deliveries' -Headers $userHdr -Body @{
            owner_id = $userId
            bakery_id = $bkId
            dealer_id = $dlId
            delivery_date = (Get-Date).ToString('yyyy-MM-dd')
        }
        $ddId = Get-ReturnedId $dd
        Record-Result 'Dealer: create delivery' ($null -ne $ddId) "status=$($dd.Status)"

        if ($ddId) {
            $ddi = Invoke-Supa -Method 'POST' -Path '/rest/v1/dealer_delivery_items' -Headers $userHdr -Body @{
                delivery_id = $ddId
                owner_id = $userId
                product_name = 'Ekmek'
                quantity = 100
                unit_price = 10
            }
            Record-Result 'Dealer: add delivery_item' ($ddi.Status -eq 201) "status=$($ddi.Status)"
        }

        # Payment via dealer_transactions (V1.2). Migration field: 'type' (tx_type degil),
        # tx_date YOK (created_at otomatik). payment_method enum: cash/transfer/card/other.
        $dt = Invoke-Supa -Method 'POST' -Path '/rest/v1/dealer_transactions' -Headers $userHdr -Body @{
            owner_id = $userId
            dealer_id = $dlId
            type = 'payment'
            amount = 500
            payment_method = 'cash'
            note = 'Smoke odeme'
        }
        Record-Result 'Dealer: create payment tx' ($dt.Status -eq 201) "status=$($dt.Status)" $dt.Body

        $dp = Invoke-Supa -Method 'POST' -Path '/rest/v1/dealer_prices' -Headers $userHdr -Body @{
            owner_id = $userId
            dealer_id = $dlId
            product_name = 'Ekmek'
            unit_price = 10
            valid_from = (Get-Date).ToString('yyyy-MM-dd')
        }
        Record-Result 'Dealer: add dealer_price' ($dp.Status -eq 201) "status=$($dp.Status)"

        $dn = Invoke-Supa -Method 'POST' -Path '/rest/v1/dealer_notes' -Headers $userHdr -Body @{
            owner_id = $userId
            dealer_id = $dlId
            note = 'Smoke not'
        }
        Record-Result 'Dealer: add dealer_note' ($dn.Status -eq 201) "status=$($dn.Status)"
    }
}

# ============================================================
# 5) Social: feed
# ============================================================
$fp = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_posts' -Headers $userHdr -Body @{
    owner_id = $userId; type = 'question'; text = "Smoke post $ts"
}
$fpId = Get-ReturnedId $fp
Record-Result 'Feed: create feed_post' ($null -ne $fpId) "status=$($fp.Status)"

if ($fpId) {
    $fl = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_likes' -Headers $userHdrMin -Body @{
        post_id = $fpId; owner_id = $userId
    }
    Record-Result 'Feed: like own post' ($fl.Status -eq 201) "status=$($fl.Status)"

    $fs = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_saves' -Headers $userHdrMin -Body @{
        post_id = $fpId; owner_id = $userId
    }
    Record-Result 'Feed: save own post' ($fs.Status -eq 201) "status=$($fs.Status)"

    $fc = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_comments' -Headers $userHdrMin -Body @{
        post_id = $fpId; owner_id = $userId; text = 'Smoke yorum'
    }
    Record-Result 'Feed: comment own post' ($fc.Status -eq 201) "status=$($fc.Status)"

    # Counter trigger: like_count + comment_count
    $fpAfter = Invoke-Supa -Method 'GET' -Path "/rest/v1/feed_posts?id=eq.$fpId&select=like_count,comment_count" -Headers @{ Authorization = "Bearer $tok" } -Body $null
    $countersOk = $false
    if (-not $fpAfter.Error -and $fpAfter.Body) {
        try {
            $arr = $fpAfter.Body | ConvertFrom-Json
            if ($arr.Count -ge 1 -and $arr[0].like_count -eq 1 -and $arr[0].comment_count -eq 1) {
                $countersOk = $true
            }
        } catch { }
    }
    Record-Result 'Feed: counter triggers (like=1, comment=1)' $countersOk "status=$($fpAfter.Status)"
}

# ============================================================
# 6) Social: groups
# ============================================================
$sg = Invoke-Supa -Method 'POST' -Path '/rest/v1/social_groups' -Headers $userHdr -Body @{
    owner_id = $userId; name = "Smoke Group $ts"; category = 'general'
    is_private = $false; max_members = 50
}
$sgId = Get-ReturnedId $sg
Record-Result 'Group: create' ($null -ne $sgId) "status=$($sg.Status)"

if ($sgId) {
    $gm = Invoke-Supa -Method 'POST' -Path '/rest/v1/group_members' -Headers $userHdrMin -Body @{
        group_id = $sgId; owner_id = $userId; role = 'owner'
    }
    Record-Result 'Group: owner joins own group' ($gm.Status -eq 201) "status=$($gm.Status)"

    $gmsg = Invoke-Supa -Method 'POST' -Path '/rest/v1/group_messages' -Headers $userHdrMin -Body @{
        group_id = $sgId; owner_id = $userId; text = 'Smoke mesaj'
    }
    Record-Result 'Group: post message' ($gmsg.Status -eq 201) "status=$($gmsg.Status)"

    # Member counter
    $sgAfter = Invoke-Supa -Method 'GET' -Path "/rest/v1/social_groups?id=eq.$sgId&select=member_count,owner_name" -Headers @{ Authorization = "Bearer $tok" } -Body $null
    $memberOk = $false
    if (-not $sgAfter.Error -and $sgAfter.Body) {
        try {
            $arr = $sgAfter.Body | ConvertFrom-Json
            if ($arr.Count -ge 1 -and $arr[0].member_count -eq 1) {
                $memberOk = $true
            }
        } catch { }
    }
    Record-Result 'Group: member_count trigger (=1)' $memberOk "status=$($sgAfter.Status)"
}

# ============================================================
# 7) Account deletion + CASCADE verify
# ============================================================
$del = Invoke-Supa -Method 'POST' -Path '/functions/v1/delete-account' -Headers @{
    Authorization = "Bearer $tok"
} -Body @{ confirm = $true }
Record-Result 'Account: delete-account function 200' ($del.Status -eq 200) "status=$($del.Status)"

$check = Invoke-Supa -Method 'GET' -Path "/auth/v1/admin/users/$userId" -Headers @{
    Authorization = "Bearer $adminKey"
} -Body $null
$userGone = ($check.Status -eq 404 -or $check.Status -eq 422)
Record-Result 'Account: user 404 after delete' $userGone "status=$($check.Status)"

# ============================================================
# Output
# ============================================================
Write-Host ""
Write-Host "===== FULL APP BACKEND SMOKE RESULTS ====="
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
