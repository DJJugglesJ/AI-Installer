#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_TARGET="$SCRIPT_DIR/launcher/linux/start_web_launcher.sh"

if [[ -x "$WEB_TARGET" ]]; then
  echo "[!] The YAD-based menu is deprecated. Launching the Web Launcher instead." >&2
  exec bash "$WEB_TARGET" "$@"
fi

echo "[!] Web Launcher script not found at $WEB_TARGET." >&2
exit 1
