"""Platform-aware path utilities for AI Hub.

Provides a single source of truth for config, state, and log paths so
Windows entry points can map to APPDATA/LOCALAPPDATA while Unix-like
platforms continue to use XDG-style defaults.
"""
from __future__ import annotations

import os
import platform
from pathlib import Path


def _is_windows() -> bool:
    return platform.system().lower().startswith("windows")


def get_config_root() -> Path:
    """Return the base configuration directory.

    Environment overrides (AIHUB_CONFIG_DIR) take precedence. On Windows we
    align with %APPDATA%\AIHub\config; otherwise ~/.config/aihub is used.
    """

    override = os.environ.get("AIHUB_CONFIG_DIR")
    if override:
        return Path(override).expanduser()

    if _is_windows():
        appdata = os.environ.get("APPDATA")
        if appdata:
            return Path(appdata) / "AIHub" / "config"

    return Path.home() / ".config" / "aihub"


def get_config_file() -> Path:
    """Return the installer configuration file path."""

    override = os.environ.get("AIHUB_CONFIG_FILE") or os.environ.get("CONFIG_FILE")
    if override:
        return Path(override).expanduser()
    return get_config_root() / "installer.conf"


def get_state_path() -> Path:
    """Return the installer state file path."""

    override = os.environ.get("CONFIG_STATE_FILE") or os.environ.get("AIHUB_CONFIG_STATE")
    if override:
        return Path(override).expanduser()
    return get_config_root() / "config.yaml"


def get_log_path() -> Path:
    """Return the primary installer log path."""

    override = os.environ.get("AIHUB_LOG_PATH")
    if override:
        return Path(override).expanduser()

    if _is_windows():
        local_appdata = os.environ.get("LOCALAPPDATA")
        if local_appdata:
            return Path(local_appdata) / "AIHub" / "logs" / "install.log"

    return get_config_root() / "install.log"


def ensure_file_path(path: Path) -> Path:
    """Ensure the parent directory exists and the file is present."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch(exist_ok=True)
    return path
