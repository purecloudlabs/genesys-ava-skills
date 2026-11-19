#!/usr/bin/env bash
#
# install.sh — install or update the ava-mcp CLI tools as a uv tool, built
# from an ava_mcp*.whl in the genesys-ava-skills GitHub releases.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.sh | sh
#
# Skip the confirmation prompt:
#   curl -sSL .../install.sh | AVA_MCP_YES=1 sh
#
# Install the highest version including pre-releases:
#   curl -sSL .../install.sh | sh -s -- --pre
#   curl -sSL .../install.sh | GENESYS_AVA_PRERELEASE=1 sh
#
# Install an exact version (stable or pre-release):
#   curl -sSL .../install.sh | sh -s -- --version 1.8.1
#   curl -sSL .../install.sh | GENESYS_AVA_VERSION=1.8.1 sh
#
# Safe to re-run: it reinstalls over whatever was there before.

set -eu

REPO="purecloudlabs/genesys-ava-skills"
API="https://api.github.com/repos/${REPO}"

PRERELEASE="${GENESYS_AVA_PRERELEASE:-0}"
VERSION="${GENESYS_AVA_VERSION:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --pre) PRERELEASE=1 ;;
    --version)
      if [ $# -lt 2 ]; then
        echo "error: --version requires a value, e.g. --version 1.8.1" >&2
        exit 1
      fi
      VERSION="$2"
      shift
      ;;
    --version=*) VERSION="${1#--version=}" ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

if ! command -v uv >/dev/null 2>&1; then
  echo "error: 'uv' is not installed. Install it first:" >&2
  echo "  curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

fetch() {
  curl -sSL "$1"
}

if [ -n "$VERSION" ]; then
  VERSION="${VERSION#v}"
  echo "Resolving ${REPO} v${VERSION}..." >&2
  releases_url="${API}/releases/tags/v${VERSION}"
elif [ "$PRERELEASE" = "1" ]; then
  echo "Resolving highest version (incl. pre-releases) of ${REPO}..." >&2
  releases_url="${API}/releases?per_page=100"
else
  releases_url="${API}/releases/latest"
fi

whl_url=$(fetch "$releases_url" \
  | grep -oE '"browser_download_url": *"[^"]*ava_mcp[^"]*\.whl"' \
  | grep -oE 'https://[^"]*' \
  | sort -V \
  | tail -n 1 || true)

if [ -z "$whl_url" ]; then
  if [ -n "$VERSION" ]; then
    echo "error: no ava_mcp*.whl asset found on release v${VERSION} of ${REPO}" >&2
    echo "       (check the tag exists, is not a draft, and has a .whl attached)" >&2
  elif [ "$PRERELEASE" = "1" ]; then
    echo "error: no ava_mcp*.whl found in any release of ${REPO}" >&2
  else
    echo "error: no ava_mcp*.whl found in the latest release of ${REPO}" >&2
  fi
  exit 1
fi

echo "About to install: $(basename "$whl_url")"
echo "  from: $whl_url"

if [ "${AVA_MCP_YES:-0}" != "1" ]; then
  if [ -r /dev/tty ]; then
    printf "Proceed? [y/N] "
    read -r reply < /dev/tty
  else
    reply="n"
  fi
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted. (set AVA_MCP_YES=1 to skip this prompt)" >&2; exit 1 ;;
  esac
fi

echo "Installing $(basename "$whl_url")..." >&2
uv tool install --force "$whl_url" --reinstall-package ava-mcp
uv tool update-shell >/dev/null 2>&1 || true

echo "" >&2
echo "Done. Open a new terminal, then run any of the below commands." >&2
echo "To Setup AVA Harness, change to project directory and run ava-mcp setup"
echo "To Update AVA Harness Skills, change to project directory and run ava-mcp skills sync"
