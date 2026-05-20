# Runs build_engine_editor.bat and prints merged compiler output with rustc-style
# warning diagnostics stripped (multi-line titles, `-->` paths, and `NNN |` snippets).

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-DiagSnippetLine([string]$Line) {
    if ([string]::IsNullOrWhiteSpace($Line)) { return $true }
    if ($Line -match '^\s+-->') { return $true }
    if ($Line -match '^\s+\|') { return $true }
    if ($Line -match '^\d+\s+\|') { return $true }
    return $false
}

$Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Push-Location $Root
try {
    $merged = cmd.exe /c "build_engine_editor.bat 2>&1"
    $exitCode = $LASTEXITCODE

    # cmd output is often captured as an array of lines; normalize before filtering.
    $lines = if ($null -eq $merged) {
        @()
    }
    elseif ($merged -is [string]) {
        @($merged -split "`r?`n")
    }
    else {
        @($merged)
    }

    $mode = $null

    foreach ($line in $lines) {
        if ($mode -eq 'wtitle') {
            # Some diagnostics omit `-->` / file header and jump straight to `NNN |` snippets.
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                if ($line -match '^\s+-->' -or $line -match '^\s+\|' -or $line -match '^\d+\s+\|') {
                    $mode = 'diag'
                }
            }
            continue
        }
        if ($mode -eq 'diag') {
            if (Test-DiagSnippetLine $line) { continue }
            $mode = $null
        }
        if ($line -match 'warning\[') {
            $mode = 'wtitle'
            continue
        }
        $line
    }

    exit $exitCode
}
finally {
    Pop-Location
}
