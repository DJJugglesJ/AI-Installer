#!/bin/bash
set -euo pipefail

DOWNLOAD_STATUS_FILE="${DOWNLOAD_STATUS_FILE:-}"
DOWNLOAD_LOG_FILE="${DOWNLOAD_LOG_FILE:-${LOG_FILE:-}}"
DOWNLOAD_OFFLINE_BUNDLE="${DOWNLOAD_OFFLINE_BUNDLE:-${AIHUB_OFFLINE_BUNDLE:-${OFFLINE_BUNDLE_PATH:-}}}"

# Write a message to the installer log or stdout.
download_log() {
  local message="$1"
  if [ -n "$DOWNLOAD_LOG_FILE" ]; then
    mkdir -p "$(dirname "$DOWNLOAD_LOG_FILE")"
    echo "$(date): $message" >> "$DOWNLOAD_LOG_FILE"
  else
    echo "$message"
  fi
}

# Emit a structured status line for the web launcher to consume.
emit_status_event() {
  local level="$1" event="$2" message="$3" detail="${4:-}" detail_json="${5:-}"
  [ -z "$DOWNLOAD_STATUS_FILE" ] && return 0

  mkdir -p "$(dirname "$DOWNLOAD_STATUS_FILE")"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq -c -n \
    --arg ts "$timestamp" \
    --arg lvl "$level" \
    --arg ev "$event" \
    --arg msg "$message" \
    --arg detail "$detail" \
    --arg detail_json "$detail_json" \
    '{timestamp:$ts, level:$lvl, event:$ev, message:$msg, detail: ((($detail_json | select(length>0) | try fromjson catch $detail) // $detail) // "")}' >> "$DOWNLOAD_STATUS_FILE"
}

check_mirror_health() {
  local url="$1" label="${2:-mirror}";
  if python3 - "$url" <<'PY'
import sys
import urllib.error
import urllib.request
url = sys.argv[1]
try:
    with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=8) as resp:
        code = getattr(resp, "status", 0) or getattr(resp, "code", 0)
        if code and int(code) >= 400:
            sys.exit(1)
except Exception:
    sys.exit(1)
PY
  then
    download_log "Mirror healthy ($label): $url"
    emit_status_event "info" "mirror_healthy" "Mirror responded" "$label"
    return 0
  fi

  download_log "Mirror failed health check ($label): $url"
  emit_status_event "warning" "mirror_unreachable" "Mirror did not respond" "$label"
  return 1
}

run_downloader() {
  local tool="$1" url="$2" dest="$3" header="${4:-}" label="${5:-download}"
  download_log "Downloader start [$label]: $tool -> $url"
  mkdir -p "$(dirname "$dest")"
  case "$tool" in
    aria2c)
      local args=(
        --continue=true
        --max-tries=3
        --retry-wait=5
        --auto-file-renaming=false
        --allow-overwrite=true
        --max-resume-failure-tries=5
        --dir="$(dirname "$dest")"
        --out="$(basename "$dest")"
      )
      [ -n "$header" ] && args+=(--header="$header")
      aria2c "${args[@]}" "$url"
      ;;
    wget)
      local args=(
        --continue
        --show-progress
        --tries=3
        --retry-connrefused
        --waitretry=5
        --timeout=30
        -O "$dest"
      )
      [ -n "$header" ] && args+=(--header="$header")
      wget "${args[@]}" "$url"
      ;;
    *)
      return 1
      ;;
  esac
}

