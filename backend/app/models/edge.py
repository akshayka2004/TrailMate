from sqlalchemy import ForeignKey, UniqueConstraint
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
