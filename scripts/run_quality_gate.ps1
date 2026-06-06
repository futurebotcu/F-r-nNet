[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Invoke-QualityStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] $Name (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "[PASS] $Name" -ForegroundColor Green
}

Write-Host "FirinNet Release Quality Gate" -ForegroundColor Yellow
Write-Host "Repository: $repoRoot"

Invoke-QualityStep -Name "Flutter analyze" -Command {
    flutter analyze
}

Invoke-QualityStep -Name "Flutter tests" -Command {
    flutter test
}

Invoke-QualityStep -Name "Debug APK build" -Command {
    flutter build apk --debug
}

$maestro = Get-Command maestro -ErrorAction SilentlyContinue
if ($null -eq $maestro) {
    Write-Host ""
    Write-Host "[SKIP] Maestro smoke test" -ForegroundColor Yellow
    Write-Host "Maestro CLI is not installed or is not available on PATH."
    Write-Host "Install it from https://docs.maestro.dev/getting-started/installing-maestro"
    Write-Host "Then start an emulator, install the APK, and run:"
    Write-Host "  maestro test .maestro/app_smoke.yaml"
    Write-Host ""
    Write-Host "Flutter quality gate passed; Maestro was skipped." -ForegroundColor Green
    exit 0
}

Invoke-QualityStep -Name "Maestro app smoke" -Command {
    maestro test .maestro/app_smoke.yaml
}

Write-Host ""
Write-Host "All quality gate steps passed." -ForegroundColor Green
