#!/bin/bash

CACHE_FILE="/tmp/aihub_loras.json"
ENTRIES_FILE="/tmp/aihub_loRA_entries.json"
TAG_GROUPS_FILE="/tmp/aihub_tag_groups.json"

if [ ! -f "$TAG_GROUPS_FILE" ]; then
  echo "[!] Tag data not found. Please run the API fetch phase first."
  exit 1
fi

echo "[*] Loading tag groups..."

# Function to display a tag group and capture selected tags
select_tags() {
  local group_name="$1"
  local tag_list=($(jq -r '."'$group_name'"[]' "$TAG_GROUPS_FILE"))

  if [ ${#tag_list[@]} -eq 0 ]; then
    echo ""  # No tags
    return
  fi

  local yad_args=()
  for tag in "${tag_list[@]}"; do
    yad_args+=(FALSE "$tag")
  done

  selected=$(yad --list --checklist --title="Select $group_name Tags" \
    --column="Select" --column="Tag" \
    "${yad_args[@]}" --width=400 --height=300)

  echo "$selected"
}

echo "[*] Select filters..."

model_tags=$(select_tags "Model Type")
style_tags=$(select_tags "Style")
content_tags=$(select_tags "Content")

selected_tags=()
for t in $model_tags $style_tags $content_tags; do
  cleaned=$(echo "$t" | sed 's/|//g')
  selected_tags+=("$cleaned")
done

if [ ${#selected_tags[@]} -eq 0 ]; then
  echo "[!] No tags selected. Exiting."
  exit 1
fi

echo "[*] Filtering LoRA entries..."

jq -r --argjson tags "$(printf '%s\n' "${selected_tags[@]}" | jq -R . | jq -s .)" '
  .[] | select(
    [.trainedWords[] | ascii_downcase] | any(. as $tag | $tags | index($tag))
  ) | [.name, .creator, .model, .rating, .votes, .nsfw] | @tsv
' "$ENTRIES_FILE" > /tmp/aihub_lora_filtered.tsv

echo "[✔] Filtered list saved to /tmp/aihub_lora_filtered.tsv"
