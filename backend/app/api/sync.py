from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.schemas.sync import SnapshotGraph, SnapshotOut, SnapshotVersionOut
from app.services.snapshot import (
    build_graph_payload,
    latest_version,
    publish_snapshot,
)

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/snapshot", response_model=SnapshotOut)
async def get_snapshot(db: Annotated[AsyncSession, Depends(get_db)]) -> SnapshotOut:
    """Full campus graph for offline caching, tagged with the latest
    published version (0 if nothing has been published yet)."""
    current = await latest_version(db)
    payload = await build_graph_payload(db)
    return SnapshotOut(
        version=current.version if current else 0,
        generated_at=current.generated_at if current else None,
        graph=SnapshotGraph(**payload),
    )


@router.post(
    "/snapshot",
    response_model=SnapshotVersionOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_role("admin", "staff"))],
)
async def publish(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SnapshotVersionOut:
    """Publish a new snapshot version so cached clients know to re-sync."""
    return await publish_snapshot(db)
