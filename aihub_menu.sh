#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

ACTION=$(yad --width=450 --height=450 --center --title="AI Workstation Launcher" \
  --list --radiolist \
  --column="Select" --column="Action"
  FALSE "🖼️  Run Stable Diffusion WebUI" \
  FALSE "🤖  Launch KoboldAI" \
  FALSE "🧠  Launch SillyTavern" \
  FALSE "📥  Install or Update LoRAs" \
  FALSE "📦  Install or Update Models" \
  FALSE "🆕  Update Installer" \
  FALSE "🔁  Pull Updates" \
  FALSE "🧠  Pair LLM + LoRA (oobabooga)" \
  FALSE "🎭  Pair LLM + LoRA (SillyTavern)" \
  FALSE "🎨  Select LoRA for Preset" \
  FALSE "💾  Save Current Pairing as Preset" \
  FALSE "📂  Load Saved Pairing Preset" \
  FALSE "❌  Exit" \
) 

case "$ACTION" in
  *"🖼️  Run Stable Diffusion WebUI"*)
    bash "$MODULE_DIR/run_webui.sh"
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
  *"📦  Install or Update Models"*)
    bash "$MODULE_DIR/install_models.sh"
    ;;
  *"🆕  Update Installer"*)
    bash "$MODULE_DIR/self_update.sh"
    ;;
  *"🔁  Pull Updates"*)
    git -C "$SCRIPT_DIR" pull
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
