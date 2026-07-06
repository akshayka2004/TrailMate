from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.schemas.building import BuildingOut
from app.schemas.checkpoint import CheckpointOut
from app.schemas.department import DepartmentOut
from app.schemas.edge import EdgeOut
from app.schemas.room import RoomOut


class SnapshotGraph(BaseModel):
    buildings: list[BuildingOut]
    departments: list[DepartmentOut]
    rooms: list[RoomOut]
    checkpoints: list[CheckpointOut]
    edges: list[EdgeOut]


class SnapshotOut(BaseModel):
    """Full campus dataset the mobile app caches for offline use."""

    version: int
    generated_at: datetime | None
    graph: SnapshotGraph


class SnapshotVersionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    version: int
    generated_at: datetime
    payload_url: str
