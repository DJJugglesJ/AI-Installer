import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.runtime.video.img2vid.services import (  # noqa: E402
    run_img2vid_from_payload,
)
from modules.runtime.video.txt2vid.services import (  # noqa: E402
    run_txt2vid_from_payload,
)


def test_run_img2vid_rejects_non_integer_frames():
    payload = {"image_path": "demo.png", "frames": "nope"}

    with pytest.raises(ValueError, match="frames must be an integer"):
        run_img2vid_from_payload(payload)


def test_run_txt2vid_rejects_non_integer_duration():
    payload = {"prompt": "a demo", "duration": "bad"}

    with pytest.raises(ValueError, match="duration must be an integer"):
        run_txt2vid_from_payload(payload)
