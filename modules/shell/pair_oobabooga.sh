#!/bin/bash

OOBA_DIR="$HOME/AI/oobabooga"
# Default workspace paths keep pairings predictable across menu and web launcher flows.
MODELS_DIR="$OOBA_DIR/models"
LORAS_DIR="$OOBA_DIR/lora"

# Ensure expected folders exist before populating the dropdowns.
[ ! -d "$MODELS_DIR" ] && mkdir -p "$MODELS_DIR"
[ ! -d "$LORAS_DIR" ] && mkdir -p "$LORAS_DIR"

# Keep the picker tight: LLMs live in models/, LoRAs live in lora/.
MODEL_CHOICES=$(find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.pth" -o -name "*.safetensors" \) -exec basename {} \;)
LORA_CHOICES=$(find "$LORAS_DIR" -type f \( -name "*.safetensors" -o -name "*.pt" \) -exec basename {} \;)

SELECTED=$(yad --form --title="oobabooga Model + LoRA Pairing" --width=620 --height=260 --center \
  --text="Pick a model from models/ and optionally layer a LoRA from lora/." \
  --field="Model (models/):CB" "$(echo "$MODEL_CHOICES" | tr '\n' '!')" \
  --field="LoRA (lora/, optional):CB" "$(echo -e "None\n$LORA_CHOICES" | tr '\n' '!')")

MODEL=$(echo "$SELECTED" | cut -d '|' -f1)
LORA=$(echo "$SELECTED" | cut -d '|' -f2)

CMD="python server.py --model-dir models --model \"$MODEL\""
if [[ "$LORA" != "None" ]]; then
  CMD="$CMD --load-lora \"lora/$LORA\""
fi

cat <<EOF > /tmp/oobabooga_launch.sh
#!/bin/bash
cd "$OOBA_DIR"
$CMD
EOF

chmod +x /tmp/oobabooga_launch.sh

yad --center --width=420 --height=200 --title="Launch oobabooga" \
  --text="✅ Ready to launch from $OOBA_DIR\n\nModel: $MODEL\nLoRA: $LORA\n\nClick Launch to start." \
  --button="Launch Now!":0 --button="Cancel":1

if [[ $? -eq 0 ]]; then
  gnome-terminal -- bash -c "/tmp/oobabooga_launch.sh; exec bash"
fi
