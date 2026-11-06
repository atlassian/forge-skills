#!/usr/bin/env pwsh
<#
.SYNOPSIS
Deterministic static-analysis layer for the Forge security review skill (Windows / PowerShell).

.DESCRIPTION
Runs two pinned, checksum-verified tools against a Forge project and writes every result under
<project>\security-audit-artifacts\ (override with FORGE_SA_OUTPUT_DIR):

  1. FSRT (github.com/atlassian-labs/FSRT)          -> fsrt\report.json, fsrt\fsrt.log
  2. OpenGrep (github.com/opengrep/opengrep) running -> opengrep\results.json,
     the Forge rules in ..\assets\opengrep-rules   opengrep\results.sarif, opengrep\opengrep.log

A machine-readable status summary is written to static-analysis-summary.json and printed.
Exit codes: 0 every tool completed (with or without findings); 1 at least one tool did not
complete (its status is "not_run", never "clean"); 2 usage error.

Environment: FORGE_SA_SKIP_FSRT=1, FORGE_SA_SKIP_OPENGREP=1, FORGE_SA_OUTPUT_DIR, FORGE_LOG.
Network: first run downloads each binary once and verifies its SHA-256 before executing it.
FSRT fetches Atlassian API specifications into ~\.cache\fsrt on its first run. Nothing is uploaded.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ForgeProjectRootDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RulesDir = Join-Path (Split-Path -Parent $ScriptDir) 'assets\opengrep-rules'
$FsrtExe = Join-Path $ScriptDir 'fsrt.exe'
$OpenGrepExe = Join-Path $ScriptDir 'opengrep.exe'

# FSRT pin: a specific release tag on atlassian-labs/FSRT (Atlassian-controlled). The asset is
# named fsrt-<platform>.<ext> and holds fsrt.exe at the archive root. The SHA-256 is verified after
# download so a tampered or substituted asset is rejected before it is ever executed. Keep these
# values in sync with run_static_analysis.sh.
$FsrtReleaseTag = 'v0.1.1'
$FsrtAssetExt = 'zip'
$FsrtPlatform = 'windows-x86_64'
$FsrtUrl = "https://github.com/atlassian-labs/FSRT/releases/download/$FsrtReleaseTag/fsrt-$FsrtPlatform.$FsrtAssetExt"
$FsrtSha256 = 'E3487415F161CDDC2BAD3CDE7C8C517A7E3ECFFBF307227500886529F143E310'

# OpenGrep pin: official release asset from github.com/opengrep/opengrep (LGPL-2.1, no telemetry).
$OpenGrepVersion = '1.16.2'
$OpenGrepUrl = "https://github.com/opengrep/opengrep/releases/download/v$OpenGrepVersion/opengrep_windows_x86.exe"
$OpenGrepSha256 = '1232AEA7E877D82289EFE7C676DBF5A32524122A2C5B8EF69564E544802E6FF0'

$OpenGrepExcludes = @(
    '--exclude', 'node_modules', '--exclude', 'dist', '--exclude', 'build', '--exclude', '.next',
    '--exclude', 'out', '--exclude', 'coverage', '--exclude', 'vendor',
    '--exclude', 'security-audit-artifacts',
    '--exclude', '*.min.js', '--exclude', '*.min.css', '--exclude', '*.bundle.js',
    '--exclude', '*.chunk.js', '--exclude', '*.map'
)

$Status = [ordered]@{
    fsrt     = [ordered]@{ status = 'not_run'; detail = ''; release = $FsrtReleaseTag; findings = 0; report = 'fsrt/report.json'; log = 'fsrt/fsrt.log' }
    opengrep = [ordered]@{ status = 'not_run'; detail = ''; version = $OpenGrepVersion; rules_dir = $RulesDir; findings = 0; error_findings = 0; warning_findings = 0; file_errors = 0; json = 'opengrep/results.json'; sarif = 'opengrep/results.sarif'; log = 'opengrep/opengrep.log' }
}

function Write-Log {
    param([string]$Message)
    Write-Host "[static-analysis] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[static-analysis] WARNING: $Message" -ForegroundColor Yellow
}

