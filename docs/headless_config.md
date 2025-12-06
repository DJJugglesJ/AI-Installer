# Headless installer configuration

Headless runs can load a configuration file when you pass `--headless` (optionally with `--config <file>`). The installer supports simple `KEY=value` files **or** JSON objects and logs every decision—including defaults when entries are missing—to `~/.config/aihub/install.log`. All files are validated against the installer schema at `modules/config_service/installer_schema.yaml` to keep CI runs predictable.

## Supported keys

| Key               | Purpose                                                                   | Notes |
| ----------------- | ------------------------------------------------------------------------- | ----- |
| `gpu_mode`        | Force GPU mode selection (`nvidia`, `amd`, `intel`, or `cpu`).            | CLI `--gpu` takes precedence. Defaults to hardware detection/CPU fallback when absent. |
| `install_target`  | Automatically run a specific installer (`webui`, `kobold`, `sillytavern`, `loras`, or `models`). | CLI `--install` takes precedence. Leaving this blank creates the launcher without auto-installing. |
| `huggingface_token` | Token used by model installers for authenticated Hugging Face downloads. | `HUGGINGFACE_TOKEN` environment variables take precedence. Anonymous downloads are used when the token is missing. |
| `enable_fp16` | Prefer half-precision math when supported. | Defaults to `true` on NVIDIA; forced to `false` when the detected GPU/driver does not advertise FP16 support. |
| `enable_xformers` | Toggle xFormers acceleration for WebUI. | Only honored when NVIDIA drivers are detected. Disabled automatically when unsupported or when DirectML is enabled. |
| `enable_directml` | Enable DirectML mode. | Offered for AMD/Intel GPUs detected under Windows/WSL. Mutually exclusive with xFormers. |
| `enable_low_vram` | Apply `--medvram` when launching WebUI. | Auto-enabled when <8GB of VRAM is detected on NVIDIA cards; can be forced on/off explicitly. |

Additional scalar fields in JSON files are ignored by the loader to keep parsing predictable.

### Profiles and schema validation

For CI runs you can ship repeatable profiles and validate them automatically:

* `--profile ci-basic` loads `modules/config_service/profiles/ci-basic.yaml` and validates it against `installer_schema.yaml`.
* `--config-schema /path/to/custom-schema.yaml` points the installer at a different schema if your pipeline needs extra keys.

Both flags work with `--headless` and will abort early with a log entry if validation fails.

## Formats

### Env-style file
```
gpu_mode=nvidia
install_target=models
huggingface_token=hf_your_token_here
```

### JSON file
```
{
  "gpu_mode": "cpu",
  "install_target": "webui",
  "huggingface_token": "hf_your_token_here"
}
```

Place your config anywhere and pass it via `--config /path/to/file`. When `--config` is omitted, the installer uses `~/.config/aihub/installer.conf` and logs whether values were loaded or defaults were applied.

See [`docs/headless-config.json`](headless-config.json) for a ready-to-use template.
