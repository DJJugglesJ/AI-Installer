#!/bin/bash

ACTION=$(yad --width=400 --height=300 --center --title="AI Workstation" \
  --list --radiolist \
  --column="Select" --column="Action" \
  TRUE "🖼️  Run Stable Diffusion WebUI" \
  FALSE "🤖  Launch KoboldAI" \
  FALSE "🧠  Launch SillyTavern" \
  FALSE "📥  Install or Update LoRAs" \
  FALSE "📦  Install or Update Models" \
  FALSE "🔁  Pull Updates" \
  FALSE "❌  Exit")

case "$ACTION" in
  *"Stable Diffusion"*) bash ~/AI-Installer/modules/run_webui.sh ;;
  *"KoboldAI"*) bash ~/AI-Installer/modules/run_kobold.sh ;;
  *"SillyTavern"*) bash ~/AI-Installer/modules/run_sillytavern.sh ;;
  *"LoRAs"*) bash ~/AI-Installer/modules/install_loras.sh ;;
  *"Models"*) bash ~/AI-Installer/modules/install_models.sh ;;
  *"Updates"*) git -C ~/AI-Installer pull ;;
  *"Exit"*) exit 0 ;;
  *) yad --info --text="No valid option selected." --title="AI Hub" ;;
esac
