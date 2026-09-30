from sqlalchemy import JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class PathSegment(Base):
    """A free-drawn walkable path — not tied to any specific checkpoint
    pair. Ordered [lat, lng] points tracing a real road/sidewalk. Routing
    connects checkpoints to the nearest point on the nearest segment, and
    stitches segments together wherever they physically cross, rather than
    requiring an admin to wire up every checkpoint pair by hand.
    """

    __tablename__ = "path_segments"

    id: Mapped[int] = mapped_column(primary_key=True)
    points: Mapped[list[list[float]]] = mapped_column(JSON)
