#!/usr/bin/env pwsh
#
# install.ps1 — install or update the ava-mcp CLI tools as a uv tool, built
# from the latest ava_mcp*.whl in the genesys-ava-skills GitHub releases.
# The wheel currently exposes multiple commands (ava-mcp, ava-mcp-update,
# ava-mcp-docs, ava-mcp-setup, ...) — `uv tool install` installs all of
# them, whatever they happen to be, so this script doesn't hardcode names.
#
# Usage:
#   irm https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.ps1 | iex
#
# Skip the confirmation prompt (e.g. for CI/non-interactive use):
#   $env:AVA_MCP_YES = "1"
#   irm https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.ps1 | iex
#
# Safe to re-run: it re-resolves the latest release every time and reinstalls
# over whatever was there before, so running it again is how you update.

$ErrorActionPreference = "Stop"

$Repo = "purecloudlabs/genesys-ava-skills"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Error "'uv' is not installed. Install it first:`n  irm https://astral.sh/uv/install.ps1 | iex"
    exit 1
}

try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -ErrorAction Stop
}
catch {
    Write-Error "error: failed to query latest release for ${Repo}: $_"
    exit 1
}

$whlAsset = $release.assets | Where-Object { $_.browser_download_url -match "ava_mcp.*\.whl$" } | Select-Object -First 1
$whlUrl = $whlAsset.browser_download_url

if (-not $whlUrl) {
    Write-Error "error: no ava_mcp*.whl found in the latest release of $Repo"
    exit 1
}

$whlName = Split-Path $whlUrl -Leaf

Write-Host "About to install: $whlName"
Write-Host "  from: $whlUrl"

if ($env:AVA_MCP_YES -ne "1") {
    $reply = Read-Host "Proceed? [y/N]"
    switch -Regex ($reply) {
        '^(y|Y|yes|YES)$' { }
        default {
            Write-Error "Aborted. (set `$env:AVA_MCP_YES = '1' to skip this prompt)"
            exit 1
        }
    }
}

$env:UV_SKIP_WHEEL_FILENAME_CHECK=1

Write-Host "Installing $whlName..."
uv tool install --force $whlUrl --reinstall-package ava-mcp
try { uv tool update-shell *> $null } catch { }

Write-Host ""
Write-Host "Done. Open a new terminal, then run any of the below commands."
Write-Host "To Setup AVA Harness, change to project directory and run ava-mcp setup"
Write-Host "To Update AVA Harness Skills, change to project directory and run ava-mcp update"

