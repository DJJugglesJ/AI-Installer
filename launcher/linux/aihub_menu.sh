#!/bin/bash
set -euo pipefail

# AI Hub menu launcher (deprecated)
# - Purpose: redirect legacy YAD entrypoints to the Web Launcher.
# - Assumptions: Web Launcher script exists under launcher/linux.
# - Side effects: starts the Web Launcher server and exits.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_LAUNCHER="$SCRIPT_DIR/start_web_launcher.sh"

echo "[!] The YAD-based Linux menu is deprecated. Redirecting to the Web Launcher..." >&2

if [[ -x "$WEB_LAUNCHER" ]]; then
  exec bash "$WEB_LAUNCHER"
fi

echo "[!] Web Launcher script not found at $WEB_LAUNCHER." >&2
exit 1
