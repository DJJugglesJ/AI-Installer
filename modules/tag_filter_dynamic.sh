#!/bin/bash

TMP_JSON="/tmp/civitai_loras.json"
TMP_TAGS="/tmp/real_civitai_top_tags.json"
TMP_GROUPED="/tmp/grouped_civitai_tags.json"
TMP_SELECTION="/tmp/lora_selected_tags.txt"

# 1. Fetch latest LoRAs
curl -s "https://civitai.com/api/v1/models?types=LoRA&limit=100&nsfw=true" -o "$TMP_JSON"

# 2. Parse top 100 tags
TOP_TAGS=$(jq -r '[.items[]?.tags[]] | group_by(.) | map({tag: .[0], count: length}) | sort_by(-.count) | .[:100] | map(.tag)' "$TMP_JSON")

# 3. Group tags
echo "$TOP_TAGS" | jq 'reduce .[] as $tag (
  {"model":[],"style":[],"character":[],"theme":[],"nsfw":[],"misc":[]};
  if ($tag | test("sdxl|sd1|model|checkpoint"; "i")) then .model += [$tag]
  elif ($tag | test("realism|art|painting|sketch|style|lineart|watercolor"; "i")) then .style += [$tag]
  elif ($tag | test("character|girl|boy|man|woman|oc|original"; "i")) then .character += [$tag]
  elif ($tag | test("cyber|fantasy|sci|demon|angel|war|armor|future|retro"; "i")) then .theme += [$tag]
  elif ($tag | test("nsfw|nude|sex|lewd|explicit"; "i")) then .nsfw += [$tag]
  else .misc += [$tag] end
)' > "$TMP_GROUPED"

# 4. Launch YAD tag selection
> "$TMP_SELECTION"
for category in $(jq -r 'keys[]' "$TMP_GROUPED"); do
  mapfile -t tags < <(jq -r ".\"$category\"[]" "$TMP_GROUPED")
  if [ ${#tags[@]} -eq 0 ]; then continue; fi

  TAG_OPTIONS=()
  for tag in "${tags[@]}"; do TAG_OPTIONS+=(FALSE "$tag"); done

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