function Fail-Usage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    Write-Host 'Usage: run_static_analysis.ps1 <forge-project-root-directory>'
    exit 2
}

# Downloads to a temporary file, verifies the SHA-256, then moves it into place.
function Install-VerifiedDownload {
    param([string]$Url, [string]$ExpectedSha256, [string]$Destination)
    $tmp = "$Destination.$([System.Guid]::NewGuid().ToString('N')).download"
    try {
        Write-Log "Downloading $Url"
        Invoke-WebRequest -Uri $Url -OutFile $tmp -MaximumRetryCount 3 -RetryIntervalSec 5
        $actual = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
        if ($actual -ine $ExpectedSha256) {
            throw "checksum mismatch for $Url`n  expected: $ExpectedSha256`n  actual:   $actual"
        }
        Move-Item -LiteralPath $tmp -Destination $Destination -Force
        Write-Log "Checksum verified: $actual"
    }
    finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}

function Install-Fsrt {
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    try {
        $archive = Join-Path $tmpDir "fsrt-artifact.$FsrtAssetExt"
        $extracted = Join-Path $tmpDir 'extracted'
        Write-Log "fsrt.exe not found in $ScriptDir. Downloading the pinned release for $FsrtPlatform..."
        Install-VerifiedDownload -Url $FsrtUrl -ExpectedSha256 $FsrtSha256 -Destination $archive

        New-Item -ItemType Directory -Path $extracted | Out-Null
        if ($FsrtAssetExt -eq 'zip') {
            Expand-Archive -LiteralPath $archive -DestinationPath $extracted -Force
        }
        else {
            & tar -xzf $archive -C $extracted
            if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archive" }
        }

        # The archive holds the binary at its root.
        $found = Get-ChildItem -LiteralPath $extracted -File -Recurse |
            Where-Object { $_.Name -ieq 'fsrt.exe' -or $_.Name -ieq 'fsrt' } |
            Select-Object -First 1
        if ($null -eq $found) {
            throw "could not find 'fsrt.exe' (or 'fsrt') inside the downloaded artifact"
        }
        Copy-Item -LiteralPath $found.FullName -Destination $FsrtExe -Force
        Write-Log "Installed fsrt to $FsrtExe"
    }
    finally {
        if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force }
    }
}

function Install-OpenGrep {
    Write-Log "opengrep.exe not found in $ScriptDir. Downloading OpenGrep $OpenGrepVersion (windows_x86)..."
    Install-VerifiedDownload -Url $OpenGrepUrl -ExpectedSha256 $OpenGrepSha256 -Destination $OpenGrepExe
    Write-Log "Installed opengrep to $OpenGrepExe"
}

