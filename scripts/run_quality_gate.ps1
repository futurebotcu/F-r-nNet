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

function Invoke-AdvisoryStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Name (advisory)" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] $Name failed (exit code: $LASTEXITCODE)." -ForegroundColor Yellow
        Write-Host "This advisory result does not fail the release quality gate."
        return
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

$patrol = Get-Command patrol -ErrorAction SilentlyContinue
if ($null -eq $patrol) {
    Write-Host ""
    Write-Host "[SKIP] Patrol app smoke" -ForegroundColor Yellow
    Write-Host "Patrol CLI is not installed or is not available on PATH."
    Write-Host "Install it with:"
    Write-Host "  dart pub global activate patrol_cli"
    Write-Host "Then start an emulator and run:"
    Write-Host "  patrol test -t patrol_test/app_smoke_test.dart --no-uninstall"
    Write-Host "  patrol test -t patrol_test/guest_guard_empty_profile_smoke_test.dart --no-uninstall"
    Write-Host "Flutter quality steps remain successful; Patrol was skipped."
} else {
    Write-Host ""
    Write-Host "Patrol environment note: use a cold-booted API 35 or API 36 emulator." -ForegroundColor Yellow
    Write-Host "API 37 preview / 16 KB page-size images are not supported by this quality gate."
    Invoke-AdvisoryStep -Name "Patrol app smoke (stabilization)" -Command {
        patrol test -t patrol_test/app_smoke_test.dart --no-uninstall
    }
    Invoke-AdvisoryStep -Name "Patrol guest/empty/profile smoke (stabilization)" -Command {
        patrol test -t patrol_test/guest_guard_empty_profile_smoke_test.dart --no-uninstall
    }
}

$maestro = Get-Command maestro -ErrorAction SilentlyContinue
if ($null -eq $maestro) {
    Write-Host ""
    Write-Host "[SKIP] Maestro advisory smoke" -ForegroundColor Yellow
    Write-Host "Maestro CLI is not installed or is not available on PATH."
    Write-Host "Install it from https://docs.maestro.dev/getting-started/installing-maestro"
    Write-Host "Then start an emulator and run:"
    Write-Host "  maestro test .maestro/app_smoke.yaml"
} else {
    Invoke-AdvisoryStep -Name "Maestro app smoke" -Command {
        maestro test .maestro/app_smoke.yaml
    }
}

Write-Host ""
Write-Host "Required quality gate steps passed." -ForegroundColor Green
