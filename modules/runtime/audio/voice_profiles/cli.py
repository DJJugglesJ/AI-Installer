"""CLI entrypoint for voice profile discovery."""
from __future__ import annotations

import argparse
import json

from modules.runtime.models.tasks import serialize_task
from .services import list_voice_profiles


def main() -> None:
    parser = argparse.ArgumentParser(description="List available voice profiles")
    parser.parse_args()
    task = list_voice_profiles()
    print(json.dumps(serialize_task(task), indent=2))


if __name__ == "__main__":
    main()
