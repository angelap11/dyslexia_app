"""Optional Bearer API key check (SIMPLIFY_API_KEY env)."""

from __future__ import annotations

from fastapi import Header, HTTPException, status

from .config import get_settings


async def require_api_key(
    authorization: str | None = Header(default=None),
) -> None:
    expected = get_settings().api_key
    if not expected:
        # Auth disabled when no key is configured (local GPU bring-up).
        return

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header. Use: Bearer <API_KEY>",
        )

    token = authorization.removeprefix("Bearer ").strip()
    if token != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )
