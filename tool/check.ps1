# The full check sequence — one command, every check.
#
# Substage 3.5.7: "The requirement is that ONE command runs every check, not
# that a particular host runs it." This script is the authority; the GitHub
# Actions workflow calls the same steps so the two cannot drift apart.
#
#   pwsh tool/check.ps1            run everything
#   pwsh tool/check.ps1 -SkipBuild skip the slow APK build (local iteration)
#
# Exit 0 = everything passed. Any non-zero = a failure, named.

param(
    [switch]$SkipBuild,
    [switch]$SkipCoverage
)

$ErrorActionPreference = 'Continue'

# Flutter is not on every shell's PATH on this machine (ENVIRONMENT.md §8).
$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' }
           else { "$env:USERPROFILE\flutter\bin\flutter.bat" }
$dart    = if (Get-Command dart -ErrorAction SilentlyContinue) { 'dart' }
           else { "$env:USERPROFILE\flutter\bin\dart.bat" }

$failures = @()
$step = 0

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)
    $script:step++
    Write-Host ""
    Write-Host "----------------------------------------------------------"
    Write-Host "[$script:step] $Name"
    Write-Host "----------------------------------------------------------"
    & $Body
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Name (exit $LASTEXITCODE)" -ForegroundColor Red
        $script:failures += $Name
    } else {
        Write-Host "ok: $Name" -ForegroundColor Green
    }
}

Invoke-Step 'Resolve dependencies' { & $flutter pub get }

# Generated code is gitignored (substage 3.3.4), so a clean checkout has none.
# Running generation here also proves it still WORKS on every push, which is
# stronger than trusting a committed artefact.
Invoke-Step 'Code generation' { & $flutter pub run build_runner build }

Invoke-Step 'Format check' {
    & $dart format --output=none --set-exit-if-changed .
}

# Substage 3.5.3: fail on ANY analyser issue, not only on errors.
Invoke-Step 'Static analysis' { & $flutter analyze }

# The six invariant guards. See ARCHITECTURE.md §2.3 and DEVELOPMENT.md §4.
Invoke-Step 'Invariant guards G1-G6' { & $dart run tool/guards/guards.dart }

if ($SkipCoverage) {
    Invoke-Step 'Tests' { & $flutter test }
} else {
    # Substage 3.5.4: produce a coverage figure now, while it is near zero, so
    # the trend is visible from the first commit rather than from Stage 9.
    Invoke-Step 'Tests with coverage' { & $flutter test --coverage }
}

if (-not $SkipBuild) {
    Invoke-Step 'Debug build' { & $flutter build apk --debug }
}

# --- coverage summary ------------------------------------------------------
if ((-not $SkipCoverage) -and (Test-Path 'coverage/lcov.info')) {
    $lines = Get-Content 'coverage/lcov.info'
    $found = ($lines | Where-Object { $_ -match '^LF:(\d+)$' } |
              ForEach-Object { [int]$Matches[1] } | Measure-Object -Sum).Sum
    $hit   = ($lines | Where-Object { $_ -match '^LH:(\d+)$' } |
              ForEach-Object { [int]$Matches[1] } | Measure-Object -Sum).Sum
    $pct = if ($found -gt 0) { [math]::Round(100.0 * $hit / $found, 1) } else { 0 }
    Write-Host ""
    Write-Host "Coverage: $hit/$found lines ($pct%)"
}

# --- verdict ---------------------------------------------------------------
Write-Host ""
Write-Host "=========================================================="
if ($failures.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED ($script:step steps)" -ForegroundColor Green
    exit 0
}
Write-Host "FAILED: $($failures.Count) of $script:step steps" -ForegroundColor Red
$failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
exit 1
