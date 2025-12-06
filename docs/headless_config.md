# Headless installer configuration

Headless runs can load a configuration file when you pass `--headless` (optionally with `--config <file>`). The installer supports simple `KEY=value` files **or** JSON objects and logs every decision—including defaults when entries are missing—to `~/.config/aihub/install.log`.

## Supported keys

| Key               | Purpose                                                                   | Notes |
| ----------------- | ------------------------------------------------------------------------- | ----- |
| `gpu_mode`        | Force GPU mode selection (`nvidia`, `amd`, `intel`, or `cpu`).            | CLI `--gpu` takes precedence. Defaults to hardware detection/CPU fallback when absent. |
| `install_target`  | Automatically run a specific installer (`webui`, `kobold`, `sillytavern`, `loras`, or `models`). | CLI `--install` takes precedence. Leaving this blank creates the launcher without auto-installing. |
| `huggingface_token` | Token used by model installers for authenticated Hugging Face downloads. | `HUGGINGFACE_TOKEN` environment variables take precedence. Anonymous downloads are used when the token is missing. |

Additional scalar fields in JSON files are ignored by the loader to keep parsing predictable.

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
