#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

ACTION=$(yad --width=400 --height=300 --center --title="AI Workstation" \
  --list --radiolist \
  --column="Select" --column="Action"\
  FALSE "🎭  Pair LLM + LoRA (SillyTavern)"\
  FALSE "🧠  Pair LLM + LoRA (oobabooga)"\
  FALSE "🆕  Update Installer" \
  TRUE "🖼️  Run Stable Diffusion WebUI" \
  FALSE "🤖  Launch KoboldAI" \
  FALSE "🧠  Launch SillyTavern" \
  FALSE "📥  Install or Update LoRAs" \
  FALSE "📦  Install or Update Models" \
  FALSE "🔁  Pull Updates" \
  FALSE "❌  Exit")

case "$ACTION" in
  *"Pair LLM + LoRA (SillyTavern)"*)
    bash ~/AI-Installer/modules/pair_sillytavern.sh
    ;;
  *"Pair LLM + LoRA (oobabooga)"*)
    bash ~/AI-Installer/modules/pair_oobabooga.sh
    ;;
  *"Update Installer"*)
    bash ~/AI-Installer/modules/self_update.sh
    ;;
  *"Stable Diffusion"*)
    if [ "$webui_installed" != "true" ]; then
      yad --info --text="WebUI has not been installed yet. Please install it first." --title="Missing Component"
    else
      bash ~/AI-Installer/modules/run_webui.sh
    fi
    ;;
  *"KoboldAI"*)
    if [ "$kobold_installed" != "true" ]; then
      yad --info --text="KoboldAI has not been installed yet. Please install it first." --title="Missing Component"
    else
      bash ~/AI-Installer/modules/run_kobold.sh
    fi
    ;;
  *"SillyTavern"*)
    bash ~/AI-Installer/modules/run_sillytavern.sh
    ;;
  *"LoRAs"*)
    bash ~/AI-Installer/modules/install_loras.sh
    ;;
  *"Models"*)
    bash ~/AI-Installer/modules/install_models.sh
    ;;
  *"Updates"*)
    git -C ~/AI-Installer pull
    ;;
  *"Exit"*)
    exit 0
    ;;
  *)
    yad --info --text="No valid option selected." --title="AI Hub"
    ;;
esac
