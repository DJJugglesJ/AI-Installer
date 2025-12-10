#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

payload=""
if [ -t 0 ]; then
  payload=${1:-""}
else
  payload="$(cat)"
fi

if [ -z "$payload" ]; then
  echo "Usage: run_txt2vid.sh '{\"prompt\":\"Describe the scene\"}'" >&2
  exit 1
fi

cd "$PROJECT_ROOT"
printf '%s' "$payload" | python -m modules.runtime.video.txt2vid.cli
