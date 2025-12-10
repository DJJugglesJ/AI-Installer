#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run GPU diagnostics." >&2
  exit 1
fi

PYTHONPATH="$PROJECT_ROOT" python3 - <<'PY'
import json
from modules.runtime.hardware.gpu_diagnostics import collect_gpu_diagnostics, format_summary

def main() -> None:
    payload = collect_gpu_diagnostics()
    print(json.dumps(payload, indent=2))
    print()
    print(format_summary(payload))


if __name__ == "__main__":
    main()
PY
