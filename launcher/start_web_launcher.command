#!/bin/bash
# macOS double-click helper to start the AI Hub web launcher

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="${AIHUB_WEB_HOST:-127.0.0.1}"
PORT="${AIHUB_WEB_PORT:-3939}"

cd "$PROJECT_ROOT" || exit 1

export PYTHONPATH="$PROJECT_ROOT:${PYTHONPATH:-}"
export AIHUB_WEB_HOST="$HOST"
export AIHUB_WEB_PORT="$PORT"
exec python -m modules.runtime.web_launcher --host "$HOST" --port "$PORT"
