from pydantic import BaseModel, ConfigDict, Field


class CheckpointBase(BaseModel):
    label: str = Field(min_length=1, max_length=200)
    lat: float
    lng: float
    building_id: int | None = None


class CheckpointCreate(CheckpointBase):
    pass


class CheckpointUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=200)
    lat: float | None = None
    lng: float | None = None
    building_id: int | None = None


class CheckpointOut(CheckpointBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    qr_code_id: int | None = None
