#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/aihub"
LOG_FILE="$CONFIG_DIR/install.log"
STATE_FILE="$CONFIG_DIR/artifacts.json"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$CONFIG_DIR/config.yaml}"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-$CONFIG_DIR/installer.conf}"

HEADLESS="${HEADLESS:-0}"
DO_SCAN=0
DO_PRUNE=0
DO_ROTATE=0
DO_VERIFY=0
AUTO_MODE=0
ARTIFACT_RECORD_TYPE=""
ARTIFACT_RECORD_PATH=""
SCHEDULE_DAYS=""

source "$SCRIPT_DIR/config_service/config_helpers.sh"
CONFIG_ENV_FILE="$CONFIG_ENV_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load 2>/dev/null

mkdir -p "$CONFIG_DIR"
touch "$LOG_FILE"

MODEL_DIRS=("${aihub_model_dir:-$HOME/ai-hub/models}" "$HOME/AI/WebUI/models/Stable-diffusion")
LORA_DIRS=("${aihub_lora_dir:-$HOME/AI/LoRAs}" "$HOME/AI/oobabooga/loras")
CACHE_DIRS=("$HOME/.cache/aihub" "/tmp/aihub" "/tmp/civitai_cache")
LOG_ROTATE_THRESHOLD_MB="${artifacts_log_rotate_mb:-5}"
CACHE_RETENTION_DAYS="${artifacts_cache_retention_days:-7}"
MODEL_THRESHOLD_GB="${artifacts_model_threshold_gb:-150}"
LORA_THRESHOLD_GB="${artifacts_lora_threshold_gb:-60}"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

human_size() {
  local size_bytes="$1"
  local units=(B KB MB GB TB)
  local unit=0
  local value="$size_bytes"

  while [[ "$value" -ge 1024 && $unit -lt 4 ]]; do
    value=$((value / 1024))
    unit=$((unit + 1))
  done

  printf "%s %s" "$value" "${units[$unit]}"
}

ensure_state_file() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"records": [], "last_maintenance": ""}' >"$STATE_FILE"
  fi
}

