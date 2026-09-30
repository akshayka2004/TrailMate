from sqlalchemy import ForeignKey, JSON, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Edge(Base):
    __tablename__ = "edges"
    __table_args__ = (
        UniqueConstraint("checkpoint_a_id", "checkpoint_b_id", name="uq_edge_pair"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    checkpoint_a_id: Mapped[int] = mapped_column(
        ForeignKey("checkpoints.id", ondelete="CASCADE"), index=True
    )
    checkpoint_b_id: Mapped[int] = mapped_column(
        ForeignKey("checkpoints.id", ondelete="CASCADE"), index=True
    )
    distance_meters: Mapped[float]
    walking_time_estimate_sec: Mapped[int]
    is_indoor: Mapped[bool] = mapped_column(default=False)
    # Ordered [lat, lng] waypoints tracing the real walkway from checkpoint_a
    # to checkpoint_b — lets the drawn route hug actual paths instead of a
    # straight line between the two checkpoints. None/empty = no shape data,
    # callers fall back to the straight line.
    path: Mapped[list[list[float]] | None] = mapped_column(JSON, default=None)
