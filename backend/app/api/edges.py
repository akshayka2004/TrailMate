from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.models import Checkpoint, Edge
from app.schemas.edge import EdgeCreate, EdgeOut, EdgeUpdate

router = APIRouter(prefix="/edges", tags=["edges"])

admin_or_staff = require_role("admin", "staff")


@router.get("", response_model=list[EdgeOut])
async def list_edges(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Edge).order_by(Edge.id))
    return result.scalars().all()


@router.post(
    "",
    response_model=EdgeOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(admin_or_staff)],
)
async def create_edge(body: EdgeCreate, db: Annotated[AsyncSession, Depends(get_db)]):
    for cp_id in (body.checkpoint_a_id, body.checkpoint_b_id):
        if await db.get(Checkpoint, cp_id) is None:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY,
                f"Unknown checkpoint id {cp_id}",
            )

    # Undirected graph: reject a duplicate regardless of endpoint order.
    lo, hi = sorted((body.checkpoint_a_id, body.checkpoint_b_id))
    # path is stored relative to (a=lo, b=hi) — reverse it if the caller's
    # original a/b order got swapped above.
    path = body.path
    if path is not None and body.checkpoint_a_id != lo:
        path = list(reversed(path))
    dupe = await db.execute(
        select(Edge).where(
            or_(
                (Edge.checkpoint_a_id == lo) & (Edge.checkpoint_b_id == hi),
                (Edge.checkpoint_a_id == hi) & (Edge.checkpoint_b_id == lo),
            )
        )
    )
    if dupe.scalar_one_or_none() is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "An edge between these checkpoints already exists"
        )

    edge = Edge(
        checkpoint_a_id=lo,
        checkpoint_b_id=hi,
        distance_meters=body.distance_meters,
        walking_time_estimate_sec=body.walking_time_estimate_sec,
        is_indoor=body.is_indoor,
        path=path,
    )
    db.add(edge)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Duplicate edge")
    await db.refresh(edge)
    return edge


@router.patch(
    "/{edge_id}",
    response_model=EdgeOut,
    dependencies=[Depends(admin_or_staff)],
)
async def update_edge(
    edge_id: int, body: EdgeUpdate, db: Annotated[AsyncSession, Depends(get_db)]
):
    edge = await db.get(Edge, edge_id)
    if edge is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Edge not found")
    edge.path = body.path
    await db.commit()
    await db.refresh(edge)
    return edge


@router.delete(
    "/{edge_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(admin_or_staff)],
)
async def delete_edge(edge_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    edge = await db.get(Edge, edge_id)
    if edge is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Edge not found")
    await db.delete(edge)
    await db.commit()