upsert_record() {
  local type="$1" path="$2" status="$3" size="$4" target="$5"
  ensure_state_file
  local tmp
  tmp=$(mktemp)
  jq --arg type "$type" --arg path "$path" --arg status "$status" \
    --arg target "$target" --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson size "$size" '
      .records = (.records // []) | .records |= map(select(.path != $path))
      | .records += [{"type": $type, "path": $path, "status": $status, "size_bytes": $size, "target": $target, "last_seen": $time}]
    ' "$STATE_FILE" >"$tmp" && mv "$tmp" "$STATE_FILE"
}

record_artifact() {
  local type="$1" path="$2"
  local size=0 status="missing" target=""

  if [[ -L "$path" ]]; then
    target=$(readlink -f "$path" || true)
    if [[ -e "$path" ]]; then
      status="symlink_ok"
      size=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
    else
      status="symlink_broken"
    fi
  elif [[ -e "$path" ]]; then
    status="ok"
    size=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
  fi

  upsert_record "$type" "$path" "$status" "${size:-0}" "$target"
  log_msg "Tracked $type: $path (${status}, $(human_size "${size:-0}"))"
}

scan_dir_for_artifacts() {
  local type="$1" dir="$2"
  [[ -d "$dir" ]] || return
  while IFS= read -r file; do
    record_artifact "$type" "$file"
  done < <(find "$dir" -maxdepth 2 -type f -regextype posix-egrep -regex ".*\\.(safetensors|ckpt|gguf|bin|pth|pt)$")
}

scan_artifacts() {
  for dir in "${MODEL_DIRS[@]}"; do
    scan_dir_for_artifacts "model" "$dir"
  done
  for dir in "${LORA_DIRS[@]}"; do
    scan_dir_for_artifacts "lora" "$dir"
  done
  for dir in "${CACHE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    record_artifact "cache" "$dir"
  done
}

prune_old_artifacts() {
  local removed=0
  for dir in "${CACHE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      log_msg "Pruning stale cache: $file"
      rm -f "$file" && removed=$((removed + 1))
    done < <(find "$dir" -type f -mtime "+$CACHE_RETENTION_DAYS" -print)

    while IFS= read -r file; do
      log_msg "Removing partial download: $file"
      rm -f "$file" && removed=$((removed + 1))
    done < <(find "$dir" -type f -regextype posix-egrep -regex ".*\\.(part|tmp)$" -print)
  done

  if [[ $removed -eq 0 ]]; then
    log_msg "No cached artifacts qualified for pruning (retention ${CACHE_RETENTION_DAYS}d)."
  fi
}

rotate_logs() {
  local threshold_bytes=$((LOG_ROTATE_THRESHOLD_MB * 1024 * 1024))
  local current_size
  current_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  if [[ "$current_size" -lt "$threshold_bytes" ]]; then
    log_msg "Log rotation skipped; size $(human_size "$current_size") below threshold ${LOG_ROTATE_THRESHOLD_MB}MB."
    return
  fi

  for i in {3..1}; do
    if [[ -f "$LOG_FILE.$i" ]]; then
      mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
    fi
  done
  mv "$LOG_FILE" "$LOG_FILE.1"
  touch "$LOG_FILE"
  log_msg "Rotated install.log (previous size $(human_size "$current_size"))."
}

verify_symlinks() {
  local issues=0
  for dir in "${MODEL_DIRS[@]}" "${LORA_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r link; do
      local target
      target=$(readlink -f "$link" || true)
      if [[ -e "$link" ]]; then
        log_msg "Verified symlink: $link -> ${target:-unknown}"
      else
        log_msg "Broken symlink detected: $link -> ${target:-missing}"
        issues=$((issues + 1))
      fi
    done < <(find "$dir" -maxdepth 2 -type l)
  done

  if [[ $issues -eq 0 ]]; then
    log_msg "Symlink verification complete with no issues detected."
  fi
}

total_size_warning() {
  local total_models=0 total_loras=0
  for dir in "${MODEL_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    total_models=$((total_models + $(du -sb "$dir" 2>/dev/null | awk '{print $1}') ))
  done
  for dir in "${LORA_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    total_loras=$((total_loras + $(du -sb "$dir" 2>/dev/null | awk '{print $1}') ))
  done

  local model_threshold_bytes=$((MODEL_THRESHOLD_GB * 1024 * 1024 * 1024))
  local lora_threshold_bytes=$((LORA_THRESHOLD_GB * 1024 * 1024 * 1024))

  if [[ "$total_models" -gt "$model_threshold_bytes" ]]; then
    log_msg "Model footprint $(human_size "$total_models") exceeds threshold ${MODEL_THRESHOLD_GB}GB. Consider pruning old models."
  fi
  if [[ "$total_loras" -gt "$lora_threshold_bytes" ]]; then
    log_msg "LoRA footprint $(human_size "$total_loras") exceeds threshold ${LORA_THRESHOLD_GB}GB. Consider pruning old LoRAs."
  fi
}

update_last_maintenance() {
  ensure_state_file
  local tmp
  tmp=$(mktemp)
  jq --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.last_maintenance = $time' "$STATE_FILE" >"$tmp" && mv "$tmp" "$STATE_FILE"
  config_set "artifacts.last_maintenance" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null || true
}

interactive_menu() {
  if ! command -v yad >/dev/null 2>&1; then
    DO_SCAN=1; DO_PRUNE=1; DO_ROTATE=1; DO_VERIFY=1; AUTO_MODE=1
    return
  fi

  local response
  response=$(yad --list --checklist --width=700 --height=400 --title="Artifact Manager" \
    --column="Run":CHK --column="Task" --column="Description" \
    TRUE "Scan artifacts" "Record current models, LoRAs, and caches." \
    TRUE "Prune caches" "Remove stale caches and partial downloads." \
    TRUE "Rotate logs" "Rotate install.log if above threshold." \
    TRUE "Verify symlinks" "Confirm linked models/LoRAs are valid.")

  [[ -z "$response" ]] && exit 0

  if echo "$response" | grep -q "Scan artifacts"; then DO_SCAN=1; fi
  if echo "$response" | grep -q "Prune caches"; then DO_PRUNE=1; fi
  if echo "$response" | grep -q "Rotate logs"; then DO_ROTATE=1; fi
  if echo "$response" | grep -q "Verify symlinks"; then DO_VERIFY=1; fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --scan              Record current artifacts (models, LoRAs, caches).
  --prune             Remove stale caches and partial downloads.
  --rotate-logs       Rotate install.log when above threshold.
  --verify-links      Check symlinks for tracked models/LoRAs.
  --auto              Run all maintenance steps in headless mode.
  --record <type> <path>  Track a specific artifact path.
  --schedule-days <n> Persist preferred maintenance cadence in config.
  --headless          Skip GUI prompts.
  -h, --help          Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan) DO_SCAN=1 ;;
    --prune) DO_PRUNE=1 ;;
    --rotate-logs) DO_ROTATE=1 ;;
    --verify-links) DO_VERIFY=1 ;;
    --auto) DO_SCAN=1; DO_PRUNE=1; DO_ROTATE=1; DO_VERIFY=1; AUTO_MODE=1 ;;
    --record)
      ARTIFACT_RECORD_TYPE="$2"
      ARTIFACT_RECORD_PATH="$3"
      shift 2
      ;;
    --schedule-days)
      SCHEDULE_DAYS="$2"
      shift
      ;;
    --headless) HEADLESS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
  shift
done

if [[ -n "$SCHEDULE_DAYS" ]]; then
  config_set "artifacts.maintenance_days" "$SCHEDULE_DAYS" 2>/dev/null || true
  log_msg "Preferred maintenance cadence set to every ${SCHEDULE_DAYS} day(s)."
fi

if [[ -n "$ARTIFACT_RECORD_TYPE" && -n "$ARTIFACT_RECORD_PATH" ]]; then
  record_artifact "$ARTIFACT_RECORD_TYPE" "$ARTIFACT_RECORD_PATH"
  exit 0
fi

if [[ $DO_SCAN -eq 0 && $DO_PRUNE -eq 0 && $DO_ROTATE -eq 0 && $DO_VERIFY -eq 0 ]]; then
  if [[ "$HEADLESS" -eq 1 ]]; then
    DO_SCAN=1; DO_PRUNE=1; DO_ROTATE=1; DO_VERIFY=1; AUTO_MODE=1
  else
    interactive_menu
  fi
fi

[[ $DO_SCAN -eq 1 ]] && scan_artifacts
[[ $DO_PRUNE -eq 1 ]] && prune_old_artifacts
[[ $DO_ROTATE -eq 1 ]] && rotate_logs
[[ $DO_VERIFY -eq 1 ]] && verify_symlinks

total_size_warning
update_last_maintenance

if [[ $AUTO_MODE -eq 1 && "$HEADLESS" -eq 0 ]]; then
  yad --info --title="Artifact maintenance" --text="Cleanup tasks completed. Check install.log for details." --width=400
fi
