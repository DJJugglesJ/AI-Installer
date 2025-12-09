# Model and LoRA Quickstart

This guide highlights the fastest way to install the default Stable Diffusion 1.5 preset, know where assets are stored, and pair LoRAs with the supported frontends. The refreshed installer now asks before installing packages, provides inline GPU guidance (NVIDIA/AMD/Intel/CPU), and retries or resumes downloads with mirror fallbacks so you can complete installs without babysitting every step.

## Install Stable Diffusion 1.5
- From the repository root, run the installer and jump directly to model setup:
  ```bash
  ./install.sh --install models
  ```
- Headless or scripted setups can pin GPU mode and skip all dialogs:
  ```bash
  ./install.sh --headless --gpu nvidia --install models
  ```
  - Use `--gpu amd`, `--gpu intel`, or `--gpu cpu` to force a mode when detection is undesirable.
- The installer stores checkpoints at `~/ai-hub/models/` and links them into the Stable Diffusion WebUI folder at `~/AI/WebUI/models/Stable-diffusion/` when present.
- YAD installs can browse curated manifests; headless runs fall back to Hugging Face and download `sd-v1-5.ckpt` by default. Provide a token via the prompt or set `HUGGINGFACE_TOKEN` if the file is gated or rate limited.
- The curated manifests now include SDXL base/refiner/turbo options, SD1.5 fallbacks, and community favorites so you can browse a wider set of checkpoints without hunting for links.
- Use the launcher entry **🗂️ Browse Curated Models & LoRAs** (or `bash modules/shell/manifest_browser.sh` or `python -m modules.runtime.web_launcher`) to review manifest metadata and queue installs without leaving the menu.
- If a download fails, the installer automatically retries with resumable transfers across `aria2c`/`wget` and rotates through manifest mirrors before prompting you to retry.

### SD1.5 preset cheat sheet
- Base: `Stable Diffusion 1.5 (EMA-Only)` from the curated manifest (filename: `v1-5-pruned-emaonly.ckpt`).
- Default sampler: `DPM++ 2M Karras` with **20–28 steps** and **CFG 7–8** for balanced sharpness.
- Resolution: start at **768x768** for portraits; bump to **896x1152** for full-body compositions if VRAM allows.
- Negative prompt starters: `nsfw, bad hands, extra limbs, worst quality, lowres` and add `EasyNegative` if you have the embedding.
- Quick styles:
  - **Photographic**: use a photographic LoRA (e.g., Analog Film Photo Enhancer) at weight **0.6–0.8** and add `cinematic lighting, 35mm photograph`.
  - **Illustration**: pick an anime/line-art LoRA at **0.7** and add `sharp ink, cel shading, clean lineart`.

### SDXL counterpart presets
- Base/refiner pair: install `Stable Diffusion XL Base` and `Stable Diffusion XL Refiner` from the manifest; set refiner switch around **0.8** in two-stage pipelines.
- Turbo: use `Stable Diffusion XL Turbo (FP16)` for low-latency tests with **4–6 steps** and CFG **2–3**.
- Sampler defaults: `DPM++ SDE Karras` or `Euler a`; start at **30–35 steps** (base) and **20 steps** (refiner) for quality renders.
- LoRA pairing: SDXL LoRAs in `~/AI/LoRAs/` are picked up by WebUI automatically, just like SD1.5, and can be mixed with the refiner pipeline.
- GPU prompts during install will recommend NVIDIA drivers when applicable and surface ROCm/oneAPI/DirectML notes for AMD/Intel/WSL users so you can pick a safe default before downloading larger assets.

## LoRA installation
- Run the LoRA helper directly or from the launcher menu to pull curated or CivitAI LoRAs into `~/AI/LoRAs/`:
  ```bash
  ./install.sh --install loras
  # or
  bash modules/shell/install_loras.sh
  ```
- The WebUI installer creates a symlink from `~/AI/LoRAs/` to `~/AI/WebUI/models/Lora/`, so any downloaded LoRA is immediately available to Stable Diffusion WebUI.
- If a LoRA download is interrupted mid-file, rerun the task; it resumes automatically and validates checksums before prompting.

