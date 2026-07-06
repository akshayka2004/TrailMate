from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.models import Building
from app.schemas.building import BuildingCreate, BuildingOut, BuildingUpdate

router = APIRouter(prefix="/buildings", tags=["buildings"])

admin_or_staff = require_role("admin", "staff")


@router.get("", response_model=list[BuildingOut])
async def list_buildings(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Building).order_by(Building.name))
    return result.scalars().all()


@router.get("/{building_id}", response_model=BuildingOut)
async def get_building(building_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    building = await db.get(Building, building_id)
    if building is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Building not found")
    return building


@router.post(
    "",
    response_model=BuildingOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(admin_or_staff)],
)
async def create_building(
    body: BuildingCreate, db: Annotated[AsyncSession, Depends(get_db)]
):
    building = Building(**body.model_dump())
    db.add(building)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Building name already exists")
    await db.refresh(building)
    return building


@router.patch(
    "/{building_id}",
    response_model=BuildingOut,
    dependencies=[Depends(admin_or_staff)],
)
async def update_building(
    building_id: int,
    body: BuildingUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    building = await db.get(Building, building_id)
    if building is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Building not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(building, field, value)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Building name already exists")
    await db.refresh(building)
    return building


@router.delete(
    "/{building_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_role("admin"))],
)
async def delete_building(
    building_id: int, db: Annotated[AsyncSession, Depends(get_db)]
):
    building = await db.get(Building, building_id)
    if building is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Building not found")
    try:
        await db.delete(building)
        await db.commit()
    except IntegrityError:
        # checkpoints reference this building via ON DELETE RESTRICT.
        await db.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Building still has checkpoints; reassign or delete them first",
        )
