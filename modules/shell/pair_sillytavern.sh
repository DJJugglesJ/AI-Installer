#!/bin/bash

OOBA_DIR="$HOME/AI/oobabooga"
KOBOLD_DIR="$HOME/AI/KoboldAI"
SILLY_DIR="$HOME/AI/SillyTavern"
OOBA_MODELS="$OOBA_DIR/models"
KOBOLD_MODELS="$KOBOLD_DIR/models"
PAIR_FILE="/tmp/st_llm_pair.txt"
CONFIG_FILE="$SILLY_DIR/config.json"
PROMPT_BUNDLE_PATH="${PROMPT_BUNDLE_PATH:-$HOME/.cache/aihub/prompt_builder/prompt_bundle.json}"

load_prompt_bundle() {
  local path="$PROMPT_BUNDLE_PATH"
  if [ ! -f "$path" ]; then
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "Prompt bundle found at $path but jq is missing; skipping injection." >&2
    return 1
  fi

  POSITIVE_PROMPT=$(jq -r 'if .positive_prompt_text? then .positive_prompt_text else (.positive_prompt // []) | join(" | ") end' "$path")
  NEGATIVE_PROMPT=$(jq -r 'if .negative_prompt_text? then .negative_prompt_text else (.negative_prompt // []) | join(" | ") end' "$path")
  LORA_FLAGS=$(jq -r '(.lora_calls // []) | map(.name + (if (.weight // null) != null then ":" + (.weight|tostring) else "" end) + (if (.trigger // null) != null then ":" + .trigger else "" end)) | join(",")' "$path")

  export PROMPT_BUILDER_POSITIVE="$POSITIVE_PROMPT"
  export PROMPT_BUILDER_NEGATIVE="$NEGATIVE_PROMPT"
  export PROMPT_BUILDER_LORAS="$LORA_FLAGS"
  export PROMPT_BUILDER_BUNDLE_PATH="$path"
}

[ -d "$OOBA_MODELS" ] || mkdir -p "$OOBA_MODELS"
[ -d "$KOBOLD_MODELS" ] || mkdir -p "$KOBOLD_MODELS"

load_prompt_bundle

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
ACTIONS=$(yad --list --title="Select Action" --width=400 --height=200 --column="Action" --column="Description"   "Launch Script" "Generate a launch script for the paired backend"   "Inject to SillyTavern" "Write API config to SillyTavern config.json"   "Both" "Do both actions")

if [ -z "$ACTIONS" ]; then
  yad --info --title="Cancelled" --text="No action selected."
  exit 0
fi

IFS='|' read -r ACTION _ <<< "$ACTIONS"

launch_in_terminal() {
  local command_file="$1"
  local launch_sequence="\"$command_file\"; exec bash"
  if command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal -- bash -lc "$launch_sequence"
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e bash -lc "$launch_sequence"
  else
    bash "$command_file"
  fi
}
case "$ACTION" in
   "Launch Script"|"Both")
    OUTFILE="/tmp/st_llm_launch.sh"
    {
      echo "#!/bin/bash"
      if [[ -n "${PROMPT_BUILDER_POSITIVE:-}" ]]; then
        echo "export PROMPT_BUILDER_POSITIVE=\"$PROMPT_BUILDER_POSITIVE\""
        echo "export PROMPT_BUILDER_NEGATIVE=\"$PROMPT_BUILDER_NEGATIVE\""
        echo "export PROMPT_BUILDER_LORAS=\"$PROMPT_BUILDER_LORAS\""
        echo "export PROMPT_BUILDER_BUNDLE_PATH=\"$PROMPT_BUNDLE_PATH\""
      fi
      if [[ "$SELECTED_BACKEND" == "oobabooga" ]]; then
        echo "cd \"$OOBA_DIR\""
        echo "python server.py --model-dir models --model \"$SELECTED_MODEL\""
      else
        echo "cd \"$KOBOLD_DIR\""
        echo "python KoboldAI.py --model \"$SELECTED_MODEL\""
      fi
    } > "$OUTFILE"
    chmod +x "$OUTFILE"
    launch_in_terminal "$OUTFILE"
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
