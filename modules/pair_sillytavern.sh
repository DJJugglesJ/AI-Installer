#!/bin/bash

OOBA_DIR="$HOME/AI/oobabooga"
KOBOLD_DIR="$HOME/AI/KoboldAI"
SILLY_DIR="$HOME/AI/SillyTavern"
OOBA_MODELS="$OOBA_DIR/models"
KOBOLD_MODELS="$KOBOLD_DIR/models"
PAIR_FILE="/tmp/st_llm_pair.txt"
CONFIG_FILE="$SILLY_DIR/config.json"

[ -d "$OOBA_MODELS" ] || mkdir -p "$OOBA_MODELS"
[ -d "$KOBOLD_MODELS" ] || mkdir -p "$KOBOLD_MODELS"

BACKENDS=()
MODEL_LIST=()

if [ -d "$OOBA_DIR" ]; then
  BACKENDS+=("oobabooga")
  while IFS= read -r model; do
    MODEL_LIST+=("oobabooga:$model")
  done < <(find "$OOBA_MODELS" -type f -exec basename {} \;)
fi

if [ -d "$KOBOLD_DIR" ]; then
  BACKENDS+=("KoboldAI")
  while IFS= read -r model; do
    MODEL_LIST+=("KoboldAI:$model")
  done < <(find "$KOBOLD_MODELS" -type f -exec basename {} \;)
fi

if [ ${#BACKENDS[@]} -eq 0 ]; then
  yad --error --title="No Backends Found" --text="❌ No oobabooga or KoboldAI installation found."
  exit 1
fi

if [ ${#BACKENDS[@]} -eq 1 ]; then
  SELECTED_BACKEND="${BACKENDS[0]}"
else
  SELECTED_BACKEND=$(yad --form --title="Choose Default Backend" --field="Use this backend:CB" "$(IFS=!; echo "${BACKENDS[*]}")" | cut -d '|' -f1)
fi

FILTERED_MODELS=()
for item in "${MODEL_LIST[@]}"; do
  if [[ "$item" == "$SELECTED_BACKEND:"* ]]; then
    FILTERED_MODELS+=("${item#*:}")
  fi
done

MODEL_CHOICE=$(yad --form --title="Select LLM Model" --field="Model:CB" "$(IFS=!; echo "${FILTERED_MODELS[*]}")")
SELECTED_MODEL=$(echo "$MODEL_CHOICE" | cut -d '|' -f1)

echo "$SELECTED_BACKEND:$SELECTED_MODEL" > "$PAIR_FILE"

# Offer actions: launch, inject, or both
ACTION=$(yad --list --title="Select Action" --width=400 --height=200 --column="Action" --column="Description"   "Launch Script" "Generate a launch script for the paired backend"   "Inject to SillyTavern" "Write API config to SillyTavern config.json"   "Both" "Do both actions")

case "$ACTION" in
  *Launch*)
    OUTFILE="/tmp/st_llm_launch.sh"
    echo "#!/bin/bash" > "$OUTFILE"
    if [[ "$SELECTED_BACKEND" == "oobabooga" ]]; then
      echo "cd "$OOBA_DIR"" >> "$OUTFILE"
      echo "python server.py --model-dir models --model "$SELECTED_MODEL"" >> "$OUTFILE"
    else
      echo "cd "$KOBOLD_DIR"" >> "$OUTFILE"
      echo "python KoboldAI.py --model "$SELECTED_MODEL"" >> "$OUTFILE"
    fi
    chmod +x "$OUTFILE"
    gnome-terminal -- bash -c "$OUTFILE; exec bash"
    ;;
esac

if [[ "$ACTION" == "Inject to SillyTavern" || "$ACTION" == "Both" ]]; then
  if [ ! -f "$CONFIG_FILE" ]; then
    cp "$SILLY_DIR/config.example.json" "$CONFIG_FILE"
  fi

  # Choose port defaults
  PORT="5000"
  if [[ "$SELECTED_BACKEND" == "KoboldAI" ]]; then PORT="5001"; fi

  jq --arg backend "$SELECTED_BACKEND" --arg port "$PORT"     '.apiUrl = "http://localhost:\($port)"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

yad --info --title="Pairing Complete" --text="✅ Paired $SELECTED_MODEL via $SELECTED_BACKEND for SillyTavern."
