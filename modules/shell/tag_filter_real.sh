#!/bin/bash

GROUPED_TAGS_JSON="$HOME/AI-Installer/grouped_civitai_tags.json"
TMP_SELECTION="/tmp/lora_selected_tags.txt"
mkdir -p "$(dirname "$GROUPED_TAGS_JSON")"

if [ ! -f "$GROUPED_TAGS_JSON" ]; then
  yad --error --title="Missing Tags" --text="Grouped CivitAI tag file not found.\nExpected: $GROUPED_TAGS_JSON"
  exit 1
fi

# Load tag groups using jq
for category in $(jq -r 'keys[]' "$GROUPED_TAGS_JSON"); do
  mapfile -t tags < <(jq -r ".\"$category\"[]" "$GROUPED_TAGS_JSON")

  if [ ${#tags[@]} -eq 0 ]; then
    continue
  fi

  TAG_OPTIONS=()
  for tag in "${tags[@]}"; do
    TAG_OPTIONS+=(FALSE "$tag")
  done

  selected=$(yad --list --width=400 --height=300 --center --separator="|" \
    --title="Select Tags - $category" \
    --text="Choose tags from: $category" \
    --multiple --column="Select" --column="Tag" "${TAG_OPTIONS[@]}")

  if [ -n "$selected" ]; then
    IFS="|" read -ra chosen <<< "$selected"
    for tag in "${chosen[@]}"; do
      echo "$tag" >> "$TMP_SELECTION"
    done
  fi
done

yad --info --title="Tag Filter Ready" --text="Selected tags:\n\n$(cat "$TMP_SELECTION")"
