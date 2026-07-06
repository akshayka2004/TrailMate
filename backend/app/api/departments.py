from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.db.session import get_db
from app.models import Building, Department
from app.schemas.department import (
    DepartmentCreate,
    DepartmentOut,
    DepartmentUpdate,
)

router = APIRouter(prefix="/departments", tags=["departments"])

admin_or_staff = require_role("admin", "staff")


async def _require_building(db: AsyncSession, building_id: int) -> None:
    if await db.get(Building, building_id) is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Unknown building_id")


@router.get("", response_model=list[DepartmentOut])
async def list_departments(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Department).order_by(Department.name))
    return result.scalars().all()


@router.post(
    "",
    response_model=DepartmentOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(admin_or_staff)],
)
async def create_department(
    body: DepartmentCreate, db: Annotated[AsyncSession, Depends(get_db)]
):
    await _require_building(db, body.building_id)
    department = Department(**body.model_dump())
    db.add(department)
    await db.commit()
    await db.refresh(department)
    return department


@router.patch(
    "/{department_id}",
    response_model=DepartmentOut,
    dependencies=[Depends(admin_or_staff)],
)
async def update_department(
    department_id: int,
    body: DepartmentUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    department = await db.get(Department, department_id)
    if department is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Department not found")
    data = body.model_dump(exclude_unset=True)
    if "building_id" in data:
        await _require_building(db, data["building_id"])
    for field, value in data.items():
        setattr(department, field, value)
    await db.commit()
    await db.refresh(department)
    return department


@router.delete(
    "/{department_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_role("admin"))],
)
async def delete_department(
    department_id: int, db: Annotated[AsyncSession, Depends(get_db)]
):
    department = await db.get(Department, department_id)
    if department is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Department not found")
    await db.delete(department)
    await db.commit()
