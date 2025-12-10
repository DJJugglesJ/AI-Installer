"""CLI entrypoint for img2vid."""
from __future__ import annotations

import argparse
import json
from typing import Any, Dict

from modules.runtime.models.tasks import serialize_task
from .services import run_img2vid_from_payload


def _load_payload(args: argparse.Namespace) -> Dict[str, Any]:
    if args.payload_json:
        return json.loads(args.payload_json)
    if args.payload_file:
        return json.loads(args.payload_file.read_text(encoding="utf-8"))
    if args.image_path:
        payload: Dict[str, Any] = {"image_path": args.image_path, "frames": args.frames}
        if args.prompt:
            payload["prompt"] = args.prompt
        return payload
    raw = args.stdin.read() if not args.stdin.isatty() else ""
    if raw:
        return json.loads(raw)
    raise ValueError("Provide --image-path or a JSON payload")


def main() -> None:
    parser = argparse.ArgumentParser(description="AI Hub img2vid CLI")
    parser.add_argument("--image-path", dest="image_path", help="Source image")
    parser.add_argument("--prompt", help="Optional guidance prompt")
    parser.add_argument("--frames", type=int, default=16, help="Frame count")
    parser.add_argument("--payload-json", dest="payload_json", help="Inline JSON payload")
    parser.add_argument("--payload-file", dest="payload_file", type=argparse.FileType("r"), help="Path to JSON payload")
    parser.add_argument("--stdin", type=argparse.FileType("r"), default="-", help="Optional stdin handle")
    args = parser.parse_args()

    payload = _load_payload(args)
    task = run_img2vid_from_payload(payload)
    print(json.dumps(serialize_task(task), indent=2))


if __name__ == "__main__":
    main()