function Invoke-Fsrt {
    param([string]$TargetDir, [string]$OutputDir)
    $outDir = Join-Path $OutputDir 'fsrt'
    $report = Join-Path $outDir 'report.json'
    $logFile = Join-Path $outDir 'fsrt.log'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    if ($env:FORGE_SA_SKIP_FSRT -eq '1') {
        $Status.fsrt.status = 'skipped'
        $Status.fsrt.detail = 'FORGE_SA_SKIP_FSRT=1'
        return
    }
    if (-not (Test-Path -LiteralPath $FsrtExe -PathType Leaf)) {
        try {
            Install-Fsrt
        }
        catch {
            $Status.fsrt.status = 'not_run'
            $Status.fsrt.detail = "download or verification failed: $($_.Exception.Message)"
            Add-Content -LiteralPath $logFile -Value $_.Exception.Message
            Write-Warn "FSRT: $($Status.fsrt.detail)"
            return
        }
    }

    if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report -Force }
    Write-Log "Running fsrt against $TargetDir"
    if (-not $env:FORGE_LOG) { $env:FORGE_LOG = 'warn' }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $FsrtExe --out $report $TargetDir *> $logFile
        $rc = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    $logText = if (Test-Path -LiteralPath $logFile) { Get-Content -LiteralPath $logFile -Raw } else { '' }
    if ($rc -ne 0) {
        $Status.fsrt.status = 'not_run'
        $Status.fsrt.detail = "fsrt exited with status $rc; see fsrt/fsrt.log"
    }
    elseif (-not (Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).Length -eq 0) {
        $Status.fsrt.status = 'not_run'
        $Status.fsrt.detail = 'fsrt produced no report; see fsrt/fsrt.log'
    }
    elseif ($logText -match 'Could not scan|Unable to scan') {
        $Status.fsrt.status = 'not_run'
        $Status.fsrt.detail = 'fsrt could not analyse this project; see fsrt/fsrt.log'
    }
    else {
        $Status.fsrt.status = 'completed'
        try {
            $json = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
            $Status.fsrt.findings = @($json.vulns).Count
        }
        catch {
            $Status.fsrt.findings = 0
        }
        if ($logText -match 'error while running') {
            $Status.fsrt.status = 'completed_with_warnings'
            $Status.fsrt.detail = 'a checker reported errors; see fsrt/fsrt.log'
        }
    }

    if ($Status.fsrt.status -eq 'not_run') {
        Write-Warn "FSRT: $($Status.fsrt.detail)"
    }
    else {
        Write-Log "FSRT $($Status.fsrt.status): $($Status.fsrt.findings) finding(s) -> $report"
        Get-Content -LiteralPath $report -Raw | Write-Host
    }
}

