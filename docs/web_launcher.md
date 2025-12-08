# Web launcher (backend + frontend)

The web launcher exposes the same installer/launcher helpers that power the legacy YAD/menu flows, but wraps them in a lightweight HTTP server and a bundled HTML/JS UI. It is designed for **local-first use** with optional bearer-token protection when you need to bind beyond `127.0.0.1`.

## Hosting model
- **Process:** `python -m modules.runtime.web_launcher serve` runs a threaded HTTP server that serves the static UI and JSON APIs from the repository checkout.
- **Bind/port:** Defaults to `127.0.0.1:3939`. Override with `AIHUB_WEB_HOST`/`AIHUB_WEB_PORT` or `--host/--port` if you want to expose the server to a LAN (e.g., `0.0.0.0`).
- **Authentication:** Optional bearer token. Set `AIHUB_WEB_TOKEN` or `--auth-token <token>` to require every API call to present `Authorization: Bearer <token>` (the UI exposes a token field that stores the value in `localStorage`). Leave unset for single-user localhost use.
- **Static + API:** The handler serves `modules/runtime/web_launcher/static/` alongside `/api/*` endpoints for actions, installer jobs, manifests, prompt compilation, and character registry browsing.

## How it augments or replaces legacy menus
- **Linux/WSL:** `launcher/start_web_launcher.sh` replaces the need for `aihub_menu.sh` + YAD dialogs. Existing desktop shortcuts can target the web launcher script or `http://127.0.0.1:3939` directly after the server is started.
- **Windows:** `launcher/start_web_launcher.bat` and `launcher/start_web_launcher.ps1` mirror the Linux script and forward into the Python entry point (works in WSL-backed setups). The legacy `.bat`/`.ps1` menu wrappers remain available if you prefer dialogs.
- **macOS:** `launcher/start_web_launcher.command` provides a double-clickable launcher while keeping `aihub_menu.sh` available in terminals for parity with Linux.

## Startup scripts and URLs
- `launcher/start_web_launcher.sh` (Linux/WSL/macOS terminal)
- `launcher/start_web_launcher.bat` (Windows batch)
- `launcher/start_web_launcher.ps1` (Windows PowerShell)
- `launcher/start_web_launcher.command` (macOS Finder/Terminal)

Each script accepts `AIHUB_WEB_HOST`, `AIHUB_WEB_PORT`, and optionally `AIHUB_WEB_TOKEN` to pre-configure the binding and authentication. After launching, the UI is available at:

- `http://127.0.0.1:3939` (default localhost)
- `http://<bind-host>:<port>` when using a custom bind (e.g., `0.0.0.0:8080` for LAN access)

When exposing beyond localhost, set a bearer token and ensure your firewall/network allows only intended clients.

## API surface (quick reference)
- `GET /api/status` — counts of actions/manifests/characters.
- `GET /api/actions` — available launcher/install commands.
- `POST /api/actions {"action": "run_webui"}` — trigger a launcher action (logs written under `~/.cache/aihub/web_launcher/logs`).
- `GET /api/manifests` — curated model and LoRA manifests.
- `POST /api/installations {"models": [], "loras": []}` — start curated installers; `GET /api/installations` polls progress and history.
- `POST /api/prompt/compile {"scene": {...}}` — build prompt bundles used by launchers.
- `GET /api/characters` — Character Studio registry entries shared with Prompt Builder.

The UI exercises these endpoints directly; headless environments can call the APIs on their own if preferred.
