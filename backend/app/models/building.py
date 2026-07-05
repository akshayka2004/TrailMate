from typing import Any

from geoalchemy2 import Geometry
from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Building(Base):
    __tablename__ = "buildings"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200), unique=True)
    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(500))
    lat: Mapped[float]
    lng: Mapped[float]
    footprint: Mapped[Any | None] = mapped_column(
        Geometry(geometry_type="POLYGON", srid=4326), nullable=True
    )
