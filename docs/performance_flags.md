# Performance flags

These toggles apply primarily to Stable Diffusion WebUI launches. They can be set via the headless config (`~/.config/aihub/installer.conf`), CLI configs, or through the **Performance Flags** menu entry.

## Defaults by GPU family
- **NVIDIA:**
  - FP16: **Enabled** by default and falls back to full precision if the driver lacks FP16 stability.
  - xFormers: **Enabled** by default when `nvidia-smi` is present; disabled automatically when drivers are missing or when DirectML is selected.
  - Low VRAM: Automatically recommended when <8GB VRAM is detected via `nvidia-smi`.
- **AMD (Linux):**
  - FP16: Disabled by default to avoid precision instability. Enable only when you know ROCm/AMDGPU drivers are tuned for it.
  - xFormers: Not offered.
  - DirectML: Only exposed under Windows/WSL; otherwise disabled.
  - Low VRAM: Optional toggle.
- **Intel:**
  - Defaults to CPU fallback for WebUI; FP16/xFormers are disabled.
  - DirectML is available under Windows/WSL only and disables xFormers automatically.
  - Low VRAM: Optional toggle, useful for integrated GPUs.
- **CPU-only:**
  - Runs with full precision and ignores GPU-accelerator toggles. Low VRAM remains available.

## Flag meanings
- **FP16:** Requests half-precision math when supported; otherwise forces full precision (`--precision full --no-half`).
- **xFormers:** Adds `--xformers` for NVIDIA GPUs with working drivers.
- **DirectML:** Adds `--use-directml` for AMD/Intel GPUs under Windows/WSL and turns off xFormers to avoid conflicts.
- **Low VRAM:** Adds `--medvram` to reduce memory usage at the cost of speed and potentially higher CPU usage.
