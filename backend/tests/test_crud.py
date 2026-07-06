from sqlalchemy import create_engine, text

from app.core.security import hash_password
from app.models import RoomType

from .conftest import TEST_URL_SYNC

ADMIN_EMAIL = "cruadmin@test.dev"
STAFF_EMAIL = "crustaff@test.dev"
PASSWORD = "Passw0rd!x"


def _seed_user(email: str, role: str) -> None:
    engine = create_engine(TEST_URL_SYNC)
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (name, email, password_hash, role) "
                "VALUES (:n, :e, :p, :r)"
            ),
            {"n": role, "e": email, "p": hash_password(PASSWORD), "r": role},
        )
    engine.dispose()


def _token(client, email: str) -> str:
    return client.post(
        "/auth/login", data={"username": email, "password": PASSWORD}
    ).json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_building_crud_lifecycle(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)

    created = client.post(
        "/buildings",
        json={"name": "Block A", "lat": 9.5, "lng": 76.5},
        headers=_auth(token),
    )
    assert created.status_code == 201
    bid = created.json()["id"]

    assert client.get("/buildings").status_code == 200

    patched = client.patch(
        f"/buildings/{bid}",
        json={"description": "Updated"},
        headers=_auth(token),
    )
    assert patched.status_code == 200
    assert patched.json()["description"] == "Updated"

    assert client.delete(f"/buildings/{bid}", headers=_auth(token)).status_code == 204
    assert client.get(f"/buildings/{bid}").status_code == 404


def test_building_duplicate_name_conflict(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)
    payload = {"name": "Dup Block", "lat": 9.5, "lng": 76.5}
    assert (
        client.post("/buildings", json=payload, headers=_auth(token)).status_code == 201
    )
    assert (
        client.post("/buildings", json=payload, headers=_auth(token)).status_code == 409
    )


def test_create_building_requires_auth(client):
    resp = client.post("/buildings", json={"name": "NoAuth", "lat": 1, "lng": 1})
    assert resp.status_code == 401


def test_staff_can_create_but_not_delete_building(client):
    _seed_user(STAFF_EMAIL, "staff")
    token = _token(client, STAFF_EMAIL)
    created = client.post(
        "/buildings",
        json={"name": "Staff Block", "lat": 9.5, "lng": 76.5},
        headers=_auth(token),
    )
    assert created.status_code == 201
    bid = created.json()["id"]
    # delete is admin-only
    assert client.delete(f"/buildings/{bid}", headers=_auth(token)).status_code == 403


def test_delete_building_with_checkpoint_blocked(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)
    bid = client.post(
        "/buildings",
        json={"name": "Occupied", "lat": 9.5, "lng": 76.5},
        headers=_auth(token),
    ).json()["id"]
    client.post(
        "/checkpoints",
        json={"label": "CP", "lat": 9.5, "lng": 76.5, "building_id": bid},
        headers=_auth(token),
    )
    # ON DELETE RESTRICT -> 409
    assert client.delete(f"/buildings/{bid}", headers=_auth(token)).status_code == 409


def test_room_requires_valid_building(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)
    resp = client.post(
        "/rooms",
        json={
            "name": "Ghost Room",
            "type": RoomType.lab.value,
            "floor": 1,
            "building_id": 999999,
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422


def test_edge_crud_and_dedupe(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)
    a = client.post(
        "/checkpoints",
        json={"label": "A", "lat": 1, "lng": 1},
        headers=_auth(token),
    ).json()["id"]
    b = client.post(
        "/checkpoints",
        json={"label": "B", "lat": 2, "lng": 2},
        headers=_auth(token),
    ).json()["id"]

    created = client.post(
        "/edges",
        json={
            "checkpoint_a_id": a,
            "checkpoint_b_id": b,
            "distance_meters": 50,
            "walking_time_estimate_sec": 36,
        },
        headers=_auth(token),
    )
    assert created.status_code == 201

    # reversed endpoints = same undirected edge -> 409
    dupe = client.post(
        "/edges",
        json={
            "checkpoint_a_id": b,
            "checkpoint_b_id": a,
            "distance_meters": 50,
            "walking_time_estimate_sec": 36,
        },
        headers=_auth(token),
    )
    assert dupe.status_code == 409


def test_edge_self_loop_rejected(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)
    a = client.post(
        "/checkpoints",
        json={"label": "Solo", "lat": 1, "lng": 1},
        headers=_auth(token),
    ).json()["id"]
    resp = client.post(
        "/edges",
        json={
            "checkpoint_a_id": a,
            "checkpoint_b_id": a,
            "distance_meters": 10,
            "walking_time_estimate_sec": 8,
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422


def test_qr_generation_and_png(client):
    _seed_user(ADMIN_EMAIL, "admin")
    token = _token(client, ADMIN_EMAIL)
    cp = client.post(
        "/checkpoints",
        json={"label": "QR CP", "lat": 1, "lng": 1},
        headers=_auth(token),
    ).json()["id"]

    gen = client.post(f"/checkpoints/{cp}/qr", headers=_auth(token))
    assert gen.status_code == 200
    assert gen.json()["qr_code_id"] is not None

    png = client.get(f"/checkpoints/{cp}/qr.png")
    assert png.status_code == 200
    assert png.headers["content-type"] == "image/png"
    assert png.content[:8] == b"\x89PNG\r\n\x1a\n"
