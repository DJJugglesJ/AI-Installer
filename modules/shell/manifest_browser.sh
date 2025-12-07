#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"
MODEL_MANIFEST="$MANIFEST_DIR/models.json"
LORA_MANIFEST="$MANIFEST_DIR/loras.json"
LOG_FILE="$HOME/.config/aihub/install.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_msg() {
  echo "$(date): $1" >> "$LOG_FILE"
}

require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing required tools: ${missing[*]}" >&2
    exit 1
  fi
}

human_size() {
  local size_bytes="$1"
  local units=(B KB MB GB TB)
  local unit=0
  local value="$size_bytes"

  while [ "$value" -ge 1024 ] && [ $unit -lt 4 ]; do
    value=$((value / 1024))
    unit=$((unit + 1))
  done

  printf "%s %s" "$value" "${units[$unit]}"
}

build_entries() {
  local manifest="$1" type_label="$2" key_prefix="$3""|"
  local -n entries_ref=$4
  local -n data_ref=$5

  [ ! -f "$manifest" ] && return

  while IFS= read -r item; do
    local name version size license tags notes size_human key
    name=$(echo "$item" | jq -r '.name')
    version=$(echo "$item" | jq -r '.version // ""')
    size=$(echo "$item" | jq -r '.size_bytes // 0')
    license=$(echo "$item" | jq -r '.license // "Unknown"')
    tags=$(echo "$item" | jq -r '.tags | join(", ")')
    notes=$(echo "$item" | jq -r '.notes // ""')
    size_human=$(human_size "$size")
    key="$key_prefix$name"

    entries_ref+=(FALSE "$type_label" "$name" "$version" "$size_human" "$license" "$tags" "$notes")
    data_ref["$key"]="$item"
  done < <(jq -c '.items[]' "$manifest")
}

require_commands jq yad

entries=()
declare -A ENTRY_DATA

build_entries "$MODEL_MANIFEST" "Model" "model" entries ENTRY_DATA
build_entries "$LORA_MANIFEST" "LoRA" "lora" entries ENTRY_DATA

if [ ${#entries[@]} -eq 0 ]; then
  yad --error --title="Manifest Browser" --text="No manifest entries found. Ensure manifests/models.json and manifests/loras.json exist." --width=500
  exit 1
fi

selection=$(yad --list --checklist --separator="\n" --width=1100 --height=600 --title="Models & LoRAs" \
  --column="Select":CHK --column="Type" --column="Name" --column="Version" --column="Size" --column="License" --column="Tags" --column="Notes" \
  "${entries[@]}")

if [ -z "$selection" ]; then
  log_msg "Manifest browser dismissed without selection"
  exit 0
fi

model_names=()
lora_names=()
while IFS='|' read -r _type name _rest; do
  [ -z "$name" ] && continue
  if [[ "$_type" = "Model"* ]]; then
    model_names+=("$name")
  else
    lora_names+=("$name")
  fi
done <<< "$selection"

if [ ${#model_names[@]} -eq 0 ] && [ ${#lora_names[@]} -eq 0 ]; then
  log_msg "Manifest browser did not capture any valid selections"
  exit 0
fi

if [ ${#model_names[@]} -gt 0 ]; then
  log_msg "Launching curated model install for ${model_names[*]}"
  CURATED_MODEL_NAMES="$(printf "%s\n" "${model_names[@]}")" HEADLESS=1 bash "$SCRIPT_DIR/install_models.sh"
fi

if [ ${#lora_names[@]} -gt 0 ]; then
  log_msg "Launching curated LoRA install for ${lora_names[*]}"
  CURATED_LORA_NAMES="$(printf "%s\n" "${lora_names[@]}")" HEADLESS=1 bash "$SCRIPT_DIR/install_loras.sh"
fi
