#!/bin/bash

# detect_gpu.sh — Identify installed GPU and prompt for driver setup or CPU fallback

NVIDIA_FOUND=$(lspci | grep -i 'NVIDIA')
AMD_FOUND=$(lspci | grep -i 'AMD' | grep -i 'VGA')
INTEL_FOUND=$(lspci | grep -i 'Intel' | grep -i 'VGA')

if [[ ! -z "$NVIDIA_FOUND" ]]; then
  GPU_TYPE="NVIDIA"
elif [[ ! -z "$AMD_FOUND" ]]; then
  GPU_TYPE="AMD"
elif [[ ! -z "$INTEL_FOUND" ]]; then
  GPU_TYPE="INTEL"
else
  GPU_TYPE="UNKNOWN"
fi

case "$GPU_TYPE" in
  "NVIDIA")
    yad --question --title="NVIDIA GPU Detected" \
      --text="An NVIDIA GPU was detected. Would you like to install the recommended NVIDIA driver using ubuntu-drivers?" \
      --button="Yes!install:0" --button="No:1"
    if [[ $? -eq 0 ]]; then
      sudo apt update
      sudo ubuntu-drivers autoinstall
    fi
    ;;
  "AMD")
    yad --question --title="AMD GPU Detected" \
      --text="An AMD GPU was detected. Would you like to install the ROCm stack for AI workloads?" \
      --button="Yes!install_rocm:0" --button="No:1"
    if [[ $? -eq 0 ]]; then
      sudo apt update
      sudo apt install -y rocm-dkms
    fi
    ;;
  "INTEL")
    yad --info --title="Intel GPU Detected" \
      --text="An Intel GPU was detected. While usable for graphics, most AI tools will fall back to CPU.\n\nTo enable Intel GPU acceleration, you would need to manually configure OpenVINO or oneAPI support.\n\nThe installer will now proceed with CPU fallback unless manually configured."
    GPU_TYPE="CPU"
    ;;
  *)
    yad --question --title="No Supported GPU Detected" \
      --text="No supported GPU was detected. Would you like to proceed in CPU-only mode (slower)?" \
      --button="Yes!cpu_fallback:0" --button="No:1"
    if [[ $? -ne 0 ]]; then
      echo "Installation aborted by user due to no compatible GPU."
      exit 1
    fi
    GPU_TYPE="CPU"
    ;;
esac

# Fallback setup
if [[ "$GPU_TYPE" == "CPU" ]]; then
  echo "[CPU MODE] Proceeding with CPU fallback setup..."
  sudo apt update
  sudo apt install -y libopenblas-dev
fi
