from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.models import Building, Checkpoint, QRCode
from app.schemas.checkpoint import (
    CheckpointCreate,
    CheckpointOut,
    CheckpointUpdate,
)
from app.services.qr import payload_for_checkpoint, render_qr_png

router = APIRouter(prefix="/checkpoints", tags=["checkpoints"])

admin_or_staff = require_role("admin", "staff")


async def _require_building(db: AsyncSession, building_id: int | None) -> None:
    if building_id is not None and await db.get(Building, building_id) is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Unknown building_id")


@router.get("", response_model=list[CheckpointOut])
async def list_checkpoints(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Checkpoint).order_by(Checkpoint.id))
    return result.scalars().all()


@router.post(
    "",
    response_model=CheckpointOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(admin_or_staff)],
)
async def create_checkpoint(
    body: CheckpointCreate, db: Annotated[AsyncSession, Depends(get_db)]
):
    await _require_building(db, body.building_id)
    checkpoint = Checkpoint(**body.model_dump())
    db.add(checkpoint)
    await db.commit()
    await db.refresh(checkpoint)
    return checkpoint


@router.patch(
    "/{checkpoint_id}",
    response_model=CheckpointOut,
    dependencies=[Depends(admin_or_staff)],
)
async def update_checkpoint(
    checkpoint_id: int,
    body: CheckpointUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    checkpoint = await db.get(Checkpoint, checkpoint_id)
    if checkpoint is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Checkpoint not found")
    data = body.model_dump(exclude_unset=True)
    if "building_id" in data:
        await _require_building(db, data["building_id"])
    for field, value in data.items():
        setattr(checkpoint, field, value)
    await db.commit()
    await db.refresh(checkpoint)
    return checkpoint


@router.delete(
    "/{checkpoint_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_role("admin"))],
)
async def delete_checkpoint(
    checkpoint_id: int, db: Annotated[AsyncSession, Depends(get_db)]
):
    checkpoint = await db.get(Checkpoint, checkpoint_id)
    if checkpoint is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Checkpoint not found")
    await db.delete(checkpoint)
    await db.commit()


@router.post(
    "/{checkpoint_id}/qr",
    response_model=CheckpointOut,
    dependencies=[Depends(admin_or_staff)],
)
async def generate_qr(checkpoint_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    """Create (or reuse) the QR row for a checkpoint and link it back."""
    checkpoint = await db.get(Checkpoint, checkpoint_id)
    if checkpoint is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Checkpoint not found")

    existing = await db.execute(
        select(QRCode).where(QRCode.checkpoint_id == checkpoint_id)
    )
    qr = existing.scalar_one_or_none()
    if qr is None:
        qr = QRCode(
            checkpoint_id=checkpoint_id,
            payload=payload_for_checkpoint(checkpoint_id),
        )
        db.add(qr)
        await db.flush()
        checkpoint.qr_code_id = qr.id
        await db.commit()
        await db.refresh(checkpoint)
    return checkpoint


@router.get("/{checkpoint_id}/qr.png")
async def download_qr(checkpoint_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(
        select(QRCode).where(QRCode.checkpoint_id == checkpoint_id)
    )
    qr = result.scalar_one_or_none()
    if qr is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "No QR generated for this checkpoint"
        )
    png = render_qr_png(qr.payload)
    return Response(
        content=png,
        media_type="image/png",
        headers={
            "Content-Disposition": f'inline; filename="checkpoint-{checkpoint_id}.png"'
        },
    )
