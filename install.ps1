#!/usr/bin/env pwsh
#
# install.ps1 — install or update the ava-mcp CLI tools as a uv tool, built
# from an ava_mcp*.whl in the genesys-ava-skills GitHub releases.
#
# Usage (latest stable):
#   irm https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.ps1 | iex
#
# Skip the confirmation prompt:
#   $env:AVA_MCP_YES = "1"
#
# Highest version including pre-releases:
#   .\install.ps1 -Pre
#   $env:GENESYS_AVA_PRERELEASE = "1"; irm .../install.ps1 | iex
#
# Exact version (stable or pre-release):
#   .\install.ps1 -Version 1.8.1
#   $env:GENESYS_AVA_VERSION = "1.8.1"; irm .../install.ps1 | iex
#
# Safe to re-run: it reinstalls over whatever was there before.

param(
    [switch]$Pre,
    [string]$Version
)

$ErrorActionPreference = "Stop"

$Repo = "purecloudlabs/genesys-ava-skills"
$Api = "https://api.github.com/repos/$Repo"

$Prerelease = $Pre -or ($env:GENESYS_AVA_PRERELEASE -eq "1")
if (-not $Version) { $Version = $env:GENESYS_AVA_VERSION }
if ($Version) { $Version = $Version.TrimStart("v") }

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "'uv' is not installed. Install it first:`n  irm https://astral.sh/uv/install.ps1 | iex"
}

$headers = @{ "User-Agent" = "ava-mcp-installer" }

function Get-WheelAsset($release) {
    $release.assets |
        Where-Object { $_.browser_download_url -match "ava_mcp.*\.whl$" } |
        Select-Object -First 1
}

$whlUrl = $null

try {
    if ($Version) {
        Write-Host "Resolving $Repo v$Version..."
        $release = Invoke-RestMethod -Uri "$Api/releases/tags/v$Version" -Headers $headers
        $asset = Get-WheelAsset $release
        if ($asset) { $whlUrl = $asset.browser_download_url }
    }
    elseif ($Prerelease) {
        Write-Host "Resolving highest version (incl. pre-releases) of $Repo..."
        $releases = Invoke-RestMethod -Uri "$Api/releases?per_page=100" -Headers $headers

        $candidates = foreach ($r in $releases) {
            $asset = Get-WheelAsset $r
            if (-not $asset) { continue }
            $tag = ($r.tag_name -replace '^v', '')
            if ($tag -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?') { continue }
            $patch = if ($Matches[3]) { $Matches[3] } else { "0" }
            [pscustomobject]@{
                Version = [version]"$($Matches[1]).$($Matches[2]).$patch"
                Stable  = (-not $r.prerelease)
                Url     = $asset.browser_download_url
            }
        }

        $best = $candidates |
            Sort-Object -Property @{ Expression = "Version"; Descending = $true },
                                  @{ Expression = "Stable"; Descending = $true } |
            Select-Object -First 1
        if ($best) { $whlUrl = $best.Url }
    }
    else {
        $release = Invoke-RestMethod -Uri "$Api/releases/latest" -Headers $headers
        $asset = Get-WheelAsset $release
        if ($asset) { $whlUrl = $asset.browser_download_url }
    }
}
catch {
    throw "failed to query releases for ${Repo}: $_"
}

if (-not $whlUrl) {
    if ($Version) {
        throw "no ava_mcp*.whl asset found on release v$Version of $Repo (check the tag exists, is not a draft, and has a .whl attached)"
    }
    elseif ($Prerelease) {
        throw "no ava_mcp*.whl found in any release (including pre-releases) of $Repo"
    }
    else {
        throw "no ava_mcp*.whl found in the latest release of $Repo"
    }
}

$whlName = Split-Path $whlUrl -Leaf

Write-Host "About to install: $whlName"
Write-Host "  from: $whlUrl"

if ($env:AVA_MCP_YES -ne "1") {
    $reply = Read-Host "Proceed? [y/N]"
    if ($reply -notmatch '^(y|yes)$') {
        throw "Aborted. (set `$env:AVA_MCP_YES = '1' to skip this prompt)"
    }
}

$env:UV_SKIP_WHEEL_FILENAME_CHECK = "1"

Write-Host "Installing $whlName..."
uv tool install --force $whlUrl --reinstall-package ava-mcp
if ($LASTEXITCODE -ne 0) { throw "uv tool install failed (exit code $LASTEXITCODE)" }

try { uv tool update-shell *> $null } catch { }

Write-Host ""
Write-Host "Done. Open a new terminal, then run any of the below commands."
Write-Host "To Setup AVA Harness, change to project directory and run ava-mcp setup"
Write-Host "To Update AVA Harness Skills, change to project directory and run ava-mcp skills sync"
