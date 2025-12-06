#!/bin/bash

# detect_gpu.sh — Identify installed GPU and prompt for driver setup or CPU fallback

CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/aihub/installer.conf}"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="${LOG_FILE:-$HOME/.config/aihub/install.log}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config_service/config_helpers.sh"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

log_msg "Starting GPU detection flow; log file located at $LOG_FILE"

run_package_install() {
  local description="$1"
  shift
  local cmd=("$@")
  local attempts=0 max_attempts=2

  while (( attempts < max_attempts )); do
    attempts=$((attempts + 1))
    log_msg "Executing package command ($attempts/$max_attempts): ${cmd[*]} for ${description:-packages}"
    if "${cmd[@]}"; then
      log_msg "Package command succeeded for ${description:-packages}"
      return 0
    fi

    local exit_code=$?
    log_msg "Package command failed or was canceled (exit $exit_code) for ${description:-packages}"
    if (( attempts >= max_attempts )); then
      break
    fi

    if command -v yad >/dev/null 2>&1; then
      yad --question --title="Retry ${description:-install}" --text="The last package command failed or was canceled.\nWould you like to retry?" --tooltip="Reconnect your network or re-open the terminal if sudo timed out." --button="Yes!retry:0" --button="No:1"
      [[ $? -eq 0 ]] || break
    fi
  done

  return 1
}

CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load

NVIDIA_FOUND=$(lspci | grep -i 'NVIDIA')
AMD_FOUND=$(lspci | grep -i 'AMD' | grep -i 'VGA')
INTEL_FOUND=$(lspci | grep -i 'Intel' | grep -i 'VGA')
GPU_DETAILS=$(lspci | grep -Ei 'VGA|3D|Display')
GPU_MODULES=$(lsmod | awk '{print $1}' | grep -E 'nvidia|amdgpu|i915' || true)

log_msg "Running lspci scan for GPUs."
log_msg "NVIDIA entries found: $([[ -n "$NVIDIA_FOUND" ]] && echo yes || echo no)"
log_msg "AMD entries found: $([[ -n "$AMD_FOUND" ]] && echo yes || echo no)"
log_msg "Intel entries found: $([[ -n "$INTEL_FOUND" ]] && echo yes || echo no)"
[[ -n "$GPU_MODULES" ]] && log_msg "Kernel modules currently loaded: $GPU_MODULES"

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

