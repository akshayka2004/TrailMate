from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.models import PathSegment
from app.schemas.path_segment import PathSegmentCreate, PathSegmentOut

router = APIRouter(prefix="/paths", tags=["paths"])

admin_or_staff = require_role("admin", "staff")


@router.get("", response_model=list[PathSegmentOut])
async def list_paths(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(PathSegment).order_by(PathSegment.id))
    return result.scalars().all()


@router.post(
    "",
    response_model=PathSegmentOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(admin_or_staff)],
)
async def create_path(
    body: PathSegmentCreate, db: Annotated[AsyncSession, Depends(get_db)]
):
    segment = PathSegment(points=body.points)
    db.add(segment)
    await db.commit()
    await db.refresh(segment)
    return segment


@router.delete(
    "/{path_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(admin_or_staff)],
)
async def delete_path(path_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    segment = await db.get(PathSegment, path_id)
    if segment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Path segment not found")
    await db.delete(segment)
    await db.commit()
