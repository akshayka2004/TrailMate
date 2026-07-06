from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.models import Building, Room
from app.schemas.room import RoomCreate, RoomOut, RoomUpdate

router = APIRouter(prefix="/rooms", tags=["rooms"])

admin_or_staff = require_role("admin", "staff")


async def _require_building(db: AsyncSession, building_id: int) -> None:
    if await db.get(Building, building_id) is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Unknown building_id")


@router.get("", response_model=list[RoomOut])
async def list_rooms(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Room).order_by(Room.name))
    return result.scalars().all()


@router.post(
    "",
    response_model=RoomOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(admin_or_staff)],
)
async def create_room(body: RoomCreate, db: Annotated[AsyncSession, Depends(get_db)]):
    await _require_building(db, body.building_id)
    room = Room(**body.model_dump())
    db.add(room)
    await db.commit()
    await db.refresh(room)
    return room


@router.patch(
    "/{room_id}", response_model=RoomOut, dependencies=[Depends(admin_or_staff)]
)
async def update_room(
    room_id: int,
    body: RoomUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    room = await db.get(Room, room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Room not found")
    data = body.model_dump(exclude_unset=True)
    if "building_id" in data:
        await _require_building(db, data["building_id"])
    for field, value in data.items():
        setattr(room, field, value)
    await db.commit()
    await db.refresh(room)
    return room


@router.delete(
    "/{room_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_role("admin"))],
)
async def delete_room(room_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    room = await db.get(Room, room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Room not found")
    await db.delete(room)
    await db.commit()
