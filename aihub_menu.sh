#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_TARGET="$SCRIPT_DIR/launcher/linux/aihub_menu.sh"

if [[ -x "$MENU_TARGET" ]]; then
  exec bash "$MENU_TARGET" "$@"
fi

echo "[!] AI Hub menu launcher not found at $MENU_TARGET." >&2
exit 1
