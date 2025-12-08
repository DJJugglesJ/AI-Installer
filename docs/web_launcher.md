# Web Launcher

The web launcher replaces the YAD/menu experience with a browser-based control panel that wraps the same shell helpers and runtime modules. It runs locally on `http://127.0.0.1:3939` by default and exposes JSON endpoints for automation.

## What ships in this release
- Lightweight Python server at `modules/runtime/web_launcher/` that serves the bundled static UI and JSON APIs.
- Static HTML/JS/CSS under `modules/runtime/web_launcher/static/` so no frontend build step is required.
- OS-aware startup scripts:
  - `launcher/start_web_launcher.sh` for Linux, macOS, and WSL.
  - `launcher/start_web_launcher.ps1` and `launcher/start_web_launcher.bat` for Windows shells.
- Backend endpoints wrap the existing shell helpers (`modules/shell/*.sh`) so side effects and logs stay consistent with the legacy menu.

## Endpoints
- `GET /api/status` — returns action list plus manifest/character counts.
- `GET /api/actions` — enumerate available launcher actions.
- `POST /api/actions` — `{ "action": "run_webui" }` shells out to the matching helper and returns PID and log path.
- `GET /api/manifests` — returns models/LoRAs from `manifests/`.
- `GET /api/characters` — reads Character Studio cards via the shared registry.
- `POST /api/prompt/compile` — accepts a `SceneDescription` payload and compiles prompts with Prompt Builder, writing the prompt bundle for launcher reuse.

## Relationship to YAD/menu flows
- The legacy YAD dialogs remain available for compatibility (`aihub_menu.sh`), but new desktop shortcuts should point to the web launcher scripts.
- Launcher buttons in the web UI call the same shell helpers as the menu, preserving logs in `~/.config/aihub/install.log` and related caches.
- Manifest browsing, prompt compilation, and Character Studio registry inspection are now available without requiring a desktop widget toolkit.

## Usage
1. From the repo root run `./launcher/start_web_launcher.sh` (or the matching Windows script).
2. Open the provided URL (default `http://127.0.0.1:3939`) in a browser.
3. Trigger installs/launches, browse manifests, or compile prompts; the latest prompt bundle is written to `~/.cache/aihub/prompt_builder/prompt_bundle.json` for launcher consumption.

To change the bind host/port, export `AIHUB_WEB_HOST` or `AIHUB_WEB_PORT` or pass `--host/--port` to the launcher script.
