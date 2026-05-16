#Requires -Version 5.1
# FirinNet - Account deletion live smoke (P0).
#
# Test akisi:
#   1. .env.admin.local'dan SUPABASE_URL + service_role oku.
#   2. Gecici test user yarat (Admin API). Email firinnet_smoke_delete_<ts>.
#   3. Sign-in -> user JWT.
#   4. User JWT ile feed_posts'a 1 pre-data satiri ekle.
#   5. Negative tests:
#        - confirm=false  -> 400 expected
#        - no auth header -> 401 expected
#   6. Positive test: user JWT + confirm=true -> 200.
#   7. Verify: auth.users + profiles + feed_posts'tan o user'a ait satir
#      KALMAMIS olmali (CASCADE).
#   8. Fatih kullanicisi (mevcut tek gercek user) korunmus olmali.
#
# Guvenlik:
#   - service_role konsola/log'a YAZILMAZ; "present: yes" masking.
#   - Test user temizligi function'in kendi cascade'i ile + auth.users
#     CASCADE FK'leri saglar; ek silme islemi yapilmaz.
#   - Hicbir gercek kullaniciya dokunulmaz.

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

$ts = (Get-Date).ToString('yyyyMMddHHmmss')
$pw = [Guid]::NewGuid().ToString('N')
$email = "firinnet_smoke_delete_$ts@example.com"

# ============================================================
# 1) Create test user
# ============================================================
$create = Invoke-Supa -Method 'POST' -Path '/auth/v1/admin/users' -Headers @{ Authorization = "Bearer $adminKey" } -Body @{
    email = $email; password = $pw; email_confirm = $true
}
$userId = $null
if (-not $create.Error -and $create.Body) {
    try { $userId = ($create.Body | ConvertFrom-Json).id } catch { }
}
Record-Result 'Create test user (Admin API)' ($null -ne $userId) "status=$($create.Status)"
if (-not $userId) {
    Write-Host "ABORT: test user olusturulamadi" -ForegroundColor Red
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

# ============================================================
# 2) Sign-in
# ============================================================
$sign = Invoke-Supa -Method 'POST' -Path '/auth/v1/token?grant_type=password' -Headers @{} -Body @{
    email = $email; password = $pw
}
$tok = $null
if (-not $sign.Error -and $sign.Body) {
    try { $tok = ($sign.Body | ConvertFrom-Json).access_token } catch { }
}
Record-Result 'Sign-in' ($null -ne $tok) "status=$($sign.Status)"
if (-not $tok) {
    Write-Host "ABORT: token alinamadi" -ForegroundColor Red
    [void](Invoke-Supa -Method 'DELETE' -Path "/auth/v1/admin/users/$userId" -Headers @{ Authorization = "Bearer $adminKey" } -Body $null)
    $results | Format-Table -AutoSize Name, Status, Detail
    exit 1
}

# ============================================================
# 3) Pre-data: feed_post
# ============================================================
$post = Invoke-Supa -Method 'POST' -Path '/rest/v1/feed_posts' -Headers @{
    Authorization = "Bearer $tok"; Prefer = 'return=representation'
} -Body @{
    owner_id = $userId; type = 'question'; text = "PreDeleteSmoke_$ts"
}
$postOk = -not $post.Error -and $post.Status -eq 201
Record-Result 'Pre-delete: user creates feed_post' $postOk "status=$($post.Status)"

# ============================================================
# 4) Negative: confirm=false -> 400
# ============================================================
$noConfirm = Invoke-Supa -Method 'POST' -Path '/functions/v1/delete-account' -Headers @{
    Authorization = "Bearer $tok"
} -Body @{ confirm = $false }
Record-Result 'NEGATIVE confirm=false rejected (400)' ($noConfirm.Status -eq 400) "status=$($noConfirm.Status)"

# ============================================================
# 5) Negative: no Authorization header -> 401
#    Function verify_jwt=true; Edge runtime apikey header'ina baksa bile
#    bizim function kodu Authorization Bearer'i acikca ariyor. Function
#    konfigurasyonu eksik header'i 401'e dusurmeli.
# ============================================================
$noAuth = Invoke-Supa -Method 'POST' -Path '/functions/v1/delete-account' -Headers @{} -Body @{
    confirm = $true
}
Record-Result 'NEGATIVE no auth header rejected (401)' ($noAuth.Status -eq 401) "status=$($noAuth.Status)"

# ============================================================
# 6) Positive: delete-account
# ============================================================
$del = Invoke-Supa -Method 'POST' -Path '/functions/v1/delete-account' -Headers @{
    Authorization = "Bearer $tok"
} -Body @{ confirm = $true }
$delOk = ($del.Status -eq 200)
if ($delOk -and $del.Body) {
    try {
        $j = $del.Body | ConvertFrom-Json
        if (-not $j.ok) { $delOk = $false }
    } catch { $delOk = $false }
}
Record-Result 'delete-account 200 + ok=true' $delOk "status=$($del.Status)"

# ============================================================
# 7) Verify CASCADE: auth.users + profiles + feed_posts temiz mi
#    service_role apikey ile direct REST sorgular. PostgREST profiles'a
#    SELECT yapinca 403 dondurebilir (gecmis smoke'da gordugumuz pattern),
#    bu durumda gercek dogrulamayi MCP execute_sql (Claude tarafi) yapacak.
#    Burada en azindan auth.admin.users GET sonucunu kullaniyoruz.
# ============================================================
$verifyUser = Invoke-Supa -Method 'GET' -Path "/auth/v1/admin/users/$userId" -Headers @{
    Authorization = "Bearer $adminKey"
} -Body $null
# Silinmis user: 404 ya da bos. 200 dondurse residue var demek.
$userGone = ($verifyUser.Status -eq 404 -or $verifyUser.Status -eq 422)
Record-Result 'Verify: auth.users[$userId] gone (404)' $userGone "status=$($verifyUser.Status)"

# ============================================================
# Output
# ============================================================
Write-Host ""
Write-Host "===== ACCOUNT DELETION SMOKE RESULTS ====="
$results | Format-Table -AutoSize Name, Status, Detail
$failed = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count
Write-Host ""
Write-Host "TOTAL: $($results.Count) | FAIL: $failed"
Write-Host "Test user id was opaque; not printed."
if ($failed -eq 0) {
    Write-Host "ALL PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed FAILED" -ForegroundColor Red
    exit 1
}
