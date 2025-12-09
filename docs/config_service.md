# Configuration service

The configuration service lives in `modules/config_service/` and owns the canonical JSON/YAML configuration at `~/.config/aihub/config.yaml`.
The helper automatically mirrors a legacy env-style export to `~/.config/aihub/installer.conf` so existing shell modules can continue to `source` values.

> **Dependency note:** YAML parsing relies on [PyYAML](https://pyyaml.org/). Install it with `pip install -r requirements.txt` (or `pip install PyYAML`) before running the installer or calling the configuration CLI.

## Priority rules

1. **CLI flags** passed to `install.sh` (e.g., `--gpu nvidia`, `--install webui`) are forwarded as overrides to the service.
2. **Environment variables** with the `AIHUB_` prefix (for example, `AIHUB_GPU_MODE=cpu` or `AIHUB_INSTALLER__INSTALL_TARGET=webui`) override saved values.
3. **Saved configuration** in `config.yaml` is loaded next.
4. **Built-in defaults** from the service are used when no other value is present.

The service emits warnings for deprecated fields or invalid values and writes migrations back to disk automatically.

## CLI usage

```bash
# Export current config (merged with env/CLI overrides) as env assignments
python modules/config_service/config_service.py export --format env

# Export and write the legacy env file used by shell scripts
python modules/config_service/config_service.py export --write-env ~/.config/aihub/installer.conf

# Save updates using dotted paths
python modules/config_service/config_service.py save --set gpu.mode=nvidia --set performance.enable_fp16=true

# Force migration to the latest schema
python modules/config_service/config_service.py migrate
```

## Shell helpers

Shell scripts source `modules/config_service/config_helpers.sh` to load/export config and persist changes using `config_set`.
This ensures values like GPU mode, install status, and performance flags are validated and stored consistently in both YAML and env formats.
