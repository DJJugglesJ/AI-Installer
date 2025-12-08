#!/bin/bash
# Start the AI Hub web launcher (Linux/macOS/WSL)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="${AIHUB_WEB_HOST:-127.0.0.1}"
PORT="${AIHUB_WEB_PORT:-3939}"

cd "$PROJECT_ROOT" || exit 1

PYTHONPATH="$PROJECT_ROOT:${PYTHONPATH:-}" \
AIHUB_WEB_HOST="$HOST" \
AIHUB_WEB_PORT="$PORT" \
python -m modules.runtime.web_launcher --host "$HOST" --port "$PORT"
