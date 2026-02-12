#!/usr/bin/env bash
set -euo pipefail

OWNER_REPO="${OWNER_REPO:-romanv1812/xray-oneclick}"
BRANCH="${BRANCH:-main}"
MAIN_PATH="${MAIN_PATH:-lib/xray-reality-vless.sh}"

exec bash <(curl -fsSL "https://raw.githubusercontent.com/${OWNER_REPO}/${BRANCH}/${MAIN_PATH}")