## Pairing flows
### Stable Diffusion WebUI
1. Ensure models exist in `~/ai-hub/models/` (see above) and LoRAs in `~/AI/LoRAs/`.
2. Launch WebUI (`aihub_menu.sh` ➜ **Run Stable Diffusion WebUI** or `bash modules/shell/run_webui.sh`).
3. Pick the SD1.5 checkpoint (e.g., `sd-v1-5.ckpt`) from the model dropdown and select a LoRA from the `Lora` selector. The symlinked LoRA folder makes downloads immediately visible.
4. Apply the preset cheatsheet values above: sampler + steps/CFG, resolution, and LoRA weight. Save the combination as a WebUI preset for quick reuse.

#### Fast pairing examples
- **SD1.5 + Analog Film look:** select `v1-5-pruned-emaonly.ckpt`, add `analog-film-photo-enhancer.safetensors` at **0.7**, set **DPM++ 2M Karras**, **24 steps**, **CFG 7**, and prompt `cinematic portrait, soft rim light, kodak gold color grading`.
- **SD1.5 + Detail booster:** pick `v1-5-pruned-emaonly.ckpt`, add `add_detail.safetensors` at **0.6**, set **DPM++ 2M Karras**, **22 steps**, **CFG 8**, and prompt `highly detailed illustration, crisp lines, elaborate background, volumetric lighting`.
- **SDXL + Expressive faces:** choose `sd_xl_base_1.0.safetensors`, enable the refiner at 0.8, add `expressive-faces-sdxl.safetensors` at **0.65**, use **Euler a**, **32 base / 20 refiner steps**, **CFG 6**, and prompt `studio portrait, dramatic expression, key light and fill light`.

### KoboldAI (LLM backends)
1. Place models in `~/AI/KoboldAI/models/` or install them via the KoboldAI UI.
2. If you prefer an oobabooga-style launch script that injects a LoRA, run:
   ```bash
   bash modules/shell/pair_oobabooga.sh
   ```
   - Choose an LLM from `~/AI/oobabooga/models/` and, optionally, a LoRA from `~/AI/oobabooga/lora/`.
   - The script writes `/tmp/oobabooga_launch.sh` and can launch it directly; use this when you want to start a LoRA-enabled backend for KoboldAI-compatible clients.

### SillyTavern
1. To point SillyTavern at a local API backend (oobabooga or KoboldAI), run:
   ```bash
   bash modules/shell/pair_sillytavern.sh
   ```
   - Select the backend (`oobabooga` or `KoboldAI`) and choose a model from that runtime's `models` folder.
   - Choose **Inject to SillyTavern** or **Both** to set `apiUrl` in `~/AI/SillyTavern/config.json` (defaults: oobabooga on port 5000, KoboldAI on port 5001).
2. When using oobabooga as the backend and you need a LoRA, run `bash modules/shell/pair_oobabooga.sh` first to generate the launch script with the desired LoRA, then start SillyTavern after the backend is running.

## Defaults at a glance
- Models: `~/ai-hub/models/` (symlinked into WebUI when available)
- WebUI install: `~/AI/WebUI/`
- LoRAs: `~/AI/LoRAs/` (WebUI symlink target)
- oobabooga: `~/AI/oobabooga/` (LLM models in `models/`, LoRAs in `lora/`)
- KoboldAI: `~/AI/KoboldAI/` (models in `models/`)
- SillyTavern: `~/AI/SillyTavern/` (config at `config.json`)

## Troubleshooting downloads
- Logs: all download attempts write to `~/.config/aihub/install.log`, including the downloader chosen, retry counts, and whether a mirror URL was used.
- Resume: failed transfers automatically resume with exponential backoff across both `aria2c` and `wget`. If a transfer is interrupted mid-file, re-running the installer continues from the partial download.
- Mirrors: curated manifests optionally list `.mirrors` entries. When the primary URL fails, mirrors are tried in order with the same checksum verification. If every source fails, the dialog surfaces the error and the log lists each attempted URL.
- If you see repeated checksum mismatches, remove the partially downloaded file in `~/ai-hub/models/` or `~/AI/LoRAs/` and retry to avoid reusing corrupted data.
