from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.buildings import router as buildings_router
from app.api.checkpoints import router as checkpoints_router
from app.api.departments import router as departments_router
from app.api.edges import router as edges_router
from app.api.rooms import router as rooms_router
from app.api.route import router as route_router
from app.api.sync import router as sync_router

app = FastAPI(title="TrailMate API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    # Dev: web admin (5173) + Flutter web served on any localhost port.
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(buildings_router)
app.include_router(departments_router)
app.include_router(rooms_router)
app.include_router(checkpoints_router)
app.include_router(edges_router)
app.include_router(route_router)
app.include_router(sync_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
