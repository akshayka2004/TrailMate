"""Supabase Storage upload via the REST API (no heavy SDK).

Used for building images, QR PNGs, and event posters. When SUPABASE_URL /
SUPABASE_KEY are unset (local dev), `is_configured()` is False and callers
should fall back to serving bytes directly from the API.
"""

import httpx

from app.core.config import settings

DEFAULT_BUCKET = "trailmate-public"


def is_configured() -> bool:
    return bool(settings.supabase_url and settings.supabase_key)


async def upload_bytes(
    path: str,
    data: bytes,
    content_type: str,
    bucket: str = DEFAULT_BUCKET,
    upsert: bool = True,
) -> str:
    """Upload `data` to `bucket/path` and return its public URL.

    Raises RuntimeError if Supabase is not configured, or httpx.HTTPStatusError
    on a non-2xx response.
    """
    if not is_configured():
        raise RuntimeError("Supabase storage is not configured")

    base = settings.supabase_url.rstrip("/")
    url = f"{base}/storage/v1/object/{bucket}/{path}"
    headers = {
        "Authorization": f"Bearer {settings.supabase_key}",
        "Content-Type": content_type,
        "x-upsert": "true" if upsert else "false",
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, content=data, headers=headers)
        resp.raise_for_status()
    return f"{base}/storage/v1/object/public/{bucket}/{path}"
