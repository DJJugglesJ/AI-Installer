# Model and LoRA Browser Design

## Goals
- Provide a consistent browsing surface (CLI and web UI) for curated model and LoRA manifests.
- Reuse existing installer/runtime abstractions so installs, updates, and logs remain unified.
- Strengthen manifest hygiene with predictable refresh cadence, validation rules, and rich metadata fields.

## Manifest refresh cadence
- **Weekly automated refresh**: a scheduled job regenerates curated manifests from trusted sources, applies validation, and opens a PR with the updated files.
- **Fast-track hotfixes**: security or checksum fixes bypass the schedule with an on-demand refresh that reuses the same validation pipeline.
- **Local sync hooks**: CLI/web UI surfaces expose "Refresh manifests" actions that pull the latest curated set, verify signatures/checksums, and only apply when validations pass.

## Validation and metadata fields
- **Required integrity fields**: `url`, `size`, `sha256`, and optional `mirrors[]` checked before surfacing entries; installer refuses installs on checksum mismatch.
- **Licensing and source provenance**: `license`, `source`, `attribution`, and `gated` flags surfaced in the browser so users can understand requirements before download.
- **Runtime targeting**: `frontend` (e.g., `webui`, `comfyui`, `koboldai`), `file_type`, `precision`, and `default_path` to map entries into the correct installer/runtime destination.
- **User experience metadata**: `title`, `description`, `tags[]`, `thumbnail`, `version`, and optional `recommended_companions[]` (e.g., LoRAs that pair well with a model) for filtering and curated sets.
- **Validation pipeline**: schema validation (JSON schema), checksum verification against staged files, and linting for missing metadata fields before manifests are merged or fetched by clients.

## User-facing browser (CLI + web UI)
- **Shared data model**: runtime exposes a manifest service that loads validated manifests and presents a typed list of entries with their metadata and install commands.
- **CLI experience**: a `python -m modules.runtime.manifests browse` command lists curated models/LoRAs with filters (`--frontend webui`, `--tag photoreal`), shows metadata, and offers one-click installs by invoking the existing installer hooks.
- **Web UI panel**: a new "Models & LoRAs" view reuses the same manifest service APIs, shows thumbnails and badges (license, size, version), and includes a single install button per entry plus a bulk queue mode.
- **Installer/runtime integration**: install actions call the existing download/placement abstractions (the same ones used by YAD/menu flows) so logging, resume logic, and folder mappings stay consistent. The browser only triggers these helpers, never reimplements download logic.
- **Safety rails**: before install, the browser confirms disk space based on `size`, warns on gated/licensed items, and blocks entries that fail checksum validation or schema checks during the latest refresh.

## Deliverables
- Validated manifest schema and pipeline documentation.
- CLI and web UI surfaces backed by the shared manifest service.
- Automation that refreshes manifests on the documented cadence and surfaces refresh status in logs and the browser UI.