verify_checksum() {
  local file="$1" expected="$2" remove_on_fail="${3:-1}"
  if [ -z "$expected" ] || [ "$expected" = "null" ]; then
    download_log "Checksum not provided for $(basename "$file"); skipping verification"
    emit_status_event "info" "checksum_skipped" "Checksum not provided for $(basename "$file")"
    return 0
  fi

  local actual
  actual=$(sha256sum "$file" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    emit_status_event "error" "checksum_failed" "Checksum mismatch for $(basename "$file")" "$actual"
    download_log "Checksum mismatch for $file (expected: $expected, got: $actual); removing corrupt download"
    if [ "$remove_on_fail" -eq 1 ]; then
      rm -f "$file"
    fi
    return 1
  fi

  download_log "Checksum verified for $(basename "$file")"
  emit_status_event "info" "checksum_ok" "Verified checksum for $(basename "$file")"
  return 0
}

# shellcheck disable=SC2120
# Supports two signatures for backwards compatibility:
# download_with_retries url dest checksum mirrors
# download_with_retries url dest header checksum mirrors
# shellcheck disable=SC2317
download_with_retries() {
  local url="$1" dest="$2"
  local header="" expected_checksum="" mirror_list=""
  if [ $# -ge 5 ]; then
    header="$3"
    expected_checksum="$4"
    mirror_list="$5"
  else
    expected_checksum="$3"
    mirror_list="$4"
  fi

  local downloaders=()
  local max_attempts=3
  local backoff_start=5
  local urls=("$url")
  local current_url=""
  local failures=()
  local offline_bundle="$DOWNLOAD_OFFLINE_BUNDLE"
  local dest_basename
  dest_basename="$(basename "$dest")"

  if [ -n "$offline_bundle" ] && [ -d "$offline_bundle" ]; then
    offline_bundle="$offline_bundle/$dest_basename"
  fi

  if [ -f "$dest" ] && verify_checksum "$dest" "$expected_checksum"; then
    emit_status_event "info" "already_present" "Existing file verified; skipping download" "" "{\"path\": \"$dest\"}"
    download_log "Existing file already matches expected checksum: $dest"
    return 0
  fi

  if [ -n "$offline_bundle" ] && [ -f "$offline_bundle" ]; then
    emit_status_event "info" "offline_candidate" "Validating offline bundle for $dest_basename" "" "{\"source\": \"$offline_bundle\"}"
    if verify_checksum "$offline_bundle" "$expected_checksum" 0; then
      mkdir -p "$(dirname "$dest")"
      cp "$offline_bundle" "$dest"
      emit_status_event "info" "offline_used" "Used offline bundle for $dest_basename" "" "{\"source\": \"$offline_bundle\", \"dest\": \"$dest\"}"
      download_log "Copied $offline_bundle to $dest (checksum verified)"
      return 0
    else
      emit_status_event "warning" "offline_invalid" "Offline bundle checksum mismatch" "$offline_bundle"
      download_log "Offline bundle failed checksum for $dest_basename; continuing with remote download"
    fi
  fi

  if [[ -n "$mirror_list" ]]; then
    while IFS= read -r mirror; do
      [[ -n "$mirror" ]] && urls+=("$mirror")
    done <<< "$mirror_list"
  fi

  command -v aria2c >/dev/null 2>&1 && downloaders+=(aria2c)
  command -v wget >/dev/null 2>&1 && downloaders+=(wget)

  for idx in "${!urls[@]}"; do
    current_url="${urls[$idx]}"
    local mirror_label="mirror $((idx + 1))/${#urls[@]}"
    local detail_json
    detail_json=$(jq -nc --arg url "$current_url" --arg label "$mirror_label" --argjson index "$((idx + 1))" --argjson total "${#urls[@]}" '{url:$url,label:$label,index:$index,total:$total}')

    if ! check_mirror_health "$current_url" "$mirror_label"; then
      failures+=("Health check failed for $current_url")
      emit_status_event "warning" "mirror_unhealthy" "Skipping mirror after failed probe" "" "$detail_json"
      if (( idx + 1 < ${#urls[@]} )); then
        emit_status_event "warning" "mirror_fallback" "Switching to next mirror for $(basename "$dest")" "$current_url" "$detail_json"
      fi
      continue
    fi

    emit_status_event "info" "mirror_selected" "Using mirror $mirror_label" "" "$detail_json"

    emit_status_event "info" "download_start" "Starting download for $(basename "$dest")" "$current_url"
    download_log "Starting download: $dest from $current_url using ${downloaders[*]} (${mirror_label})"

    if [ -f "$dest" ]; then
      local existing_size
      existing_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
      emit_status_event "info" "resume" "Resuming existing file $(basename "$dest")" "$current_url" "{\"bytes_present\": $existing_size}"
      download_log "Resuming existing file $dest ($existing_size bytes present)"
    fi

    for ((i = 0; i < ${#downloaders[@]}; i++)); do
      local downloader="${downloaders[$i]}"
      local attempt=1
      local backoff=$backoff_start

      while [ $attempt -le $max_attempts ]; do
        local attempt_label="$mirror_label attempt $attempt via $downloader"
        if [ $attempt -gt 1 ]; then
          emit_status_event "warning" "retry" "Retry $attempt for $(basename "$dest")" "$downloader"
          download_log "Retry $attempt_label for $dest (url: $current_url)"
          sleep $backoff
          backoff=$((backoff * 2))
        else
          download_log "Initiating $attempt_label for $dest"
        fi

        emit_status_event "info" "download_attempt" "Attempting download via $downloader" "$current_url"
        if run_downloader "$downloader" "$current_url" "$dest" "$header" "$attempt_label"; then
          if verify_checksum "$dest" "$expected_checksum"; then
            download_log "Download succeeded with $downloader from $current_url (${mirror_label})"
            emit_status_event "info" "download_complete" "Completed download for $(basename "$dest")" "$downloader"
            return 0
          else
            failures+=("Checksum failed via $downloader at $current_url")
          fi
        else
          failures+=("Downloader error via $downloader at $current_url (attempt $attempt)")
          emit_status_event "warning" "downloader_error" "Downloader error via $downloader" "$current_url"
        fi

        attempt=$((attempt + 1))
      done

      if [ $((i + 1)) -lt ${#downloaders[@]} ]; then
        emit_status_event "warning" "downloader_switch" "Switching downloader for $(basename "$dest")" "$downloader"
        download_log "$downloader exhausted; switching to ${downloaders[$((i + 1))]} for $current_url"
      fi
    done

    if (( idx + 1 < ${#urls[@]} )); then
      emit_status_event "warning" "mirror_fallback" "Switching to next mirror for $(basename "$dest")" "$current_url"
      download_log "Primary URL failed for $dest; moving to mirror $((idx + 2))"
    fi
  done

  emit_status_event "error" "download_failed" "Unable to download $(basename "$dest")" "${failures[*]}"
  download_log "Download failed after attempting ${downloaders[*]} and mirrors: $dest (failures: ${failures[*]})"
  return 1
}
