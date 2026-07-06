"""Build the offline-sync snapshot: the full campus graph + metadata.

Supabase Storage upload lands in Phase 8. Until then the payload is served
live from the DB and the SyncSnapshot.version integer is the staleness
signal: mobile caches a version, and re-pulls when a newer one is published.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Building,
    Checkpoint,
    Department,
    Edge,
    Room,
    SyncSnapshot,
)


async def latest_version(db: AsyncSession) -> SyncSnapshot | None:
    result = await db.execute(
        select(SyncSnapshot).order_by(SyncSnapshot.version.desc()).limit(1)
    )
    return result.scalar_one_or_none()


async def build_graph_payload(db: AsyncSession) -> dict:
    buildings = (await db.execute(select(Building))).scalars().all()
    departments = (await db.execute(select(Department))).scalars().all()
    rooms = (await db.execute(select(Room))).scalars().all()
    checkpoints = (await db.execute(select(Checkpoint))).scalars().all()
    edges = (await db.execute(select(Edge))).scalars().all()
    return {
        "buildings": buildings,
        "departments": departments,
        "rooms": rooms,
        "checkpoints": checkpoints,
        "edges": edges,
    }


async def publish_snapshot(db: AsyncSession) -> SyncSnapshot:
    """Mint the next snapshot version. payload_url points at the live
    versioned endpoint until Supabase blob storage exists (Phase 8)."""
    current = await latest_version(db)
    next_version = (current.version + 1) if current else 1
    snapshot = SyncSnapshot(
        version=next_version,
        payload_url=f"/sync/snapshot?version={next_version}",
    )
    db.add(snapshot)
    await db.commit()
    await db.refresh(snapshot)
    return snapshot
