#!/bin/bash

# Curated manifest browser for models and LoRAs.
# - Reads manifests/models.json and manifests/loras.json
# - Presents filterable UI for selections and streams progress while invoking installers
# - Records a history of selections and provides error handling/logging

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST_DIR="$ROOT_DIR/manifests"
MODEL_MANIFEST="$MANIFEST_DIR/models.json"
LORA_MANIFEST="$MANIFEST_DIR/loras.json"
LOG_FILE="$HOME/.config/aihub/install.log"
HISTORY_FILE="$HOME/.config/aihub/manifest_history.tsv"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_msg() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local message="Missing required tools: ${missing[*]}"
    echo "$message" >&2
    yad --error --title="Manifest Browser" --text="$message" --width=400 2>/dev/null || true
    exit 1
  fi
}

require_commands jq yad

if [ ! -f "$MODEL_MANIFEST" ] || [ ! -f "$LORA_MANIFEST" ]; then
  yad --error --title="Manifest Browser" --text="Could not find manifests in $MANIFEST_DIR" --width=420
  exit 1
fi

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

read_manifest_items() {
  local manifest="$1" type_label="$2"
  jq -c --arg type "$type_label" '.items[] | .type = $type' "$manifest"
}

apply_filters() {
  local type_filter="$1" tag_filter="$2" name_filter="$3" license_filter="$4"
  while IFS= read -r item; do
    local type name tags license
    type=$(echo "$item" | jq -r '.type')
    name=$(echo "$item" | jq -r '.name')
    tags=$(echo "$item" | jq -r '.tags | join(", ") // ""')
    license=$(echo "$item" | jq -r '.license // ""')

    if [ "$type_filter" != "All" ] && [ "$type" != "$type_filter" ]; then
      continue
    fi
    if [ -n "$tag_filter" ] && ! echo "$tags" | grep -iq "$tag_filter"; then
      continue
    fi
    if [ -n "$name_filter" ] && ! echo "$name" | grep -iq "$name_filter"; then
      continue
    fi
    if [ -n "$license_filter" ] && ! echo "$license" | grep -iq "$license_filter"; then
      continue
    fi

    echo "$item"
  done
}

show_history() {
  if [ ! -s "$HISTORY_FILE" ]; then
    yad --info --title="Selection History" --text="No history found yet." --width=350
    return
  fi

  yad --text-info --title="Selection History" --filename="$HISTORY_FILE" --width=800 --height=400 \
    --button=OK:0 --center --wrap
}

select_filters() {
  local form_output status
  while true; do
    form_output=$(yad --form --title="Filter Curated Downloads" --width=420 --center \
      --field="Type:CB" "All!Model!LoRA" \
      --field="Tags contains" "" \
      --field="Name contains" "" \
      --field="License contains" "" \
      --button="Browse:0" --button="History:2" --button="Cancel:1")
    status=$?
    case $status in
      0) echo "$form_output"; return 0 ;;
      2) show_history ;;
      *) exit 0 ;;
    esac
  done
}

build_entries() {
  local filtered_items="$1"
  local -n entries_ref=$2
  local -n data_ref=$3
  local item name version size license tags notes type size_human key

  while IFS= read -r item; do
    name=$(echo "$item" | jq -r '.name')
    version=$(echo "$item" | jq -r '.version // ""')
    size=$(echo "$item" | jq -r '.size_bytes // 0')
    license=$(echo "$item" | jq -r '.license // "Unknown"')
    tags=$(echo "$item" | jq -r '.tags | join(", ") // ""')
    notes=$(echo "$item" | jq -r '.notes // ""')
    type=$(echo "$item" | jq -r '.type')
    size_human=$(human_size "$size")
    key="$type|$name"

    entries_ref+=(FALSE "$type" "$name" "$version" "$size_human" "$license" "$tags" "$notes")
    data_ref["$key"]="$item"
  done <<< "$filtered_items"
}

read_selection() {
  local -n entries_ref=$1
  yad --list --checklist --separator="\n" --width=1100 --height=600 --title="Models & LoRAs" --center \
    --column="Select":CHK --column="Type" --column="Name" --column="Version" --column="Size" --column="License" --column="Tags" --column="Notes" \
    "${entries_ref[@]}" --button="Install:0" --button="History:2" --button="Back:1"
}

