from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class QRCode(Base):
    __tablename__ = "qrcodes"

    id: Mapped[int] = mapped_column(primary_key=True)
    # unique: one QR per checkpoint; CASCADE: QR is meaningless without it.
    checkpoint_id: Mapped[int] = mapped_column(
        ForeignKey("checkpoints.id", ondelete="CASCADE"), unique=True
    )
    payload: Mapped[str] = mapped_column(String(255), unique=True)
    image_url: Mapped[str | None] = mapped_column(String(500))
