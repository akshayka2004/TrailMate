import io

import qrcode

PAYLOAD_PREFIX = "TRAILMATE:CP:"


def payload_for_checkpoint(checkpoint_id: int) -> str:
    return f"{PAYLOAD_PREFIX}{checkpoint_id}"


def render_qr_png(payload: str) -> bytes:
    """Render a QR code for `payload` and return PNG bytes."""
    img = qrcode.make(payload)
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()