function Invoke-OpenGrep {
    param([string]$TargetDir, [string]$OutputDir)
    $outDir = Join-Path $OutputDir 'opengrep'
    $results = Join-Path $outDir 'results.json'
    $sarif = Join-Path $outDir 'results.sarif'
    $logFile = Join-Path $outDir 'opengrep.log'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    if ($env:FORGE_SA_SKIP_OPENGREP -eq '1') {
        $Status.opengrep.status = 'skipped'
        $Status.opengrep.detail = 'FORGE_SA_SKIP_OPENGREP=1'
        return
    }
    if (-not (Test-Path -LiteralPath $RulesDir -PathType Container) -or -not (Get-ChildItem -LiteralPath $RulesDir -Filter '*.yaml')) {
        $Status.opengrep.status = 'not_run'
        $Status.opengrep.detail = "rule file missing at $RulesDir"
        Write-Warn "OpenGrep: $($Status.opengrep.detail)"
        return
    }
    if (-not (Test-Path -LiteralPath $OpenGrepExe -PathType Leaf)) {
        try {
            Install-OpenGrep
        }
        catch {
            $Status.opengrep.status = 'not_run'
            $Status.opengrep.detail = "download or verification failed: $($_.Exception.Message)"
            Add-Content -LiteralPath $logFile -Value $_.Exception.Message
            Write-Warn "OpenGrep: $($Status.opengrep.detail)"
            return
        }
    }

    foreach ($f in @($results, $sarif)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
    Write-Log "Running OpenGrep $OpenGrepVersion with $RulesDir against $TargetDir"
    $env:PYTHONUTF8 = '1'
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # Scan from inside the project targeting "." so the exclude globs only match directories inside
    # the project, never a parent folder called build, dist or coverage. Paths come out relative.
    Push-Location -LiteralPath $TargetDir
    try {
        & $OpenGrepExe scan --disable-version-check --config $RulesDir `
            --json-output $results --sarif-output $sarif `
            --timeout 30 --timeout-threshold 3 --max-target-bytes 1000000 `
            @OpenGrepExcludes . *> $logFile
        $rc = $LASTEXITCODE
    }
    finally {
        Pop-Location
        $ErrorActionPreference = $previous
    }

    if (($rc -ne 0 -and $rc -ne 1) -or -not (Test-Path -LiteralPath $results) -or (Get-Item -LiteralPath $results).Length -eq 0) {
        $Status.opengrep.status = 'not_run'
        $Status.opengrep.detail = "opengrep exited with status $rc; see opengrep/opengrep.log"
        Write-Warn "OpenGrep: $($Status.opengrep.detail)"
        return
    }

    try {
        $json = Get-Content -LiteralPath $results -Raw | ConvertFrom-Json
    }
    catch {
        $Status.opengrep.status = 'not_run'
        $Status.opengrep.detail = 'opengrep output is not valid JSON; see opengrep/opengrep.log'
        Write-Warn "OpenGrep: $($Status.opengrep.detail)"
        return
    }
    $all = @($json.results)
    $Status.opengrep.status = 'completed'
    $Status.opengrep.findings = $all.Count
    $Status.opengrep.error_findings = @($all | Where-Object { $_.extra.severity -eq 'ERROR' }).Count
    $Status.opengrep.warning_findings = @($all | Where-Object { $_.extra.severity -eq 'WARNING' }).Count
    $Status.opengrep.file_errors = @($json.errors).Count
    if ($Status.opengrep.file_errors -gt 0) {
        $Status.opengrep.status = 'completed_with_errors'
        $Status.opengrep.detail = "$($Status.opengrep.file_errors) file-level error(s) or timeout(s) listed under `"errors`" in results.json"
    }
    Write-Log "OpenGrep $($Status.opengrep.status): $($Status.opengrep.findings) finding(s) ($($Status.opengrep.error_findings) ERROR, $($Status.opengrep.warning_findings) WARNING), $($Status.opengrep.file_errors) file error(s) -> $results"
}

function Write-Summary {
    param([string]$TargetDir, [string]$OutputDir)
    $overall = 'completed'
    if ($Status.fsrt.status -eq 'not_run' -or $Status.opengrep.status -eq 'not_run') { $overall = 'incomplete' }
    $summary = [ordered]@{
        overall       = $overall
        project       = $TargetDir
        artifacts_dir = $OutputDir
        tools         = $Status
    }
    $summaryPath = Join-Path $OutputDir 'static-analysis-summary.json'
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8

    Write-Host ''
    Write-Host "Static analysis summary ($summaryPath):"
    Write-Host ("  FSRT      {0}{1} ({2} finding(s))" -f $Status.fsrt.status, $(if ($Status.fsrt.detail) { " - $($Status.fsrt.detail)" } else { '' }), $Status.fsrt.findings)
    Write-Host ("  OpenGrep  {0}{1} ({2} finding(s): {3} ERROR, {4} WARNING)" -f $Status.opengrep.status, $(if ($Status.opengrep.detail) { " - $($Status.opengrep.detail)" } else { '' }), $Status.opengrep.findings, $Status.opengrep.error_findings, $Status.opengrep.warning_findings)
    if ($overall -eq 'incomplete') {
        Write-Host '  RESULT    INCOMPLETE: a tool marked not_run did NOT analyse the project. Report it as a coverage gap; do not treat its absence of findings as a clean result.' -ForegroundColor Yellow
        return 1
    }
    Write-Host '  RESULT    all requested tools completed. Deterministic findings are leads: triage each one against its metadata.skill_rule file before reporting.'
    return 0
}

if (-not (Test-Path -LiteralPath $ForgeProjectRootDirectory -PathType Container)) {
    Fail-Usage "Error: target directory does not exist: $ForgeProjectRootDirectory"
}
$targetDir = (Resolve-Path -LiteralPath $ForgeProjectRootDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $targetDir 'manifest.yml') -PathType Leaf) -and
    -not (Test-Path -LiteralPath (Join-Path $targetDir 'manifest.yaml') -PathType Leaf)) {
    Fail-Usage "Error: no manifest.yml found in target directory: $targetDir`nHint: pass the Forge project root directory (the directory containing manifest.yml)."
}
$outputDir = if ($env:FORGE_SA_OUTPUT_DIR) { $env:FORGE_SA_OUTPUT_DIR } else { Join-Path $targetDir 'security-audit-artifacts' }
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$outputDir = (Resolve-Path -LiteralPath $outputDir).Path

Invoke-Fsrt -TargetDir $targetDir -OutputDir $outputDir
Invoke-OpenGrep -TargetDir $targetDir -OutputDir $outputDir
$exitCode = Write-Summary -TargetDir $targetDir -OutputDir $outputDir
exit $exitCode
