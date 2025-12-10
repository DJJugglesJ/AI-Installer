"""Voice profile registry (placeholder)."""
from __future__ import annotations

from typing import List

from .models import VoiceProfile


def default_profiles() -> List[VoiceProfile]:
    return [
        VoiceProfile(name="basic_female", locale="en-US", description="Neutral female synthetic voice"),
        VoiceProfile(name="basic_male", locale="en-US", description="Neutral male synthetic voice"),
        VoiceProfile(name="multilingual", locale="multi", description="Multilingual placeholder voice"),
    ]