run_with_progress() {
  local title="$1"
  shift
  local log_tmp status_file tail_pid
  log_tmp=$(mktemp)
  status_file=$(mktemp)

  (
    "$@" >"$log_tmp" 2>&1
    echo $? >"$status_file"
  ) &
  local cmd_pid=$!

  (
    echo "# ${title} (logs: $log_tmp)"
    tail -f "$log_tmp" &
    tail_pid=$!
    wait $cmd_pid
    kill "$tail_pid" 2>/dev/null || true
    echo "100"
  ) | yad --progress --pulsate --auto-close --auto-kill --no-buttons --title="$title" --width=650 --height=260 --center

  local status
  status=$(cat "$status_file" 2>/dev/null || echo 1)
  rm -f "$status_file"
  rm -f "$log_tmp"
  return "$status"
}

append_history() {
  local type="$1"; shift
  local status="$1"; shift
  local names=("$@")
  mkdir -p "$(dirname "$HISTORY_FILE")"
  for name in "${names[@]}"; do
    printf "%s\t%s\t%s\t%s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$type" "$name" "$status" >> "$HISTORY_FILE"
  done
}

install_selection() {
  local -n selection_items=$1
  local models=()
  local loras=()
  local type name

  while IFS='|' read -r type name _rest; do
    [ -z "$name" ] && continue
    if [ "$type" = "Model" ]; then
      models+=("$name")
    else
      loras+=("$name")
    fi
  done <<< "${selection_items[*]}"

  local status

  if [ ${#models[@]} -gt 0 ]; then
    log_msg "Launching curated model install for ${models[*]}"
    if run_with_progress "Installing models" env CURATED_MODEL_NAMES="$(printf "%s\n" "${models[@]}")" HEADLESS=1 bash "$SCRIPT_DIR/install_models.sh"; then
      append_history "Model" "success" "${models[@]}"
    else
      append_history "Model" "failure" "${models[@]}"
      yad --error --title="Model install failed" --text="One or more model installs failed. Check $LOG_FILE" --width=500
    fi
  fi

  if [ ${#loras[@]} -gt 0 ]; then
    log_msg "Launching curated LoRA install for ${loras[*]}"
    if run_with_progress "Installing LoRAs" env CURATED_LORA_NAMES="$(printf "%s\n" "${loras[@]}")" HEADLESS=1 bash "$SCRIPT_DIR/install_loras.sh"; then
      append_history "LoRA" "success" "${loras[@]}"
    else
      append_history "LoRA" "failure" "${loras[@]}"
      yad --error --title="LoRA install failed" --text="One or more LoRA installs failed. Check $LOG_FILE" --width=500
    fi
  fi
}

main() {
  log_msg "Manifest browser opened"
  local filter_input type_filter tag_filter name_filter license_filter
  filter_input=$(select_filters) || exit 0
  IFS='|' read -r type_filter tag_filter name_filter license_filter <<< "$filter_input"

  local all_items filtered_items
  all_items=$( {
    read_manifest_items "$MODEL_MANIFEST" "Model"
    read_manifest_items "$LORA_MANIFEST" "LoRA"
  } )

  filtered_items=$(printf "%s\n" "$all_items" | apply_filters "$type_filter" "$tag_filter" "$name_filter" "$license_filter")

  if [ -z "$filtered_items" ]; then
    yad --warning --title="Manifest Browser" --text="No entries match your filters." --width=400
    exit 0
  fi

  local entries=()
  declare -A ENTRY_DATA
  build_entries "$filtered_items" entries ENTRY_DATA

  local selection_dialog selection_status
  while true; do
    selection_dialog=$(read_selection entries)
    selection_status=$?
    case $selection_status in
      0)
        [ -z "$selection_dialog" ] && { yad --info --title="Manifest Browser" --text="Nothing selected." --width=300; continue; }
        install_selection selection_dialog
        break
        ;;
      2)
        show_history
        ;;
      *)
        exit 0
        ;;
    esac
  done
}

main "$@"
