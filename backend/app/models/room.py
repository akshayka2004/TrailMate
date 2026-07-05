import enum

from sqlalchemy import Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class RoomType(str, enum.Enum):
    classroom = "classroom"
    lab = "lab"
    seminar_hall = "seminar_hall"
    office = "office"


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    type: Mapped[RoomType] = mapped_column(Enum(RoomType, name="room_type"))
    floor: Mapped[int]
    building_id: Mapped[int] = mapped_column(
        ForeignKey("buildings.id", ondelete="CASCADE"), index=True
    )
