from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.route import RouteOut, RouteStepOut
from app.services.graph import (
    NoRouteError,
    UnknownCheckpointError,
    build_graph,
    find_route,
)

router = APIRouter(tags=["navigation"])


@router.get("/route", response_model=RouteOut)
async def get_route(
    db: Annotated[AsyncSession, Depends(get_db)],
    from_id: Annotated[int, Query(description="Start checkpoint id")],
    to_id: Annotated[int, Query(description="Destination checkpoint id")],
) -> RouteOut:
    graph, checkpoints = await build_graph(db)
    try:
        result = find_route(graph, checkpoints, from_id, to_id)
    except UnknownCheckpointError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown checkpoint id")
    except NoRouteError:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "No route exists between these checkpoints",
        )
    return RouteOut(
        from_id=from_id,
        to_id=to_id,
        steps=[
            RouteStepOut(
                checkpoint_id=s.checkpoint_id, label=s.label, lat=s.lat, lng=s.lng
            )
            for s in result.steps
        ],
        total_distance_meters=result.total_distance_meters,
        total_time_seconds=result.total_time_seconds,
    )
