#!/bin/bash

OOBA_DIR="$HOME/AI/oobabooga"
KOBOLD_DIR="$HOME/AI/KoboldAI"
OOBA_MODELS="$OOBA_DIR/models"
KOBOLD_MODELS="$KOBOLD_DIR/models"

FOUND_BACKENDS=()
MODEL_LIST=()

if [ -d "$OOBA_DIR" ]; then
  FOUND_BACKENDS+=("oobabooga")
  if [ -d "$OOBA_MODELS" ]; then
    while IFS= read -r model; do
      MODEL_LIST+=("oobabooga:$model")
    done < <(find "$OOBA_MODELS" -type f -exec basename {} \;)
  fi
fi

if [ -d "$KOBOLD_DIR" ]; then
  FOUND_BACKENDS+=("KoboldAI")
  if [ -d "$KOBOLD_MODELS" ]; then
    while IFS= read -r model; do
      MODEL_LIST+=("KoboldAI:$model")
    done < <(find "$KOBOLD_MODELS" -type f -exec basename {} \;)
  fi
fi

if [ ${#FOUND_BACKENDS[@]} -eq 0 ]; then
  yad --error --title="No LLM Backends Found" --text="❌ Neither oobabooga nor KoboldAI found in ~/AI"
  exit 1
fi

MODEL_SUMMARY=$(printf "%s\n" "${MODEL_LIST[@]}" | sed 's/^/  - /')

yad --info --width=600 --title="LLM Backend Detection" --text="✅ Detected Backends:\n\n${FOUND_BACKENDS[*]}\n\n📦 Detected Models:\n$MODEL_SUMMARY"
