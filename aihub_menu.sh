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
QUICKSTART_DOC="$SCRIPT_DIR/docs/quickstart_models.md"

GPU_LABEL=${gpu_mode:-"Unknown"}
HEADLESS_FLAG=${HEADLESS:-0}
MENU_TITLE="AI Workstation Launcher (GPU: $GPU_LABEL)"
HEALTH_TEXT=$(HEADLESS=1 "$MODULE_DIR/shell/health_summary.sh")
# Log menu intent before rendering so failed dialog invocations are still captured.
log_event "info" app=aihub event=menu_open gpu_mode="$GPU_LABEL" headless="$HEADLESS_FLAG"

open_quickstart_doc() {
  if [[ ! -f "$QUICKSTART_DOC" ]]; then
    yad --error --title="Quickstart not found" --text="Expected quickstart at $QUICKSTART_DOC" --width=450 --center
    return
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$QUICKSTART_DOC" >/dev/null 2>&1 && return
  fi

  if command -v open >/dev/null 2>&1; then
    open "$QUICKSTART_DOC" >/dev/null 2>&1 && return
  fi

  yad --width=800 --height=640 --center --title="Model & LoRA Quickstart" --text-info --wrap --fontname="Monospace 10" --filename="$QUICKSTART_DOC"
}

# Keep menu copy concise while still calling out default paths so users know where assets land.
# Update flows are split between "self update" (safe for bundled installs) and a plain git pull for clones.
ACTION=$(yad --width=750 --height=520 --center --title="$MENU_TITLE" \
  --text="Health summary:\n${HEALTH_TEXT}" \
  --list --radiolist \
  --column="Select":R --column="Action" --column="Description" \
  TRUE "🖼️  Run Stable Diffusion WebUI" "Launch WebUI from ~/AI/WebUI using Stable-diffusion/ models and current GPU flags." \
  FALSE "⚙️  Performance Flags" "Review FP16/xFormers/DirectML and low-VRAM toggles saved in ~/.config/aihub/installer.conf." \
  FALSE "🤖  Launch KoboldAI" "Start KoboldAI from ~/AI/KoboldAI with your downloaded models." \
  FALSE "🧠  Launch SillyTavern" "Open SillyTavern in ~/AI/SillyTavern against your existing backends." \
  FALSE "📥  Install or Update LoRAs" "Install or refresh LoRAs in ~/AI/LoRAs (curated + CivitAI)." \
  FALSE "📦  Install or Update Models (Hugging Face)" "Install/update LLMs into ~/ai-hub/models (HEADLESS=$HEADLESS_FLAG)." \
  FALSE "🗂️  Browse Curated Models & LoRAs" "Browse manifests without leaving the menu; queue curated downloads." \
  FALSE "📥  Download Models from CivitAI" "Download CivitAI models into ~/ai-hub/models with optional GUI prompts." \
  FALSE "🧹  Artifact Maintenance" "Prune caches, rotate logs, and verify model/LoRA links." \
  FALSE "🆕  Update Installer" "Self-update bundled installer scripts, then relaunch this menu." \
  FALSE "🔁  Pull Updates" "Run git pull for $(basename "$SCRIPT_DIR") when using a clone." \
  FALSE "ℹ️  View Installer Status" "Opens the AI Hub launcher status panel from $LAUNCHER_DIR." \
  FALSE "🧠  Pair LLM + LoRA (oobabooga)" "Pair an oobabooga model from ~/AI/oobabooga/models with a LoRA in ~/AI/oobabooga/lora." \
  FALSE "🎭  Pair LLM + LoRA (SillyTavern)" "Pick backend (oobabooga/KoboldAI) and model for SillyTavern API pairing." \
  FALSE "🎨  Select LoRA for Preset" "Choose a LoRA from ~/AI/LoRAs to set as the active preset target." \
  FALSE "💾  Save Current Pairing as Preset" "Record the current model/LoRA pairing for reuse." \
  FALSE "📂  Load Saved Pairing Preset" "Apply a saved pairing preset to quickly restore settings." \
  FALSE "📘  Model & LoRA Quickstart" "Open SD1.5/SDXL preset examples and pairing steps (docs/quickstart_models.md)." \
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
  *"📘  Model & LoRA Quickstart"*)
    open_quickstart_doc
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
