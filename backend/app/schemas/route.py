from pydantic import BaseModel


class RouteStepOut(BaseModel):
    checkpoint_id: int
    label: str
    lat: float
    lng: float


class RouteOut(BaseModel):
    from_id: int
    to_id: int
    steps: list[RouteStepOut]
    total_distance_meters: float
    total_time_seconds: int
