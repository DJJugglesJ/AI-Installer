#!/bin/bash

CACHE_FILE="/tmp/aihub_loras.json"
ENTRIES_FILE="/tmp/aihub_loRA_entries.json"
TAG_GROUPS_FILE="/tmp/aihub_tag_groups.json"

API_URL="https://civitai.com/api/v1/models?types=LoRA&limit=100"

function refresh_data() {
  echo "[*] Pulling latest LoRA list from CivitAI..."
  curl -s "$API_URL" -o "$CACHE_FILE"

  if [ ! -f "$CACHE_FILE" ]; then
    yad --error --text="Failed to retrieve data from CivitAI." --title="API Error"
    exit 1
  fi

  echo "[*] Parsing entries..."
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

# Ask if user wants to refresh
yad --question --title="Refresh LoRA Data?" \
  --text="Do you want to fetch the latest LoRA list from CivitAI?" \
  --button="Yes!refresh:0" --button="No:1"
if [ $? -eq 0 ]; then
  refresh_data
fi

# Require valid data
if [ ! -f "$TAG_GROUPS_FILE" ]; then
  yad --error --text="Tag data not found. Please run the fetch phase." --title="Missing Data"
  exit 1
fi

select_tags() {
  local group_name="$1"
  local tag_list=($(jq -r '."'$group_name'"[]' "$TAG_GROUPS_FILE"))

  if [ ${#tag_list[@]} -eq 0 ]; then echo ""; return; fi

  local yad_args=()
  for tag in "${tag_list[@]}"; do
    yad_args+=(FALSE "$tag")
  done

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

# Filter list for preview
jq -r --argjson tags "$(printf '%s\n' "${selected_tags[@]}" | jq -R . | jq -s .)" '
  .[] | select(
    [.trainedWords[] | ascii_downcase] | any(. as $tag | $tags | index($tag))
  ) | [
    .name, .creator, .model, (.rating | tostring), (.votes | tostring),
    (if .nsfw then "🔞" else "" end)
  ] | @tsv
' "$ENTRIES_FILE" > /tmp/aihub_lora_filtered.tsv

yad --list --title="Filtered LoRAs" --width=800 --height=400 \
  --column="Name" --column="Creator" --column="Model" \
  --column="Rating" --column="Votes" --column="NSFW" \
  $(cat /tmp/aihub_lora_filtered.tsv | tr '\n' ' ')
