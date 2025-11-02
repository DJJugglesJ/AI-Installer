#!/bin/bash

TMP_JSON="/tmp/civitai_loras.json"
TMP_GROUPED="/tmp/grouped_civitai_tags.json"
TMP_SELECTION="/tmp/lora_selected_tags.txt"

notify()
{
  local type="$1"
  local title="$2"
  local message="$3"
  if command -v yad >/dev/null 2>&1; then
    case "$type" in
      error) yad --error --title="$title" --text="$message" ;;
      info) yad --info --title="$title" --text="$message" ;;
    esac
  else
    case "$type" in
      error) echo "ERROR: $title - $message" >&2 ;;
      info) echo "$title: $message" ;;
    esac
  fi
}

# 1. Fetch latest LoRAs
if ! curl -fsS "https://civitai.com/api/v1/models?types=LoRA&limit=100&nsfw=true" -o "$TMP_JSON"; then
  notify error "Network Error" "Failed to contact Civitai for the latest LoRA list."
  exit 1
fi

if [ ! -s "$TMP_JSON" ]; then
  notify error "Empty Response" "Civitai returned no data."
  exit 1
fi

# 2. Parse top 100 tags
if ! TOP_TAGS=$(jq -r '[.items[]?.tags[]] | group_by(.) | map({tag: .[0], count: length}) | sort_by(-.count) | .[:100] | map(.tag)' "$TMP_JSON" 2>/dev/null); then
  notify error "Parse Error" "Unable to parse LoRA metadata returned from Civitai."
  exit 1
fi

# 3. Group tags
if ! echo "$TOP_TAGS" | jq 'reduce .[] as $tag (
  {"model":[],"style":[],"character":[],"theme":[],"nsfw":[],"misc":[]};
  if ($tag | test("sdxl|sd1|model|checkpoint"; "i")) then .model += [$tag]
  elif ($tag | test("realism|art|painting|sketch|style|lineart|watercolor"; "i")) then .style += [$tag]
  elif ($tag | test("character|girl|boy|man|woman|oc|original"; "i")) then .character += [$tag]
  elif ($tag | test("cyber|fantasy|sci|demon|angel|war|armor|future|retro"; "i")) then .theme += [$tag]
  elif ($tag | test("nsfw|nude|sex|lewd|explicit"; "i")) then .nsfw += [$tag]
  else .misc += [$tag] end
)' > "$TMP_GROUPED"; then
  notify error "Parse Error" "Unable to group tags from the Civitai response."
  exit 1
fi

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

notify info "Tag Filter Ready" "Selected tags:\n\n$(cat "$TMP_SELECTION")"
