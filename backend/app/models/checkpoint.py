from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Checkpoint(Base):
    __tablename__ = "checkpoints"

    id: Mapped[int] = mapped_column(primary_key=True)
    label: Mapped[str] = mapped_column(String(200))
    lat: Mapped[float]
    lng: Mapped[float]
    # use_alter breaks the circular FK with qrcodes (created via post-hoc ALTER).
    qr_code_id: Mapped[int | None] = mapped_column(
        ForeignKey(
            "qrcodes.id",
            ondelete="SET NULL",
            use_alter=True,
            name="fk_checkpoints_qr_code_id",
        ),
        nullable=True,
    )
    # NULL building_id means outdoor node. RESTRICT: deleting a building with
    # checkpoints must fail loudly, never silently orphan the graph.
    building_id: Mapped[int | None] = mapped_column(
        ForeignKey("buildings.id", ondelete="RESTRICT"), nullable=True, index=True
    )
