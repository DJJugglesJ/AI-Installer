#!/bin/bash

# detect_gpu.sh — Identify installed GPU and prompt for driver setup or CPU fallback

CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/aihub/installer.conf}"
LOG_FILE="${LOG_FILE:-$HOME/.config/aihub/install.log}"
mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

NVIDIA_FOUND=$(lspci | grep -i 'NVIDIA')
AMD_FOUND=$(lspci | grep -i 'AMD' | grep -i 'VGA')
INTEL_FOUND=$(lspci | grep -i 'Intel' | grep -i 'VGA')
GPU_DETAILS=$(lspci | grep -Ei 'VGA|3D|Display')

if [[ -n "$NVIDIA_FOUND" ]]; then
  DETECTED_GPU="NVIDIA"
elif [[ -n "$AMD_FOUND" ]]; then
  DETECTED_GPU="AMD"
elif [[ -n "$INTEL_FOUND" ]]; then
  DETECTED_GPU="INTEL"
else
  DETECTED_GPU="UNKNOWN"
fi

GPU_MODE="$DETECTED_GPU"
log_msg "Detected GPU hardware: ${DETECTED_GPU:-unknown}"
[[ -n "$GPU_DETAILS" ]] && log_msg "PCIe GPU entries:\n$GPU_DETAILS"

if [[ -n "$GPU_MODE_OVERRIDE" ]]; then
  GPU_MODE=${GPU_MODE_OVERRIDE^^}
  log_msg "GPU mode overridden via CLI: $GPU_MODE"
elif [[ "${HEADLESS:-0}" -eq 1 ]] && grep -q '^gpu_mode=' "$CONFIG_FILE"; then
  GPU_MODE=$(grep '^gpu_mode=' "$CONFIG_FILE" | cut -d'=' -f2)
  log_msg "Headless mode: loaded GPU mode from config ($GPU_MODE)."
fi

case "$DETECTED_GPU" in
  "NVIDIA")
    DRIVER_HINT="Install recommended NVIDIA proprietary drivers via ubuntu-drivers autoinstall for best performance."
    log_msg "$DRIVER_HINT"
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: skipping NVIDIA driver prompt."
    else
      yad --question --title="NVIDIA GPU Detected" \
        --text="An NVIDIA GPU was detected. Would you like to install the recommended NVIDIA driver using ubuntu-drivers?" \
        --button="Yes!install:0" --button="No:1"
      if [[ $? -eq 0 ]]; then
        sudo apt update
        sudo ubuntu-drivers autoinstall
        log_msg "User opted to install NVIDIA drivers via ubuntu-drivers."
      else
        log_msg "User skipped NVIDIA driver installation prompt."
      fi
    fi
    ;;
  "AMD")
    DRIVER_HINT="For ROCm/AMDGPU acceleration, ensure mesa-vulkan-drivers are installed and see AMD acceleration notes: https://rocm.docs.amd.com/en/latest/deploy/linux/install.html"
    log_msg "$DRIVER_HINT"
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: skipping AMD driver prompt."
    else
      yad --question --title="AMD GPU Detected" \
        --text="An AMD GPU was detected. Would you like to install the recommended open-source AMDGPU/Vulkan drivers (mesa-vulkan-drivers)?\n\nAcceleration notes: https://rocm.docs.amd.com/en/latest/deploy/linux/install.html" \
        --button="Yes!install:0" --button="No:1"
      if [[ $? -eq 0 ]]; then
        sudo apt update
        sudo apt install -y mesa-vulkan-drivers
        log_msg "User opted to install mesa-vulkan-drivers for AMD GPU."
      else
        log_msg "User skipped AMD mesa-vulkan-drivers installation prompt."
      fi
    fi
    ;;
  "INTEL")
    DRIVER_HINT="Intel GPU detected. For acceleration, review Intel oneAPI/OpenVINO guidance: https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html"
    log_msg "$DRIVER_HINT"
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: defaulting Intel detection to CPU fallback."
    else
      yad --info --title="Intel GPU Detected" \
        --text="An Intel GPU was detected. While usable for graphics, most AI tools will fall back to CPU.\n\nTo enable Intel GPU acceleration, you would need to manually configure OpenVINO or oneAPI support.\nIntel acceleration notes: https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html\n\nThe installer will now proceed with CPU fallback unless manually configured."
    fi
    GPU_MODE="CPU"
    ;;
  *)
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: unsupported GPU detected, defaulting to CPU."
    else
      yad --question --title="No Supported GPU Detected" \
        --text="No supported GPU was detected. Would you like to proceed in CPU-only mode (slower)?" \
        --button="Yes!cpu_fallback:0" --button="No:1"
      if [[ $? -ne 0 ]]; then
        echo "Installation aborted by user due to no compatible GPU."
        log_msg "User aborted installation after unsupported GPU detection."
        exit 1
      fi
    fi
    GPU_MODE="CPU"
    ;;
esac

# Fallback setup
if [[ "$GPU_MODE" == "CPU" ]]; then
  echo "[CPU MODE] Proceeding with CPU fallback setup..."
  log_msg "CPU fallback selected. Installing CPU dependencies."
  sudo apt update
  sudo apt install -y libopenblas-dev
fi

# Persist selection to config file
if grep -q '^gpu_mode=' "$CONFIG_FILE"; then
  sed -i "s/^gpu_mode=.*/gpu_mode=$GPU_MODE/" "$CONFIG_FILE"
else
  echo "gpu_mode=$GPU_MODE" >> "$CONFIG_FILE"
fi
log_msg "Final GPU mode recorded as $GPU_MODE"
