#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"
LAUNCHER_DIR="$SCRIPT_DIR/launcher"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
LOG_FILE="$HOME/.config/aihub/install.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

GPU_LABEL=${gpu_mode:-"Unknown"}
HEADLESS_FLAG=${HEADLESS:-0}
MENU_TITLE="AI Workstation Launcher (GPU: $GPU_LABEL)"
log_msg "Opening launcher menu with GPU mode: $GPU_LABEL (HEADLESS=$HEADLESS_FLAG)"

ACTION=$(yad --width=750 --height=520 --center --title="$MENU_TITLE" \
  --list --radiolist \
  --column="Select":R --column="Action" --column="Description" \
  TRUE "🖼️  Run Stable Diffusion WebUI" "Starts the WebUI from ~/AI/WebUI with models in Stable-diffusion/; uses current GPU setup." \
  FALSE "⚙️  Performance Flags" "Toggle FP16, xFormers/DirectML, and low VRAM behavior recorded in ~/.config/aihub/installer.conf." \
  FALSE "🤖  Launch KoboldAI" "Launches KoboldAI from ~/AI/KoboldAI using your downloaded models." \
  FALSE "🧠  Launch SillyTavern" "Opens SillyTavern in ~/AI/SillyTavern with existing API/backends." \
  FALSE "📥  Install or Update LoRAs" "Downloads curated/CivitAI LoRAs into the default ~/AI/LoRAs directory." \
  FALSE "📦  Install or Update Models (Hugging Face)" "Installs LLMs to the default ~/ai-hub/models directory (HEADLESS=$HEADLESS_FLAG)." \
  FALSE "📥  Download Models from CivitAI" "Fetches CivitAI models to the default ~/ai-hub/models directory with GUI prompts by default." \
  FALSE "🆕  Update Installer" "Runs the built-in self-update to refresh installer scripts in this repository." \
  FALSE "🔁  Pull Updates" "Pulls the latest Git changes for AI-Hub into $(basename "$SCRIPT_DIR")." \
  FALSE "ℹ️  View Installer Status" "Opens the AI Hub launcher status panel from $LAUNCHER_DIR." \
  FALSE "🧠  Pair LLM + LoRA (oobabooga)" "Create a launch script pairing ~/AI/oobabooga/models with LoRAs in ~/AI/oobabooga/lora." \
  FALSE "🎭  Pair LLM + LoRA (SillyTavern)" "Choose backend (oobabooga/KoboldAI) and model for SillyTavern pairing from ~/AI." \
  FALSE "🎨  Select LoRA for Preset" "Pick a LoRA from ~/AI/LoRAs to use in pairing presets." \
  FALSE "💾  Save Current Pairing as Preset" "Save the active model/LoRA pairing preset to reuse later." \
  FALSE "📂  Load Saved Pairing Preset" "Load a previously saved pairing preset to quickly apply settings." \
  FALSE "❌  Exit" "Close the launcher without making changes." \
)

case "$ACTION" in
  *"🖼️  Run Stable Diffusion WebUI"*)
    bash "$MODULE_DIR/run_webui.sh"
    ;;
  *"⚙️  Performance Flags"*)
    bash "$MODULE_DIR/performance_flags.sh"
    ;;
  *"🤖  Launch KoboldAI"*)
    bash "$MODULE_DIR/run_kobold.sh"
    ;;
  *"🧠  Launch SillyTavern"*)
    bash "$MODULE_DIR/run_sillytavern.sh"
    ;;
  *"📥  Install or Update LoRAs"*)
    bash "$MODULE_DIR/install_loras.sh"
    ;;
  *"📦  Install or Update Models (Hugging Face)"*)
    bash "$MODULE_DIR/install_models.sh"
    ;;
  *"📥  Download Models from CivitAI"*)
    MODEL_SOURCE="civitai" bash "$MODULE_DIR/install_models.sh"
    ;;
  *"🆕  Update Installer"*)
    bash "$MODULE_DIR/self_update.sh"
    ;;
  *"🔁  Pull Updates"*)
    git -C "$SCRIPT_DIR" pull
    ;;
  *"ℹ️  View Installer Status"*)
    bash "$LAUNCHER_DIR/ai_hub_launcher.sh"
    ;;
  *"🧠  Pair LLM + LoRA (oobabooga)"*)
    bash "$MODULE_DIR/pair_oobabooga.sh"
    ;;
  *"🎭  Pair LLM + LoRA (SillyTavern)"*)
    bash "$MODULE_DIR/pair_sillytavern.sh"
    ;;
  *"🎨  Select LoRA for Preset"*)
    bash "$MODULE_DIR/select_lora.sh"
    ;;
  *"💾  Save Current Pairing as Preset"*)
    bash "$MODULE_DIR/save_pairing_preset.sh"
    ;;
  *"📂  Load Saved Pairing Preset"*)
    bash "$MODULE_DIR/load_pairing_preset.sh"
    ;;
  *"❌  Exit"*)
    exit 0
    ;;

  *)
    yad --info --text="No valid option selected." --title="AI Hub"
    ;;
esac
