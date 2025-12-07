#!/bin/bash

# AI Hub menu launcher
# - Purpose: present a YAD-driven control panel for installs/launchers using recorded config state.
# - Assumptions: installer.conf is readable and YAD is available for interactive selection.
# - Side effects: triggers downstream install/update scripts and logs menu opens for audit.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"
LAUNCHER_DIR="$SCRIPT_DIR/launcher"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
LOG_FILE="$HOME/.config/aihub/install.log"
source "$MODULE_DIR/shell/logging.sh"

GPU_LABEL=${gpu_mode:-"Unknown"}
HEADLESS_FLAG=${HEADLESS:-0}
MENU_TITLE="AI Workstation Launcher (GPU: $GPU_LABEL)"
HEALTH_TEXT=$(HEADLESS=1 "$MODULE_DIR/shell/health_summary.sh")
# Log menu intent before rendering so failed dialog invocations are still captured.
log_event "info" app=aihub event=menu_open gpu_mode="$GPU_LABEL" headless="$HEADLESS_FLAG"

ACTION=$(yad --width=750 --height=520 --center --title="$MENU_TITLE" \
  --text="Health summary:\n${HEALTH_TEXT}" \
  --list --radiolist \
  --column="Select":R --column="Action" --column="Description" \
  TRUE "🖼️  Run Stable Diffusion WebUI" "Starts the WebUI from ~/AI/WebUI with models in Stable-diffusion/; uses current GPU setup." \
  FALSE "⚙️  Performance Flags" "Toggle FP16, xFormers/DirectML, and low VRAM behavior recorded in ~/.config/aihub/installer.conf." \
  FALSE "🤖  Launch KoboldAI" "Launches KoboldAI from ~/AI/KoboldAI using your downloaded models." \
  FALSE "🧠  Launch SillyTavern" "Opens SillyTavern in ~/AI/SillyTavern with existing API/backends." \
  FALSE "📥  Install or Update LoRAs" "Downloads curated/CivitAI LoRAs into the default ~/AI/LoRAs directory." \
  FALSE "📦  Install or Update Models (Hugging Face)" "Installs LLMs to the default ~/ai-hub/models directory (HEADLESS=$HEADLESS_FLAG)." \
  FALSE "🗂️  Browse Curated Models & LoRAs" "Open the manifest browser to select curated downloads without visiting external sites." \
  FALSE "📥  Download Models from CivitAI" "Fetches CivitAI models to the default ~/ai-hub/models directory with GUI prompts by default." \
  FALSE "🧹  Artifact Maintenance" "Prune caches, rotate logs, and verify model/LoRA links." \
  FALSE "🆕  Update Installer" "Runs the built-in self-update to refresh installer scripts in this repository." \
  FALSE "🔁  Pull Updates" "Pulls the latest Git changes for AI-Hub into $(basename "$SCRIPT_DIR")." \
  FALSE "ℹ️  View Installer Status" "Opens the AI Hub launcher status panel from $LAUNCHER_DIR." \
  FALSE "🧠  Pair LLM + LoRA (oobabooga)" "Create a launch script pairing ~/AI/oobabooga/models with LoRAs in ~/AI/oobabooga/lora." \
  FALSE "🎭  Pair LLM + LoRA (SillyTavern)" "Choose backend (oobabooga/KoboldAI) and model for SillyTavern pairing from ~/AI." \
  FALSE "🎨  Select LoRA for Preset" "Pick a LoRA from ~/AI/LoRAs to use in pairing presets." \
  FALSE "💾  Save Current Pairing as Preset" "Save the active model/LoRA pairing preset to reuse later." \
  FALSE "📂  Load Saved Pairing Preset" "Load a previously saved pairing preset to quickly apply settings." \
  FALSE "📊  Health Summary" "Run connectivity, backend, and model-path checks for all apps with remediation hints." \
  FALSE "❌  Exit" "Close the launcher without making changes." \
)

case "$ACTION" in
  *"🖼️  Run Stable Diffusion WebUI"*)
    bash "$MODULE_DIR/shell/run_webui.sh"
    ;;
  *"⚙️  Performance Flags"*)
    bash "$MODULE_DIR/shell/performance_flags.sh"
    ;;
  *"🤖  Launch KoboldAI"*)
    bash "$MODULE_DIR/shell/run_kobold.sh"
    ;;
  *"🧠  Launch SillyTavern"*)
    bash "$MODULE_DIR/shell/run_sillytavern.sh"
    ;;
  *"📥  Install or Update LoRAs"*)
    bash "$MODULE_DIR/shell/install_loras.sh"
    ;;
  *"📦  Install or Update Models (Hugging Face)"*)
    bash "$MODULE_DIR/shell/install_models.sh"
    ;;
  *"🗂️  Browse Curated Models & LoRAs"*)
    bash "$MODULE_DIR/shell/manifest_browser.sh"
    ;;
  *"📥  Download Models from CivitAI"*)
    MODEL_SOURCE="civitai" bash "$MODULE_DIR/shell/install_models.sh"
    ;;
  *"🧹  Artifact Maintenance"*)
    bash "$MODULE_DIR/shell/artifact_manager.sh"
    ;;
  *"🆕  Update Installer"*)
    bash "$MODULE_DIR/shell/self_update.sh"
    ;;
  *"🔁  Pull Updates"*)
    git -C "$SCRIPT_DIR" pull
    ;;
  *"ℹ️  View Installer Status"*)
    bash "$LAUNCHER_DIR/ai_hub_launcher.sh"
    ;;
  *"🧠  Pair LLM + LoRA (oobabooga)"*)
    bash "$MODULE_DIR/shell/pair_oobabooga.sh"
    ;;
  *"🎭  Pair LLM + LoRA (SillyTavern)"*)
    bash "$MODULE_DIR/shell/pair_sillytavern.sh"
    ;;
  *"🎨  Select LoRA for Preset"*)
    bash "$MODULE_DIR/shell/select_lora.sh"
    ;;
  *"💾  Save Current Pairing as Preset"*)
    bash "$MODULE_DIR/shell/save_pairing_preset.sh"
    ;;
  *"📂  Load Saved Pairing Preset"*)
    bash "$MODULE_DIR/shell/load_pairing_preset.sh"
    ;;
  *"📊  Health Summary"*)
    bash "$MODULE_DIR/shell/health_summary.sh"
    ;;
  *"❌  Exit"*)
    exit 0
    ;;

  *)
    yad --info --text="No valid option selected." --title="AI Hub"
    ;;
esac
