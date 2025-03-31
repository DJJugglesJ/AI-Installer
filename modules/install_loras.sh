#!/bin/bash

CACHE_FILE="/tmp/aihub_loras.json"
ENTRIES_FILE="/tmp/aihub_loRA_entries.json"
TAG_GROUPS_FILE="/tmp/aihub_tag_groups.json"
SELECTION_FILE="/tmp/aihub_lora_selected.tsv"
DOWNLOAD_DIR="/opt/AI/models/Lora"

API_URL="https://civitai.com/api/v1/models?types=LoRA&limit=100"

function refresh_data() {
  curl -s "$API_URL" -o "$CACHE_FILE"
  if [ ! -f "$CACHE_FILE" ]; then
    yad --error --text="Failed to retrieve data from CivitAI." --title="API Error"
    exit 1
  fi

  jq -r '
    .items[] | {
      name: .name,
      description: .description,
      nsfw: .nsfw,
      creator: .creator.username,
      version: .modelVersions[0].name,
      trainedWords: .modelVersions[0].trainedWords,
      model: (
        .modelVersions[0].trainedWords[] |
        select(test("sdxl|1\\.5|2|anything|dream|realistic"; "i"))
      ) // "unknown",
      rating: .modelVersions[0].stats.rating,
      votes: .modelVersions[0].stats.ratingCount,
      preview: .modelVersions[0].images[0].url,
      file: .modelVersions[0].files[0].downloadUrl
    }
  ' "$CACHE_FILE" > "$ENTRIES_FILE"

  jq '[.trainedWords[]]' "$ENTRIES_FILE" |
    jq 'flatten | unique | map(ascii_downcase)' > /tmp/aihub_tags_all.json

  jq '
    reduce .[] as $tag (
      {"Model Type":[],"Style":[],"Content":[],"Misc":[]};
      if $tag | test("sdxl|1\\.5|dream|realistic|anything"; "i")
      then .["Model Type"] += [$tag]
      elif $tag | test("anime|gritty|toon|cyberpunk|realism|painterly"; "i")
      then .["Style"] += [$tag]
      elif $tag | test("nsfw|gore|sfw|violence|wholesome|dark"; "i")
      then .["Content"] += [$tag]
      else .["Misc"] += [$tag]
      end
    )
  ' /tmp/aihub_tags_all.json > "$TAG_GROUPS_FILE"
}

yad --question --title="Refresh LoRA Data?" \
  --text="Do you want to fetch the latest LoRA list from CivitAI?" \
  --button="Yes!refresh:0" --button="No:1"
if [ $? -eq 0 ]; then
  refresh_data
fi

if [ ! -f "$TAG_GROUPS_FILE" ]; then
  yad --error --text="Tag data not found. Please run the fetch phase." --title="Missing Data"
  exit 1
fi

select_tags() {
  local group_name="$1"
  local tag_list=($(jq -r '."'$group_name'"[]' "$TAG_GROUPS_FILE"))
  if [ ${#tag_list[@]} -eq 0 ]; then echo ""; return; fi
  local yad_args=()
  for tag in "${tag_list[@]}"; do yad_args+=(FALSE "$tag"); done

  selected=$(yad --list --checklist --title="Select $group_name Tags" \
    --column="Select" --column="Tag" \
    "${yad_args[@]}" --width=400 --height=300)
  echo "$selected"
}

model_tags=$(select_tags "Model Type")
style_tags=$(select_tags "Style")
content_tags=$(select_tags "Content")

selected_tags=()
for t in $model_tags $style_tags $content_tags; do
  cleaned=$(echo "$t" | sed 's/|//g')
  selected_tags+=("$cleaned")
done

if [ ${#selected_tags[@]} -eq 0 ]; then
  yad --warning --text="No tags selected. Exiting." --title="Nothing Selected"
  exit 1
fi

jq -r --argjson tags "$(printf '%s\n' "${selected_tags[@]}" | jq -R . | jq -s .)" '
  .[] | select(
    [.trainedWords[] | ascii_downcase] | any(. as $tag | $tags | index($tag))
  ) | [
    .name, .creator, .model, (.rating | tostring), (.votes | tostring),
    (if .nsfw then "🔞" else "" end), .file,
    (if .trainedWords != null then .trainedWords[0] else "misc" end)
  ] | @tsv
' "$ENTRIES_FILE" > "$SELECTION_FILE"

entries=()
while IFS=$'\t' read -r name creator model rating votes nsfw file tag; do
  entries+=(FALSE "$name" "$creator" "$model" "$rating" "$votes" "$nsfw" "$tag" "$file")
done < "$SELECTION_FILE"

selection=$(yad --list --checklist --title="Select LoRAs to Install" \
  --width=900 --height=500 \
  --column="Select" --column="Name" --column="Creator" \
  --column="Model" --column="Rating" --column="Votes" \
  --column="NSFW" --column="StyleTag" --column="Download URL" \
  "${entries[@]}")

if [ -z "$selection" ]; then
  yad --info --text="No LoRAs selected. Exiting."
  exit 0
fi

echo "$selection" | tr "|" "\n" | while read -r selected; do
  file=$(grep -F "$selected" "$SELECTION_FILE" | cut -f8)
  tag=$(grep -F "$selected" "$SELECTION_FILE" | cut -f7)
  model=$(grep -F "$selected" "$SELECTION_FILE" | cut -f3)

  install_path="${DOWNLOAD_DIR}/${model}/${tag}"
  sudo mkdir -p "$install_path"
  echo "[*] Downloading $selected to $install_path"
  wget -q --show-progress -O "$install_path/$selected.safetensors" "$file"
done

yad --info --text="✅ Selected LoRAs installed successfully!" --title="Done"
