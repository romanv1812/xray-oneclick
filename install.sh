#!/usr/bin/env bash
set -euo pipefail

# Bootstrapper: downloads and runs the real installer from this repo.
# This works when executed via: bash <(curl -fsSL .../install.sh)

OWNER_REPO="${OWNER_REPO:-romanv1812/xray-oneclick}"
BRANCH="${BRANCH:-main}"
MAIN_PATH="${MAIN_PATH:-lib/xray-reality-vless.sh}"

RAW_BASE="https://raw.githubusercontent.com/${OWNER_REPO}/${BRANCH}"
MAIN_URL="${RAW_BASE}/${MAIN_PATH}"

exec bash <(curl -fsSL "$MAIN_URL")
