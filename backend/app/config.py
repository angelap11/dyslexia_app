"""Environment-backed settings. Secrets never live in source code."""

from __future__ import annotations

import os
from functools import lru_cache


@lru_cache(maxsize=1)
def get_settings() -> "Settings":
    return Settings()


class Settings:
    def __init__(self) -> None:
        self.model_id: str = os.getenv(
            "SIMPLIFY_MODEL_ID", "LVSTCK/domestic-yak-8B-instruct"
        ).strip()
        self.hf_token: str | None = _optional_env("HF_TOKEN") or _optional_env(
            "HUGGING_FACE_HUB_TOKEN"
        )
        self.api_key: str | None = _optional_env("SIMPLIFY_API_KEY")
        # When true, skip GPU model load (API validation / CI only).
        self.skip_model_load: bool = _truthy(os.getenv("SIMPLIFY_SKIP_MODEL_LOAD"))
        self.host: str = os.getenv("SIMPLIFY_HOST", "0.0.0.0").strip()
        self.port: int = int(os.getenv("SIMPLIFY_PORT", "8000"))


def _optional_env(name: str) -> str | None:
    value = os.getenv(name, "").strip()
    return value or None


def _truthy(value: str | None) -> bool:
    if value is None:
        return False
    return value.strip().lower() in {"1", "true", "yes", "on"}
