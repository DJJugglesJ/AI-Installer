#!/bin/bash

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
)\n
case "$ACTION" in
  *"🖼️  Run Stable Diffusion WebUI"*)
    bash ~/AI-Installer/modules/run_webui.sh
    ;;
  *"🤖  Launch KoboldAI"*)
    bash ~/AI-Installer/modules/run_kobold.sh
    ;;
  *"🧠  Launch SillyTavern"*)
    bash ~/AI-Installer/modules/run_sillytavern.sh
    ;;
  *"📥  Install or Update LoRAs"*)
    bash ~/AI-Installer/modules/install_loras.sh
    ;;
  *"📦  Install or Update Models"*)
    bash ~/AI-Installer/modules/install_models.sh
    ;;
  *"🆕  Update Installer"*)
    bash ~/AI-Installer/modules/self_update.sh
    ;;
  *"🔁  Pull Updates"*)
    git -C ~/AI-Installer pull
    ;;
  *"🧠  Pair LLM + LoRA (oobabooga)"*)
    bash ~/AI-Installer/modules/pair_oobabooga.sh
    ;;
  *"🎭  Pair LLM + LoRA (SillyTavern)"*)
    bash ~/AI-Installer/modules/pair_sillytavern.sh
    ;;
  *"🎨  Select LoRA for Preset"*)
    bash ~/AI-Installer/modules/select_lora.sh
    ;;
  *"💾  Save Current Pairing as Preset"*)
    bash ~/AI-Installer/modules/save_pairing_preset.sh
    ;;
  *"📂  Load Saved Pairing Preset"*)
    bash ~/AI-Installer/modules/load_pairing_preset.sh
    ;;
  *"❌  Exit"*)
    exit 0
    ;;

  *)
    yad --info --text="No valid option selected." --title="AI Hub"
    ;;
esac
