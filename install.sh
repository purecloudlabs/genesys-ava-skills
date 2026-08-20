#!/usr/bin/env bash
#
# install.sh — install or update the ava-mcp CLI tools as a uv tool, built
# from the latest ava_mcp*.whl in the genesys-ava-skills GitHub releases.
# The wheel currently exposes multiple commands (ava-mcp, ava-mcp-update,
# ava-mcp-docs, ava-mcp-setup, ...) — `uv tool install` installs all of
# them, whatever they happen to be, so this script doesn't hardcode names.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.sh | sh
#
# Skip the confirmation prompt (e.g. for CI/non-interactive use):
#   curl -sSL .../install.sh | AVA_MCP_YES=1 sh
#
# Safe to re-run: it re-resolves the latest release every time and reinstalls
# over whatever was there before, so running it again is how you update.

set -eu

REPO="purecloudlabs/genesys-ava-skills"

if ! command -v uv >/dev/null 2>&1; then
  echo "error: 'uv' is not installed. Install it first:" >&2
  echo "  curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

whl_url=$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -oE '"browser_download_url": *"[^"]*ava_mcp[^"]*\.whl"' \
  | grep -oE 'https://[^"]*')

if [ -z "$whl_url" ]; then
  echo "error: no ava_mcp*.whl found in the latest release of ${REPO}" >&2
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
uv tool install --force "$whl_url"
uv tool update-shell >/dev/null 2>&1 || true

echo "" >&2
echo "Done. Open a new terminal, then run any of the commands listed above." >&2
