# Manifest Browser

The manifest browser provides a single place to review curated models and LoRAs from `manifests/models.json` and `manifests/loras.json` without opening external sites. It presents the same metadata used by the installers (name, version, size, license, tags, and notes) and routes installs through the existing shell/runtime hooks so logging, checksum verification, and download retries stay consistent.

## How it works
- The browser reads both manifest files and renders a combined YAD checklist so users can filter and multi-select curated entries.
- Selections are passed to the existing installers via `CURATED_MODEL_NAMES`/`CURATED_LORA_NAMES`, which install the exact manifest entries (including mirrors and checksums) without adding new download logic.
- Logging continues to use `~/.config/aihub/install.log`, matching other menu-driven flows.

## Usage
- Open the browser from the main menu: **🗂️ Browse Curated Models & LoRAs**.
- Or run directly: `bash modules/shell/manifest_browser.sh`.
- Pick one or more models/LoRAs and confirm; installs run immediately using the existing helpers.

## Future web UI hook
The browser is designed to power a future web UI panel: the selection payloads (`CURATED_MODEL_NAMES`/`CURATED_LORA_NAMES`) can be set by the web front end after rendering manifest metadata, allowing the same installers to run headlessly while reusing validation and logging.
