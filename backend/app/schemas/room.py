from pydantic import BaseModel, ConfigDict, Field

from app.models import RoomType


class RoomBase(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    type: RoomType
    floor: int
    building_id: int


class RoomCreate(RoomBase):
    pass


class RoomUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    type: RoomType | None = None
    floor: int | None = None
    building_id: int | None = None


class RoomOut(RoomBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
