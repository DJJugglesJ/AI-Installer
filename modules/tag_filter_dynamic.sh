#!/bin/bash

TMP_JSON="/tmp/civitai_loras.json"
TMP_GROUPED="/tmp/grouped_civitai_tags.json"
TMP_SELECTION="/tmp/lora_selected_tags.txt"
TMP_SOURCE_INFO="/tmp/civitai_lora_source.txt"

CACHE_DIR="/tmp/aihub_civitai_cache"
CACHE_TTL_SECONDS="${CIVITAI_CACHE_TTL:-3600}"
MAX_PAGES="${CIVITAI_LORA_PAGES:-5}"
ITEM_LIMIT=100

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

# 1. Fetch latest LoRAs (with caching and pagination)
mkdir -p "$CACHE_DIR"
SOURCE_NOTE="Source: CivitAI LoRAs"

use_cache=false
latest_cache=$(find "$CACHE_DIR" -maxdepth 1 -name 'civitai_loras_*.json' -type f 2>/dev/null | sort | tail -n 1)
if [ -n "$latest_cache" ]; then
  now=$(date +%s)
  mtime=$(stat -c %Y "$latest_cache")
  age=$((now - mtime))
  if [ "$age" -lt "$CACHE_TTL_SECONDS" ]; then
    cp "$latest_cache" "$TMP_JSON"
    use_cache=true
    info_file="${latest_cache%.json}.info"
    if [ -f "$info_file" ]; then
      SOURCE_NOTE=$(cat "$info_file")
    fi
  fi
fi

if ! $use_cache; then
  tmp_files=()
  page=1
  while [ "$page" -le "$MAX_PAGES" ]; do
    page_file=$(mktemp)
    if ! curl -fsS "https://civitai.com/api/v1/models?types=LoRA&limit=$ITEM_LIMIT&nsfw=true&page=$page" -o "$page_file"; then
      notify error "Network Error" "Failed to contact Civitai for the latest LoRA list (page $page)."
      rm -f "$page_file"
      exit 1
    fi
    if [ ! -s "$page_file" ]; then
      notify error "Empty Response" "Civitai returned no data on page $page."
      rm -f "$page_file"
      exit 1
    fi
    tmp_files+=("$page_file")
    next_page=$(jq -r '.metadata.nextPage // empty' "$page_file" 2>/dev/null)
    if [ -z "$next_page" ] || [ "$next_page" = "null" ]; then
      break
    fi
    page=$next_page
  done

  if [ ${#tmp_files[@]} -eq 0 ]; then
    notify error "Empty Response" "Civitai returned no data."
    exit 1
  fi

  if ! jq -s '{items: (map(.items // []) | add)}' "${tmp_files[@]}" > "$TMP_JSON" 2>/dev/null; then
    notify error "Parse Error" "Unable to parse LoRA metadata returned from Civitai."
    rm -f "${tmp_files[@]}"
    exit 1
  fi

  PAGES_FETCHED=${#tmp_files[@]}
  timestamp=$(date +%Y%m%d%H%M%S)
  cache_file="$CACHE_DIR/civitai_loras_${timestamp}.json"
  cp "$TMP_JSON" "$cache_file"
  SOURCE_NOTE="Source: CivitAI LoRAs pages 1-$PAGES_FETCHED (limit=$ITEM_LIMIT, fetched $(date -u))"
  echo "$SOURCE_NOTE" > "${cache_file%.json}.info"
  printf "%s" "$SOURCE_NOTE" > "$TMP_SOURCE_INFO"

  for f in "${tmp_files[@]}"; do rm -f "$f"; done
else
  : > "$TMP_SOURCE_INFO"
  printf "%s" "$SOURCE_NOTE" > "$TMP_SOURCE_INFO"
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
    --text="Choose tags from: $category\n$SOURCE_NOTE" \
    --multiple --column="Select" --column="Tag" "${TAG_OPTIONS[@]}")

  if [ -n "$selected" ]; then
    IFS="|" read -ra chosen <<< "$selected"
    for tag in "${chosen[@]}"; do
      echo "$tag" >> "$TMP_SELECTION"
    done
  fi
done

notify info "Tag Filter Ready" "${SOURCE_NOTE}\n\nSelected tags:\n\n$(cat "$TMP_SELECTION")"
