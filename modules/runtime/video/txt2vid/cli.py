"""CLI entrypoint for txt2vid."""
from __future__ import annotations

import argparse
import json
from typing import Any, Dict

from modules.runtime.models.tasks import serialize_task
from .services import run_txt2vid_from_payload


def _load_payload(args: argparse.Namespace) -> Dict[str, Any]:
    if args.payload_json:
        return json.loads(args.payload_json)
    if args.payload_file:
        return json.loads(args.payload_file.read_text(encoding="utf-8"))
    if args.prompt:
        return {"prompt": args.prompt, "duration": args.duration}
    raw = args.stdin.read() if not args.stdin.isatty() else ""
    if raw:
        return json.loads(raw)
    raise ValueError("Provide --prompt or a JSON payload")


def main() -> None:
    parser = argparse.ArgumentParser(description="AI Hub txt2vid CLI")
    parser.add_argument("--prompt", help="Text prompt to animate")
    parser.add_argument("--duration", type=int, default=4, help="Duration in seconds")
    parser.add_argument("--payload-json", dest="payload_json", help="Inline JSON payload")
    parser.add_argument("--payload-file", dest="payload_file", type=argparse.FileType("r"), help="Path to JSON payload")
    parser.add_argument("--stdin", type=argparse.FileType("r"), default="-", help="Optional stdin handle")
    args = parser.parse_args()

    payload = _load_payload(args)
    task = run_txt2vid_from_payload(payload)
    print(json.dumps(serialize_task(task), indent=2))


if __name__ == "__main__":
    main()
