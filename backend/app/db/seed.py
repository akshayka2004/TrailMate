"""Seed a small sample campus (Saintgits-like) for development.

Idempotent: wipes existing rows first, then inserts fresh data.

Run from backend/:  python -m app.db.seed
"""

import asyncio

from passlib.context import CryptContext
from sqlalchemy import delete, func, select

from app.db.session import SessionLocal
from app.models import (
    Building,
    Checkpoint,
    Department,
    Edge,
    Event,
    QRCode,
    Room,
    RoomType,
    SyncSnapshot,
    User,
    UserRole,
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

WALK_SPEED_M_PER_S = 1.4


def _edge(a: Checkpoint, b: Checkpoint, meters: float, indoor: bool = False) -> Edge:
    return Edge(
        checkpoint_a_id=a.id,
        checkpoint_b_id=b.id,
        distance_meters=meters,
        walking_time_estimate_sec=int(meters / WALK_SPEED_M_PER_S),
        is_indoor=indoor,
    )


async def seed() -> None:
    async with SessionLocal() as db:
        # Wipe in FK-safe order (checkpoints before buildings: RESTRICT).
        for model in (
            Edge,
            QRCode,
            Event,
            Checkpoint,
            Room,
            Department,
            Building,
            User,
            SyncSnapshot,
        ):
            await db.execute(delete(model))

        # --- Buildings (coords around Saintgits, Kottayam) ---
        admin_block = Building(
            name="Admin Block",
            description="Administration, principal's office, accounts.",
            lat=9.5133,
            lng=76.5421,
        )
        cs_block = Building(
            name="CS Block",
            description="Computer Science & Engineering department.",
            lat=9.5138,
            lng=76.5428,
        )
        mech_block = Building(
            name="Mechanical Block",
            description="Mechanical Engineering department and workshops.",
            lat=9.5127,
            lng=76.5432,
        )
        library = Building(
            name="Central Library",
            description="Library and reading halls.",
            lat=9.5136,
            lng=76.5415,
        )
        db.add_all([admin_block, cs_block, mech_block, library])
        await db.flush()

        # --- Departments ---
        db.add_all(
            [
                Department(
                    name="Computer Science & Engineering", building_id=cs_block.id
                ),
                Department(name="Mechanical Engineering", building_id=mech_block.id),
                Department(name="Administration", building_id=admin_block.id),
            ]
        )

        # --- Rooms ---
        seminar_hall = Room(
            name="CS Seminar Hall",
            type=RoomType.seminar_hall,
            floor=2,
            building_id=cs_block.id,
        )
        db.add_all(
            [
                Room(
                    name="CS-101",
                    type=RoomType.classroom,
                    floor=1,
                    building_id=cs_block.id,
                ),
                Room(
                    name="Programming Lab 1",
                    type=RoomType.lab,
                    floor=1,
                    building_id=cs_block.id,
                ),
                seminar_hall,
                Room(
                    name="Principal's Office",
                    type=RoomType.office,
                    floor=1,
                    building_id=admin_block.id,
                ),
                Room(
                    name="CAD Lab",
                    type=RoomType.lab,
                    floor=1,
                    building_id=mech_block.id,
                ),
                Room(
                    name="Reading Hall",
                    type=RoomType.classroom,
                    floor=1,
                    building_id=library.id,
                ),
            ]
        )
        await db.flush()

        # --- Checkpoints: outdoor spine (building_id NULL) + entrances/indoor ---
        gate = Checkpoint(label="Main Gate", lat=9.5125, lng=76.5410)
        junction_a = Checkpoint(label="Junction A (flagpole)", lat=9.5130, lng=76.5416)
        junction_b = Checkpoint(
            label="Junction B (canteen turn)", lat=9.5132, lng=76.5425
        )
        junction_c = Checkpoint(
            label="Junction C (workshop road)", lat=9.5128, lng=76.5430
        )
        parking = Checkpoint(label="Parking Lot", lat=9.5123, lng=76.5414)

        admin_entrance = Checkpoint(
            label="Admin Block Entrance",
            lat=9.5133,
            lng=76.5420,
            building_id=admin_block.id,
        )
        admin_lobby = Checkpoint(
            label="Admin Lobby", lat=9.51335, lng=76.5422, building_id=admin_block.id
        )
        cs_entrance = Checkpoint(
            label="CS Block Entrance", lat=9.5137, lng=76.5427, building_id=cs_block.id
        )
        cs_stair_g = Checkpoint(
            label="CS Stairwell (Ground)",
            lat=9.5138,
            lng=76.5429,
            building_id=cs_block.id,
        )
        cs_floor2 = Checkpoint(
            label="CS Floor 2 Corridor",
            lat=9.51382,
            lng=76.54292,
            building_id=cs_block.id,
        )
        mech_entrance = Checkpoint(
            label="Mechanical Block Entrance",
            lat=9.5127,
            lng=76.5431,
            building_id=mech_block.id,
        )
        mech_workshop = Checkpoint(
            label="Workshop Bay", lat=9.5126, lng=76.5433, building_id=mech_block.id
        )
        lib_entrance = Checkpoint(
            label="Library Entrance", lat=9.5135, lng=76.5416, building_id=library.id
        )
        lib_hall = Checkpoint(
            label="Reading Hall Door", lat=9.5136, lng=76.5414, building_id=library.id
        )
        canteen = Checkpoint(label="Canteen", lat=9.5134, lng=76.5424)

        checkpoints = [
            gate,
            junction_a,
            junction_b,
            junction_c,
            parking,
            admin_entrance,
            admin_lobby,
            cs_entrance,
            cs_stair_g,
            cs_floor2,
            mech_entrance,
            mech_workshop,
            lib_entrance,
            lib_hall,
            canteen,
        ]
        db.add_all(checkpoints)
        await db.flush()

        # --- Edges (undirected; one row per pair) ---
        db.add_all(
            [
                _edge(gate, junction_a, 85),
                _edge(gate, parking, 60),
                _edge(junction_a, junction_b, 100),
                _edge(junction_b, junction_c, 70),
                _edge(junction_a, lib_entrance, 55),
                _edge(junction_a, admin_entrance, 50),
                _edge(junction_b, cs_entrance, 45),
                _edge(junction_b, canteen, 30),
                _edge(junction_c, mech_entrance, 25),
                _edge(admin_entrance, admin_lobby, 15, indoor=True),
                _edge(cs_entrance, cs_stair_g, 20, indoor=True),
                _edge(cs_stair_g, cs_floor2, 12, indoor=True),
                _edge(mech_entrance, mech_workshop, 30, indoor=True),
                _edge(lib_entrance, lib_hall, 18, indoor=True),
                _edge(canteen, cs_entrance, 40),
                _edge(parking, junction_a, 70),
            ]
        )

        # --- QR codes for key checkpoints, back-linked ---
        for cp in (gate, cs_entrance, lib_entrance, mech_entrance, admin_entrance):
            qr = QRCode(checkpoint_id=cp.id, payload=f"TRAILMATE:CP:{cp.id}")
            db.add(qr)
            await db.flush()
            cp.qr_code_id = qr.id

        # --- Users ---
        db.add_all(
            [
                User(
                    name="TrailMate Admin",
                    email="admin@trailmate.dev",
                    password_hash=pwd_context.hash("Admin@123"),
                    role=UserRole.admin,
                ),
                User(
                    name="Staff Member",
                    email="staff@trailmate.dev",
                    password_hash=pwd_context.hash("Staff@123"),
                    role=UserRole.staff,
                ),
                User(
                    name="Sample Student",
                    email="student@trailmate.dev",
                    password_hash=pwd_context.hash("Student@123"),
                    role=UserRole.student,
                ),
            ]
        )

        # --- One sample event (room-located) ---
        db.add(
            Event(
                title="Tech Talk: Graph Pathfinding",
                description="Intro session on A* and campus navigation.",
                room_id=seminar_hall.id,
                start_time=func.now(),
                end_time=func.now(),
            )
        )

        await db.commit()

        counts = {}
        for model in (
            Building,
            Department,
            Room,
            Checkpoint,
            Edge,
            QRCode,
            User,
            Event,
        ):
            result = await db.execute(select(func.count()).select_from(model))
            counts[model.__tablename__] = result.scalar_one()
        print("Seed complete:", counts)


if __name__ == "__main__":
    asyncio.run(seed())
