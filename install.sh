#!/usr/bin/env bash
set -euo pipefail

# Wrapper that always calls the main installer.
# This lets you change internal structure later without breaking the one-liner.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/lib/xray-reality-vless.sh"
