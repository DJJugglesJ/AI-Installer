#!/bin/bash

# install_loras.sh — Phase 1: Live CivitAI Pull + Tag Grouping
# Requirements: curl, jq

CACHE_FILE="/tmp/aihub_loras.json"
TAG_GROUPS_FILE="/tmp/aihub_tag_groups.json"
API_URL="https://civitai.com/api/v1/models?types=LoRA&limit=100"

echo "[*] Pulling latest LoRA list from CivitAI..."
curl -s "$API_URL" -o "$CACHE_FILE"

if [ ! -f "$CACHE_FILE" ]; then
  echo "[!] Failed to retrieve data from CivitAI."
  exit 1
fi

echo "[*] Extracting and grouping tags..."

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
' "$CACHE_FILE" > /tmp/aihub_loRA_entries.json

# Parse all tags and group
jq '[.trainedWords[]]' /tmp/aihub_loRA_entries.json |
  jq 'flatten | unique | map(ascii_downcase)' > /tmp/aihub_tags_all.json

# Group into categories
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

echo "[✔] Tags grouped and saved to $TAG_GROUPS_FILE"
