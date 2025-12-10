#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:-json}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run GPU diagnostics." >&2
  exit 1
fi

run_python() {
  PYTHONPATH="$PROJECT_ROOT" python3 - <<'PY'
import json
from modules.runtime.hardware.gpu_diagnostics import collect_gpu_diagnostics, format_summary

payload = collect_gpu_diagnostics()
print(json.dumps(payload, indent=2))
print("\n" + format_summary(payload))
PY
}

output=$(run_python)
json_block=$(printf '%s' "$output" | python3 - <<'PY'
import json
import sys

def main() -> None:
    raw = sys.stdin.read()
    # Split on the first double newline to preserve the JSON block even if summaries contain blank lines.
    parts = raw.split("\n\n", 1)
    json_part = parts[0]
    try:
        parsed = json.loads(json_part)
    except json.JSONDecodeError:
        sys.stdout.write(json_part)
        return
    sys.stdout.write(json.dumps(parsed, indent=2))

if __name__ == "__main__":
    main()
PY
)
summary_block=$(printf '%s' "$output" | sed -n '/^GPU Diagnostics/,$p')

if [[ "$MODE" == "--summary" || "$MODE" == "summary" ]]; then
  printf '%s\n' "$summary_block"
elif [[ "$MODE" == "--combined" ]]; then
  printf '%s\n\n%s\n' "$json_block" "$summary_block"
else
  printf '%s\n' "$json_block"
fi