if [[ "$DETECTED_GPU" == "NVIDIA" ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    log_msg "nvidia-smi detected; NVIDIA driver likely present."
  else
    log_msg "nvidia-smi not found; proprietary driver may be missing."
  fi
elif [[ "$DETECTED_GPU" == "AMD" ]]; then
  if lsmod | grep -qi amdgpu; then
    log_msg "amdgpu kernel module loaded."
  else
    log_msg "amdgpu kernel module not detected; defaulting to open-source stack."
  fi
elif [[ "$DETECTED_GPU" == "INTEL" ]]; then
  if lsmod | grep -qi i915; then
    log_msg "i915 kernel module loaded for Intel graphics."
  else
    log_msg "i915 kernel module not detected; GPU acceleration may be limited."
  fi
else
  log_msg "No supported GPU modules detected; proceeding with CPU-only expectations."
fi

if [[ -n "$GPU_MODE_OVERRIDE" ]]; then
  GPU_MODE=${GPU_MODE_OVERRIDE^^}
  log_msg "GPU mode overridden via CLI: $GPU_MODE"
elif [[ "${HEADLESS:-0}" -eq 1 && -n "${gpu_mode:-}" ]]; then
  GPU_MODE=${gpu_mode^^}
  log_msg "Headless mode: loaded GPU mode from config (${GPU_MODE:-unknown})."
else
  log_msg "No GPU mode override supplied; using hardware detection defaults."
fi

FP16_SUPPORTED="false"
XFORMERS_SUPPORTED="false"
DIRECTML_SUPPORTED="false"
GPU_VRAM_GB=""
LOW_VRAM_RECOMMENDED="false"
WSL_ENVIRONMENT="false"

if grep -qi microsoft /proc/version 2>/dev/null; then
  WSL_ENVIRONMENT="true"
  log_msg "Detected Windows/WSL kernel signature; DirectML may be available for supported GPUs."
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  mem_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1)
  if [[ -n "$mem_mb" ]]; then
    GPU_VRAM_GB=$((mem_mb / 1024))
    log_msg "Detected NVIDIA VRAM: ${GPU_VRAM_GB}GB"
    if [[ "$GPU_VRAM_GB" -lt 8 ]]; then
      LOW_VRAM_RECOMMENDED="true"
      log_msg "VRAM below 8GB; recommending low VRAM flags by default."
    fi
  fi
fi

case "$DETECTED_GPU" in
  "NVIDIA")
    DRIVER_HINT="Install recommended NVIDIA proprietary drivers via ubuntu-drivers autoinstall for best performance. (Help: https://ubuntu.com/server/docs/nvidia-drivers-installation)"
    log_msg "$DRIVER_HINT"
    FP16_SUPPORTED="true"
    if command -v nvidia-smi >/dev/null 2>&1; then
      XFORMERS_SUPPORTED="true"
      log_msg "NVIDIA driver detected; xFormers acceleration is supported."
    else
      XFORMERS_SUPPORTED="false"
      log_msg "xFormers acceleration disabled because NVIDIA drivers were not detected."
    fi
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: skipping NVIDIA driver prompt."
    else
      yad --question --title="NVIDIA GPU Detected" \
        --text="An NVIDIA GPU was detected. Would you like to install the recommended NVIDIA driver using ubuntu-drivers?\n\nHelp: https://ubuntu.com/server/docs/nvidia-drivers-installation" \
        --button="Yes!install:0" --button="No:1"
      if [[ $? -eq 0 ]]; then
        run_package_install "NVIDIA driver update" sudo apt update
        run_package_install "NVIDIA driver installation" sudo ubuntu-drivers autoinstall
        log_msg "User opted to install NVIDIA drivers via ubuntu-drivers."
      else
        log_msg "User skipped NVIDIA driver installation prompt."
      fi
    fi
    ;;
  "AMD")
    DRIVER_HINT="For ROCm/AMDGPU acceleration, ensure mesa-vulkan-drivers are installed and see AMD acceleration notes: https://rocm.docs.amd.com/en/latest/deploy/linux/install.html"
    log_msg "$DRIVER_HINT"
    FP16_SUPPORTED="false"
    if [[ "$WSL_ENVIRONMENT" == "true" ]]; then
      DIRECTML_SUPPORTED="true"
      log_msg "WSL environment detected; DirectML toggle will be offered for AMD GPUs."
    else
      log_msg "DirectML not available outside Windows/WSL for AMD; leaving toggle disabled."
    fi
    log_msg "AMD GPU detected; default GPU mode set to AMD. Without ROCm/Vulkan tuning, some workloads may still fall back to CPU."
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: skipping AMD driver prompt."
    else
      yad --question --title="AMD GPU Detected" \
        --text="An AMD GPU was detected. Would you like to install the recommended open-source AMDGPU/Vulkan drivers (mesa-vulkan-drivers)?\n\nAcceleration notes: https://rocm.docs.amd.com/en/latest/deploy/linux/install.html\nVulkan troubleshooting: https://docs.mesa3d.org/install.html" \
        --button="Yes!install:0" --button="No:1"
      if [[ $? -eq 0 ]]; then
        run_package_install "AMD Vulkan prerequisites" sudo apt update
        run_package_install "mesa-vulkan-drivers" sudo apt install -y mesa-vulkan-drivers
        log_msg "User opted to install mesa-vulkan-drivers for AMD GPU."
      else
        log_msg "User skipped AMD mesa-vulkan-drivers installation prompt."
      fi
    fi
    ;;
  "INTEL")
    DRIVER_HINT="Intel GPU detected. For acceleration, review Intel oneAPI/OpenVINO guidance: https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html"
    log_msg "$DRIVER_HINT"
    FP16_SUPPORTED="false"
    if [[ "$WSL_ENVIRONMENT" == "true" ]]; then
      DIRECTML_SUPPORTED="true"
      log_msg "DirectML may be available for Intel GPUs under WSL; exposing toggle."
    else
      log_msg "DirectML disabled because Intel GPU is running outside Windows/WSL."
    fi
    log_msg "Intel GPU detected; installer will proceed with CPU fallback unless OpenVINO/oneAPI is configured manually."
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: defaulting Intel detection to CPU fallback."
    else
      yad --info --title="Intel GPU Detected" \
        --text="An Intel GPU was detected. While usable for graphics, most AI tools will fall back to CPU.\n\nTo enable Intel GPU acceleration, you would need to manually configure OpenVINO or oneAPI support.\nIntel acceleration notes: https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html\nGPU driver help: https://dgpu-docs.intel.com/driver/installation.html\n\nThe installer will now proceed with CPU fallback unless manually configured." --tooltip="OpenVINO/oneAPI required for acceleration"
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

# Record capability flags and defaults
[[ -n "$GPU_VRAM_GB" ]] && config_set "gpu.detected_vram_gb" "$GPU_VRAM_GB"
config_set "gpu.supports_fp16" "$FP16_SUPPORTED"
config_set "gpu.supports_xformers" "$XFORMERS_SUPPORTED"
config_set "gpu.supports_directml" "$DIRECTML_SUPPORTED"
if [[ -z "${enable_fp16+x}" ]]; then
  config_set "performance.enable_fp16" $([[ "$GPU_MODE" == "NVIDIA" ]] && echo "true" || echo "false")
fi
if [[ -z "${enable_xformers+x}" ]]; then
  config_set "performance.enable_xformers" "$XFORMERS_SUPPORTED"
fi
if [[ -z "${enable_directml+x}" ]]; then
  config_set "performance.enable_directml" "false"
fi
if [[ -z "${enable_low_vram+x}" ]]; then
  config_set "performance.enable_low_vram" "$LOW_VRAM_RECOMMENDED"
fi
[[ "$LOW_VRAM_RECOMMENDED" == "true" ]] && log_msg "Low VRAM recommendation recorded; medvram flag will be available."

# Fallback setup
if [[ "$GPU_MODE" == "CPU" ]]; then
  echo "[CPU MODE] Proceeding with CPU fallback setup..."
  log_msg "CPU fallback selected. Installing CPU dependencies."
  sudo apt update
  sudo apt install -y libopenblas-dev
fi

  # Persist selection to config file
  config_set "gpu.mode" "${GPU_MODE,,}"
  config_set "gpu.detected_gpu" "$DETECTED_GPU"
  log_msg "Final GPU mode recorded as $GPU_MODE"
  log_msg "Detection summary: hardware=$DETECTED_GPU, gpu_mode=$GPU_MODE"
