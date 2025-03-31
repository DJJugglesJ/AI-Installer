#!/bin/bash

# Load config or initialize
CONFIG_FILE="$HOME/.aihub/config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

if [ ! -f "$CONFIG_FILE" ]; then
    selected_apps=$(yad --list --checklist \
        --title="Select AI Tools to Install" \
        --width=600 --height=300 \
        --column="Install" --column="Tool" --column="Description" \
        TRUE "StableDiffusion" "Image generation with A1111 WebUI" \
        TRUE "KoboldAI" "Lightweight RP/Story-based LLM frontend" \
        TRUE "SillyTavern" "Roleplay UI with characters and memory" \
        TRUE "Oobabooga" "Multi-backend LLM chat with local model support")

    # Convert selection to JSON
    sd=false; kobold=false; silly=false; ooba=false
    [[ "$selected_apps" == *StableDiffusion* ]] && sd=true
    [[ "$selected_apps" == *KoboldAI* ]] && kobold=true
    [[ "$selected_apps" == *SillyTavern* ]] && silly=true
    [[ "$selected_apps" == *Oobabooga* ]] && ooba=true

    echo "{
      \"apps\": {
        \"StableDiffusion\": $sd,
        \"KoboldAI\": $kobold,
        \"SillyTavern\": $silly,
        \"Oobabooga\": $ooba,
        \"LoRAInstaller\": true,
        \"ModelDownloader\": true
      }
    }" > "$CONFIG_FILE"
fi

# Source config
StableDiffusion=$(jq -r '.apps.StableDiffusion' "$CONFIG_FILE")
KoboldAI=$(jq -r '.apps.KoboldAI' "$CONFIG_FILE")
SillyTavern=$(jq -r '.apps.SillyTavern' "$CONFIG_FILE")
Oobabooga=$(jq -r '.apps.Oobabooga' "$CONFIG_FILE")

# Run installers (downloader modules are always run)
bash modules/install_models.sh
bash modules/install_loras.sh

$StableDiffusion && echo "Installing Stable Diffusion..."
$KoboldAI && echo "Installing KoboldAI..."
$SillyTavern && echo "Installing SillyTavern..."
$Oobabooga && echo "Installing Oobabooga..."
