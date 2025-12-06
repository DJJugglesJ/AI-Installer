#!/bin/bash

# YAD-based panels for Prompt Builder quick entry and guided scene building.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="${PROMPT_CACHE_DIR:-$HOME/.cache/aihub/prompt_builder}"
SCENE_FILE="$CACHE_DIR/scene_description.json"
BUNDLE_PATH="${PROMPT_BUNDLE_PATH:-$CACHE_DIR/prompt_bundle.json}"

mkdir -p "$CACHE_DIR"

if ! command -v yad >/dev/null 2>&1; then
  echo "Prompt Builder UI requires 'yad' to be installed." >&2
  exit 1
fi

show_error() {
  local message="$1"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="Prompt Builder" --text="$message"
  else
    echo "Prompt Builder: $message" >&2
  fi
}

save_scene_and_compile() {
  local scene_json="$1"
  echo "$scene_json" > "$SCENE_FILE"
  if ! command -v python >/dev/null 2>&1; then
    show_error "Python is required to run the Prompt Builder compiler."
    return 1
  fi
  PROMPT_BUNDLE_PATH="$BUNDLE_PATH" (cd "$PROJECT_ROOT" && python -m modules.prompt_builder --scene "$SCENE_FILE") || show_error "Failed to compile scene into prompts."
}

parse_characters() {
  python - <<'PY'
import json, sys

raw = sys.stdin.read().strip().splitlines()
entries = []
for line in raw:
    if not line.strip():
        continue
    slot, character, *rest = (part.strip().replace('"', '') for part in line.split(',', 3))
    role = rest[0] if len(rest) >= 1 else ''
    override = rest[1] if len(rest) >= 2 else ''
    entry = {
        "slot_id": slot,
        "character_id": character,
    }
    if role:
        entry["role"] = role
    if override:
        entry["override_prompt_snippet"] = override
    entries.append(entry)

json.dump(entries, sys.stdout)
PY
}

extras_to_json_array() {
  python - <<'PY'
import json, sys

raw = sys.stdin.read().strip()
if not raw:
    json.dump([], sys.stdout)
    raise SystemExit

parts = [part.strip() for part in raw.split(',') if part.strip()]
json.dump(parts, sys.stdout)
PY
}

quick_prompt_panel() {
  local output
  output=$(yad --form --title="Quick Prompt" --width=600 \
    --field="Setting" --field="Mood" --field="Style" --field="Extras (comma-separated)" \
    --field="NSFW Level:CB" "safe!sfw!suggestive!explicit" --separator="|") || return 0

  IFS='|' read -r setting mood style extras nsfw <<<"$output"
  local extras_array
  extras_array=$(printf "%s" "$extras" | extras_to_json_array)
  local scene
  scene=$(cat <<JSON
{
  "setting": "${setting}",
  "mood": "${mood}",
  "style": "${style}",
  "nsfw_level": "${nsfw}",
  "extra_elements": ${extras_array}
}
JSON
)
  save_scene_and_compile "$scene"
}

guided_scene_panel() {
  local output
  output=$(yad --form --title="Guided Scene Builder" --width=700 --height=400 \
    --field="World" --field="Setting" --field="Mood" --field="Style" --field="Camera" \
    --field="NSFW Level:CB" "safe!sfw!suggestive!explicit" \
    --field="Characters (slot,character_id,role,override per line):TXT" \
    --field="Extra elements (comma-separated):TXT" --separator="|") || return 0

  IFS='|' read -r world setting mood style camera nsfw characters_raw extras <<<"$output"
  local extras_array
  extras_array=$(printf "%s" "$extras" | extras_to_json_array)
  local characters_json
  characters_json=$(printf "%s" "$characters_raw" | parse_characters)
  local scene
  scene=$(cat <<JSON
{
  "world": "${world}",
  "setting": "${setting}",
  "mood": "${mood}",
  "style": "${style}",
  "camera": "${camera}",
  "nsfw_level": "${nsfw}",
  "characters": ${characters_json},
  "extra_elements": ${extras_array}
}
JSON
)
  save_scene_and_compile "$scene"
}

main_menu() {
  local choice
  choice=$(yad --list --title="Prompt Builder" --column="Mode" --column="Description" \
    "Quick Prompt" "Fast form for vibe and extras" \
    "Guided Scene Builder" "Structured world, camera, and characters" \
    --width=600 --height=200) || return 0

  case "$choice" in
    Quick\ Prompt*) quick_prompt_panel ;;
    Guided\ Scene\ Builder*) guided_scene_panel ;;
  esac
}

main_menu
