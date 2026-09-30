from pydantic import BaseModel, ConfigDict, Field, model_validator


class EdgeBase(BaseModel):
    checkpoint_a_id: int
    checkpoint_b_id: int
    distance_meters: float = Field(gt=0)
    walking_time_estimate_sec: int = Field(gt=0)
    is_indoor: bool = False
    # Ordered [lat, lng] waypoints tracing the real walkway, in the direction
    # checkpoint_a -> checkpoint_b (endpoints get sorted to a=min(id) on
    # create, so this is always relative to the *stored* a/b, not whichever
    # order the caller passed them in).
    path: list[list[float]] | None = None

    @model_validator(mode="after")
    def _distinct_endpoints(self) -> "EdgeBase":
        if self.checkpoint_a_id == self.checkpoint_b_id:
            raise ValueError("An edge must connect two distinct checkpoints")
        return self


class EdgeCreate(EdgeBase):
    pass


class EdgeUpdate(BaseModel):
    path: list[list[float]] | None = None


class EdgeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    checkpoint_a_id: int
    checkpoint_b_id: int
    distance_meters: float
    walking_time_estimate_sec: int
    is_indoor: bool
    path: list[list[float]] | None = None
