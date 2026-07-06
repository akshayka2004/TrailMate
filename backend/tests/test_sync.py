from sqlalchemy import create_engine, text

from app.core.security import hash_password

from .conftest import TEST_URL_SYNC

PASSWORD = "Passw0rd!x"


def _admin_token(client) -> str:
    engine = create_engine(TEST_URL_SYNC)
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (name, email, password_hash, role) "
                "VALUES ('A', 'sync@test.dev', :p, 'admin')"
            ),
            {"p": hash_password(PASSWORD)},
        )
    engine.dispose()
    return client.post(
        "/auth/login", data={"username": "sync@test.dev", "password": PASSWORD}
    ).json()["access_token"]


def _seed_minimal(client, token: str) -> None:
    auth = {"Authorization": f"Bearer {token}"}
    bid = client.post(
        "/buildings", json={"name": "B", "lat": 9.5, "lng": 76.5}, headers=auth
    ).json()["id"]
    a = client.post(
        "/checkpoints",
        json={"label": "A", "lat": 9.5, "lng": 76.5, "building_id": bid},
        headers=auth,
    ).json()["id"]
    b = client.post(
        "/checkpoints", json={"label": "B", "lat": 9.501, "lng": 76.5}, headers=auth
    ).json()["id"]
    client.post(
        "/edges",
        json={
            "checkpoint_a_id": a,
            "checkpoint_b_id": b,
            "distance_meters": 100,
            "walking_time_estimate_sec": 71,
        },
        headers=auth,
    )


def test_snapshot_starts_at_version_zero(client):
    resp = client.get("/sync/snapshot")
    assert resp.status_code == 200
    body = resp.json()
    assert body["version"] == 0
    assert body["generated_at"] is None
    assert set(body["graph"].keys()) == {
        "buildings",
        "departments",
        "rooms",
        "checkpoints",
        "edges",
    }


def test_snapshot_contains_full_graph(client):
    token = _admin_token(client)
    _seed_minimal(client, token)
    body = client.get("/sync/snapshot").json()
    assert len(body["graph"]["buildings"]) == 1
    assert len(body["graph"]["checkpoints"]) == 2
    assert len(body["graph"]["edges"]) == 1


def test_publish_increments_version(client):
    token = _admin_token(client)
    auth = {"Authorization": f"Bearer {token}"}

    first = client.post("/sync/snapshot", headers=auth)
    assert first.status_code == 201
    assert first.json()["version"] == 1

    second = client.post("/sync/snapshot", headers=auth)
    assert second.json()["version"] == 2

    # GET now reflects the latest published version.
    assert client.get("/sync/snapshot").json()["version"] == 2


def test_publish_requires_auth(client):
    assert client.post("/sync/snapshot").status_code == 401
