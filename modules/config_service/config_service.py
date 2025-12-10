#!/usr/bin/env python3
"""Configuration service for AI Hub.

Loads and saves a single JSON/YAML configuration file with schema validation,
migrations, and compatibility exports for shell consumers.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Tuple

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from modules.path_utils import get_config_root, get_state_path


class ConfigError(Exception):
    pass


def _import_yaml():  # pragma: no cover - import guard
    try:
        import yaml  # type: ignore
    except ImportError as exc:
        raise ConfigError(
            "PyYAML is required to load installer profiles and schemas. "
            "Install it with `pip install -r requirements.txt` (or `pip install PyYAML`) and rerun the installer."
        ) from exc
    return yaml


try:
    yaml = _import_yaml()
except ConfigError as exc:  # pragma: no cover - dependency gate
    print(f"[error] {exc}", file=sys.stderr)
    sys.exit(1)

CONFIG_ROOT = str(get_config_root())
DEFAULT_CONFIG_PATH = str(get_state_path())
CURRENT_VERSION = 2
INSTALLER_SCHEMA_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "installer_schema.yaml"
)


DEFAULT_CONFIG: Dict[str, Any] = {
    "version": CURRENT_VERSION,
    "paths": {
        "models": "",
        "loras": "",
        "checkpoints": "",
    },
    "gpu": {
        "mode": "auto",
        "supports_fp16": None,
        "supports_xformers": None,
        "supports_directml": None,
        "detected_gpu": "",
        "detected_vram_gb": None,
    },
    "performance": {
        "enable_fp16": None,
        "enable_xformers": None,
        "enable_directml": None,
        "enable_low_vram": None,
    },
    "installer": {
        "install_target": "",
        "huggingface_token": "",
    },
    "ui": {
        "headless_default": False,
        "theme": "system",
    },
    "state": {
        "webui_installed": False,
        "kobold_installed": False,
        "sillytavern_installed": False,
        "loras_installed": False,
        "models_installed": False,
    },
    "selection": {"model": "", "loras": []},
}

# Map deprecated top-level fields to their new home
DEPRECATED_FIELD_MAP = {
    "install_target": "installer.install_target",
    "huggingface_token": "installer.huggingface_token",
    "gpu_mode": "gpu.mode",
    "enable_fp16": "performance.enable_fp16",
    "enable_xformers": "performance.enable_xformers",
    "enable_directml": "performance.enable_directml",
    "enable_low_vram": "performance.enable_low_vram",
    "webui_installed": "state.webui_installed",
    "kobold_installed": "state.kobold_installed",
    "sillytavern_installed": "state.sillytavern_installed",
    "loras_installed": "state.loras_installed",
    "models_installed": "state.models_installed",
    "detected_vram_gb": "gpu.detected_vram_gb",
    "gpu_supports_fp16": "gpu.supports_fp16",
    "gpu_supports_xformers": "gpu.supports_xformers",
    "gpu_supports_directml": "gpu.supports_directml",
}


@dataclass
class LoadedConfig:
    data: Dict[str, Any]
    warnings: List[str]
    migrated: bool


def ensure_config_root(path: str) -> None:
    root = os.path.dirname(path)
    if root and not os.path.exists(root):
        os.makedirs(root, exist_ok=True)


def coerce_value(value: Any) -> Any:
    if isinstance(value, str):
        lower = value.strip().lower()
        if lower in {"true", "1", "yes", "on"}:
            return True
        if lower in {"false", "0", "no", "off"}:
            return False
        if lower.isdigit():
            try:
                return int(lower)
            except ValueError:
                return value
    return value


def deep_get(data: Dict[str, Any], path: str) -> Any:
    current: Any = data
    for key in path.split("."):
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def deep_set(data: Dict[str, Any], path: str, value: Any) -> None:
    current = data
    parts = path.split(".")
    for key in parts[:-1]:
        if key not in current or not isinstance(current[key], dict):
            current[key] = {}
        current = current[key]
    current[parts[-1]] = value


def parse_env_style(text: str) -> Dict[str, Any]:
    parsed: Dict[str, Any] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        parsed[key.strip()] = coerce_value(value.strip())
    return parsed


def load_structured_file(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if not text.strip():
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        loaded = yaml.safe_load(text)
        if not isinstance(loaded, dict):
            raise ConfigError("Installer profile files must be a mapping/object.")
        return loaded


def load_raw_config(path: str) -> Tuple[Dict[str, Any], List[str]]:
    warnings: List[str] = []
    if not os.path.exists(path):
        return deepcopy(DEFAULT_CONFIG), warnings

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    stripped = text.lstrip()
    if not stripped:
        return deepcopy(DEFAULT_CONFIG), warnings

    if stripped.startswith("{") or stripped.startswith("["):
        data = json.loads(text)
    elif stripped[0] in {"-", ":"} or ":" in stripped.splitlines()[0]:
        data = yaml.safe_load(text) or {}
    else:
        parsed = parse_env_style(text)
        data = {"version": 0, **parsed}
        warnings.append("Loaded legacy env-style configuration; it will be migrated to structured YAML/JSON.")
    if not isinstance(data, dict):
        raise ConfigError("Configuration root must be an object/dictionary.")
    return data, warnings


def migrate_v0_to_v1(data: Dict[str, Any], warnings: List[str]) -> Dict[str, Any]:
    migrated = deepcopy(DEFAULT_CONFIG)
    for key, value in data.items():
        if key == "version":
            continue
        target = DEPRECATED_FIELD_MAP.get(key)
        if not target:
            warnings.append(f"Deprecated or unknown field '{key}' preserved under legacy namespace.")
            migrated.setdefault("legacy", {})[key] = value
            continue
        deep_set(migrated, target, value)
    migrated["version"] = 1
    return migrated


def migrate_v1_to_v2(data: Dict[str, Any], warnings: List[str]) -> Dict[str, Any]:
    data = deepcopy(data)
    data.setdefault("ui", {})
    data["ui"].setdefault("theme", DEFAULT_CONFIG["ui"]["theme"])
    data["ui"].setdefault("headless_default", DEFAULT_CONFIG["ui"]["headless_default"])
    data["version"] = 2
    return data


MIGRATIONS = {
    0: migrate_v0_to_v1,
    1: migrate_v1_to_v2,
}


ALLOWED_GPU_MODES = {"auto", "nvidia", "amd", "intel", "cpu"}


def load_installer_schema(path: str = INSTALLER_SCHEMA_PATH) -> Dict[str, Any]:
    if not os.path.exists(path):
        raise ConfigError(f"Installer schema file not found at {path}")
    try:
        return load_structured_file(path)
    except ConfigError:
        raise
    except Exception as exc:  # pragma: no cover - defensive
        raise ConfigError(f"Failed to parse installer schema: {exc}")


def validate_simple_type(value: Any, expected: Any) -> bool:
    type_map = {
        "string": str,
        "boolean": bool,
        "number": (int, float),
        "integer": int,
        "object": dict,
        "array": list,
    }
    if isinstance(expected, list):
        return any(validate_simple_type(value, t) for t in expected)
    py_type = type_map.get(expected)
    if py_type is None:
        return True
    return isinstance(value, py_type)


def validate_schema_fragment(value: Any, schema: Dict[str, Any], path: str, errors: List[str]) -> None:
    expected_type = schema.get("type")
    enum = schema.get("enum")

    if enum is not None and value not in enum:
        errors.append(f"{path or 'value'} must be one of {enum}; received {value!r}")
        return

    if expected_type == "array":
        if not isinstance(value, list):
            errors.append(f"{path or 'value'} must be an array/list")
            return
        item_schema = schema.get("items")
        if item_schema:
            for idx, child in enumerate(value):
                validate_schema_fragment(child, item_schema, f"{path}[{idx}]", errors)
        return

    if expected_type == "object":
        if not isinstance(value, dict):
            errors.append(f"{path or 'value'} must be an object/mapping")
            return
        properties: Dict[str, Any] = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        for key, child in value.items():
            if key in properties:
                validate_schema_fragment(child, properties[key], f"{path}.{key}" if path else key, errors)
            elif additional is False:
                errors.append(f"Unexpected field '{key}' in {path or 'root'}")
            elif isinstance(additional, dict):
                validate_schema_fragment(child, additional, f"{path}.{key}" if path else key, errors)
        return

    if expected_type and not validate_simple_type(value, expected_type):
        errors.append(f"{path or 'value'} expected type {expected_type}; received {type(value).__name__}")


def validate_against_schema(data: Dict[str, Any], schema: Dict[str, Any]) -> List[str]:
    errors: List[str] = []
    validate_schema_fragment(data, schema, path="", errors=errors)
    return errors


def validate(config: Dict[str, Any], warnings: List[str]) -> Dict[str, Any]:
    gpu_mode = deep_get(config, "gpu.mode")
    if gpu_mode not in ALLOWED_GPU_MODES:
        if gpu_mode is None:
            deep_set(config, "gpu.mode", "auto")
        else:
            warnings.append(
                f"Invalid gpu.mode '{gpu_mode}' replaced with 'auto'. Allowed: {sorted(ALLOWED_GPU_MODES)}"
            )
            deep_set(config, "gpu.mode", "auto")

    def validate_bool(path: str) -> None:
        value = deep_get(config, path)
        if value is None:
            return
        if isinstance(value, bool):
            return
        warnings.append(f"Field {path} expected boolean; coerced from '{value}'.")
        deep_set(config, path, bool(coerce_value(str(value))))

    for field in [
        "performance.enable_fp16",
        "performance.enable_xformers",
        "performance.enable_directml",
        "performance.enable_low_vram",
        "gpu.supports_fp16",
        "gpu.supports_xformers",
        "gpu.supports_directml",
        "ui.headless_default",
        "state.webui_installed",
        "state.kobold_installed",
        "state.sillytavern_installed",
        "state.loras_installed",
        "state.models_installed",
    ]:
        validate_bool(field)

    return config


def migrate(data: Dict[str, Any], warnings: List[str]) -> Tuple[Dict[str, Any], bool]:
    migrated = False
    version = data.get("version", 0)
    while version < CURRENT_VERSION:
        migrate_fn = MIGRATIONS.get(version)
        if not migrate_fn:
            raise ConfigError(f"No migration path from version {version}")
        data = migrate_fn(data, warnings)
        version = data.get("version", version + 1)
        migrated = True
    return data, migrated


def save_config(data: Dict[str, Any], path: str) -> None:
    ensure_config_root(path)
    ext = os.path.splitext(path)[1].lower()
    if ext in {".yaml", ".yml"}:
        with open(path, "w", encoding="utf-8") as f:
            yaml.safe_dump(data, f, sort_keys=False)
    else:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)


def flatten_for_env(config: Dict[str, Any]) -> Dict[str, Any]:
    flattened = {
        "gpu_mode": deep_get(config, "gpu.mode"),
        "install_target": deep_get(config, "installer.install_target"),
        "huggingface_token": deep_get(config, "installer.huggingface_token"),
        "enable_fp16": deep_get(config, "performance.enable_fp16"),
        "enable_xformers": deep_get(config, "performance.enable_xformers"),
        "enable_directml": deep_get(config, "performance.enable_directml"),
        "enable_low_vram": deep_get(config, "performance.enable_low_vram"),
        "gpu_supports_fp16": deep_get(config, "gpu.supports_fp16"),
        "gpu_supports_xformers": deep_get(config, "gpu.supports_xformers"),
        "gpu_supports_directml": deep_get(config, "gpu.supports_directml"),
        "detected_gpu": deep_get(config, "gpu.detected_gpu"),
        "detected_vram_gb": deep_get(config, "gpu.detected_vram_gb"),
        "webui_installed": deep_get(config, "state.webui_installed"),
        "kobold_installed": deep_get(config, "state.kobold_installed"),
        "sillytavern_installed": deep_get(config, "state.sillytavern_installed"),
        "loras_installed": deep_get(config, "state.loras_installed"),
        "models_installed": deep_get(config, "state.models_installed"),
        "config_version": config.get("version", CURRENT_VERSION),
    }
    return {k: v for k, v in flattened.items() if v is not None}


def apply_overrides(config: Dict[str, Any], overrides: List[str]) -> None:
    for override in overrides:
        if "=" not in override:
            raise ConfigError(f"Override '{override}' must use key=value format")
        key, raw_value = override.split("=", 1)
        deep_set(config, key.strip(), coerce_value(raw_value.strip()))


def apply_env_overrides(config: Dict[str, Any], prefix: str, warnings: List[str]) -> None:
    if not prefix:
        return
    for key, value in os.environ.items():
        if not key.startswith(prefix):
            continue
        path = key[len(prefix) :].lower().replace("__", ".")
        warnings.append(f"Environment override {key} applied to {path}")
        deep_set(config, path, coerce_value(value))


def load_installer_profile(file_path: str | None, profile: str | None, schema_path: str) -> Dict[str, Any]:
    schema = load_installer_schema(schema_path)
    merged: Dict[str, Any] = {}

    if profile:
        profile_path = profile
        if not os.path.exists(profile_path):
            candidate = os.path.join(os.path.dirname(schema_path), "profiles", f"{profile}.yaml")
            if os.path.exists(candidate):
                profile_path = candidate
        if not os.path.exists(profile_path):
            raise ConfigError(f"Profile '{profile}' not found at {profile_path}")
        merged.update(load_structured_file(profile_path))

    if file_path:
        if not os.path.exists(file_path):
            raise ConfigError(f"Installer config file not found: {file_path}")
        with open(file_path, "r", encoding="utf-8") as f:
            raw_text = f.read()
        if raw_text.strip().startswith("{") or raw_text.strip().startswith("["):
            merged.update(json.loads(raw_text))
        elif ":" in raw_text.splitlines()[0] or raw_text.strip().startswith("-"):
            merged.update(load_structured_file(file_path))
        else:
            merged.update(parse_env_style(raw_text))

    normalized: Dict[str, Any] = {}
    for key, value in merged.items():
        normalized[key] = coerce_value(value)

    validation_errors = validate_against_schema(normalized, schema)
    if validation_errors:
        raise ConfigError("; ".join(validation_errors))

    return normalized


def load_config(path: str, env_prefix: str, overrides: List[str]) -> LoadedConfig:
    raw, warnings = load_raw_config(path)
    migrated_config, migrated = migrate(raw, warnings)
    apply_env_overrides(migrated_config, env_prefix, warnings)
    if overrides:
        apply_overrides(migrated_config, overrides)
    validated = validate(migrated_config, warnings)
    return LoadedConfig(validated, warnings, migrated)


def export_env(config: Dict[str, Any]) -> str:
    flat = flatten_for_env(config)
    lines = [f"{key}={value}" for key, value in flat.items()]
    return "\n".join(lines)


def installer_env(config: Dict[str, Any]) -> str:
    lines = []
    for key, value in config.items():
        if isinstance(value, bool):
            value = "true" if value else "false"
        lines.append(f"{key}={value}")
    return "\n".join(lines)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AI Hub configuration service")
    parser.add_argument("--config", default=DEFAULT_CONFIG_PATH, help="Path to the JSON/YAML config file")
    subparsers = parser.add_subparsers(dest="command", required=True)

    export_parser = subparsers.add_parser("export", help="Export configuration")
    export_parser.add_argument("--format", choices=["json", "env"], default="env")
    export_parser.add_argument("--write-env", dest="write_env", help="Write a legacy env-style file alongside export")
    export_parser.add_argument("--env-prefix", default="AIHUB_", help="Environment variable prefix for overrides")
    export_parser.add_argument("--set", dest="overrides", action="append", default=[], help="Override key=value pairs")

    save_parser = subparsers.add_parser("save", help="Persist configuration changes")
    save_parser.add_argument("--set", dest="overrides", action="append", default=[], help="Updated key=value pairs")
    save_parser.add_argument("--write-env", dest="write_env", help="Write a legacy env-style file alongside save")

    subparsers.add_parser("migrate", help="Migrate config file to the latest version")
    installer_parser = subparsers.add_parser(
        "installer-profile", help="Validate and merge installer profile/config"
    )
    installer_parser.add_argument("--schema", default=INSTALLER_SCHEMA_PATH, help="Path to installer schema file")
    installer_parser.add_argument("--file", dest="file_path", help="User-supplied installer config path")
    installer_parser.add_argument("--profile", dest="profile", help="Named profile or path to profile file")
    installer_parser.add_argument("--set", dest="overrides", action="append", default=[], help="Additional overrides to merge")
    installer_parser.add_argument("--format", choices=["env", "json"], default="env")
    return parser


def command_export(args: argparse.Namespace) -> int:
    loaded = load_config(args.config, args.env_prefix, args.overrides)
    if loaded.migrated:
        save_config(loaded.data, args.config)
    if args.write_env:
        ensure_config_root(args.write_env)
        with open(args.write_env, "w", encoding="utf-8") as f:
            f.write(export_env(loaded.data) + "\n")
    if args.format == "json":
        json.dump(loaded.data, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        sys.stdout.write(export_env(loaded.data) + "\n")
    for note in loaded.warnings:
        print(f"[warn] {note}", file=sys.stderr)
    return 0


def command_save(args: argparse.Namespace) -> int:
    loaded = load_config(args.config, env_prefix="", overrides=args.overrides)
    save_config(loaded.data, args.config)
    if args.write_env:
        ensure_config_root(args.write_env)
        with open(args.write_env, "w", encoding="utf-8") as f:
            f.write(export_env(loaded.data) + "\n")
    for note in loaded.warnings:
        print(f"[warn] {note}", file=sys.stderr)
    return 0


def command_migrate(args: argparse.Namespace) -> int:
    raw, warnings = load_raw_config(args.config)
    migrated, did_migrate = migrate(raw, warnings)
    validated = validate(migrated, warnings)
    if did_migrate:
        save_config(validated, args.config)
    for note in warnings:
        print(f"[warn] {note}", file=sys.stderr)
    print(json.dumps({"migrated": did_migrate, "version": validated.get("version")}, indent=2))
    return 0


def command_installer_profile(args: argparse.Namespace) -> int:
    try:
        profile_data = load_installer_profile(args.file_path, args.profile, args.schema)
        if args.overrides:
            apply_overrides(profile_data, args.overrides)
            errors = validate_against_schema(profile_data, load_installer_schema(args.schema))
            if errors:
                raise ConfigError("; ".join(errors))
    except ConfigError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1

    if args.format == "json":
        json.dump(profile_data, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        sys.stdout.write(installer_env(profile_data) + "\n")
    return 0


def main(argv: List[str]) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "export":
            return command_export(args)
        if args.command == "save":
            return command_save(args)
        if args.command == "migrate":
            return command_migrate(args)
        if args.command == "installer-profile":
            return command_installer_profile(args)
    except ConfigError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
