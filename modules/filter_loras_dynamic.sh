#!/bin/bash

LORA_JSON="/tmp/civitai_loras.json"
SELECTED_TAGS_FILE="/tmp/lora_selected_tags.txt"

if [ ! -f "$LORA_JSON" ] || [ ! -f "$SELECTED_TAGS_FILE" ]; then
  yad --error --title="Missing Files" --text="Missing required LoRA data or tag selection file."
  exit 1
fi

mapfile -t SELECTED_TAGS < "$SELECTED_TAGS_FILE"

FILTERED=()
for row in $(jq -c '.items[]' "$LORA_JSON"); do
  name=$(echo "$row" | jq -r .name)
  tags=$(echo "$row" | jq -r '.tags | join(",")')

  MATCHED=true
  for tag in "${SELECTED_TAGS[@]}"; do
    if [[ ! "$tags" =~ $tag ]]; then
      MATCHED=false
      break
    fi
  done

  if $MATCHED; then
    FILTERED+=("$name\n$tags")
  fi
done

if [ ${#FILTERED[@]} -eq 0 ]; then
  yad --info --title="No Matches" --text="No LoRAs matched the selected tags."
else
  yad --list --width=500 --height=400 --title="Matching LoRAs" \
    --column="Name" --column="Tags" "${FILTERED[@]}"
fi
