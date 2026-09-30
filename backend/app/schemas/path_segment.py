from pydantic import BaseModel, ConfigDict, field_validator


class PathSegmentCreate(BaseModel):
    points: list[list[float]]

    @field_validator("points")
    @classmethod
    def _at_least_two_points(cls, v: list[list[float]]) -> list[list[float]]:
        if len(v) < 2:
            raise ValueError("A path segment needs at least 2 points")
        return v


class PathSegmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    points: list[list[float]]
