#!/bin/bash
# macOS double-click helper to start the AI Hub web launcher

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="${AIHUB_WEB_HOST:-127.0.0.1}"
PORT="${AIHUB_WEB_PORT:-3939}"

if ! command -v python >/dev/null 2>&1; then
  echo "Python 3.6 or newer is required to run the AI Hub web launcher." >&2
  exit 1
fi

PY_VERSION="$(python -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')"
PY_MAJOR="${PY_VERSION%%.*}"
PY_MINOR="${PY_VERSION#*.}"

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 6 ]; }; then
  echo "Python $PY_VERSION is not supported. Please upgrade to Python 3.6 or newer (3.7+ recommended)." >&2
  exit 1
fi

if [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -eq 6 ]; then
  echo "Python 3.6 detected; ensuring dataclasses backport is installed..."
  if ! python -c "import dataclasses" >/dev/null 2>&1; then
    if ! python -m pip install dataclasses; then
      echo "Failed to install the dataclasses backport required for Python 3.6." >&2
      exit 1
    fi
  fi
fi

cd "$PROJECT_ROOT" || exit 1

export PYTHONPATH="$PROJECT_ROOT:${PYTHONPATH:-}"
export AIHUB_WEB_HOST="$HOST"
export AIHUB_WEB_PORT="$PORT"
exec python -m modules.runtime.web_launcher --host "$HOST" --port "$PORT"
