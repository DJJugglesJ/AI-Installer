#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
mkdir -p "$(dirname "$LOG_FILE")"
: "${gpu_mode:=Unknown}"

touch "$LOG_FILE"

action_log() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

set_config_value() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

normalize_bool() {
  local raw="$1"
  case "${raw,,}" in
    true|1|yes|y|on)
      echo "true"
      ;;
    *)
      echo "false"
      ;;
  esac
}

supports_fp16=$(normalize_bool "${gpu_supports_fp16:-false}")
supports_xformers=$(normalize_bool "${gpu_supports_xformers:-false}")
supports_directml=$(normalize_bool "${gpu_supports_directml:-false}")

current_fp16=$(normalize_bool "${enable_fp16:-$([[ "$gpu_mode" == "NVIDIA" ]] && echo true || echo false)}")
current_xformers=$(normalize_bool "${enable_xformers:-$supports_xformers}")
current_directml=$(normalize_bool "${enable_directml:-$supports_directml}")
current_low_vram=$(normalize_bool "${enable_low_vram:-false}")

summary_lines=()
summary_lines+=("GPU mode: ${gpu_mode}")
summary_lines+=("FP16 supported: ${supports_fp16}")
summary_lines+=("xFormers supported: ${supports_xformers}")
summary_lines+=("DirectML supported: ${supports_directml}")
[[ -n "$detected_vram_gb" ]] && summary_lines+=("Detected VRAM: ${detected_vram_gb}GB")

info_text=$(printf "%s\\n" "Performance options for Stable Diffusion WebUI." "${summary_lines[@]}")

SELECTION=$(yad --width=500 --height=360 --center --title="Performance flags" \
  --form --align=left --text="${info_text}" \
  --field="Enable FP16 (half precision):CHK" "$current_fp16" \
  --field="Enable xFormers (NVIDIA):CHK" "$current_xformers" \
  --field="Enable DirectML (WSL AMD/Intel):CHK" "$current_directml" \
  --field="Low VRAM mode (--medvram):CHK" "$current_low_vram" \
  --button="Apply:0" --button="Cancel:1")

if [[ $? -ne 0 ]]; then
  exit 0
fi

IFS='|' read -r fp16_choice xformers_choice directml_choice low_vram_choice <<< "$SELECTION"

save_flag() {
  local key="$1" requested="$2" supported="$3" label="$4"
  local normalized
  normalized=$(normalize_bool "$requested")
  if [[ "$normalized" == "true" && "$supported" != "true" ]]; then
    action_log "${label} requested but not supported; disabling."
    normalized="false"
  fi
  set_config_value "$key" "$normalized"
  action_log "${label} set to ${normalized}."
}

save_flag "enable_fp16" "$fp16_choice" "$supports_fp16" "FP16"
save_flag "enable_xformers" "$xformers_choice" "$supports_xformers" "xFormers"
# DirectML conflicts with xFormers; prioritise DirectML when supported
if [[ $(normalize_bool "$directml_choice") == "true" && "$supports_directml" == "true" ]]; then
  set_config_value "enable_directml" "true"
  set_config_value "enable_xformers" "false"
  action_log "DirectML enabled; xFormers disabled due to mutual exclusivity."
else
  save_flag "enable_directml" "$directml_choice" "$supports_directml" "DirectML"
fi
save_flag "enable_low_vram" "$low_vram_choice" "true" "Low VRAM"

action_log "Performance flag update complete."
