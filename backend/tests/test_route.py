"""A* pathfinding unit tests over a hand-built graph.

Covers Phase 4 acceptance cases: direct path, no path (disconnected),
same start/end. Uses the service layer directly with a synthetic graph
so it does not depend on seed data.
"""

import networkx as nx
import pytest

from app.models import Checkpoint
from app.services.graph import (
    NoRouteError,
    RouteResult,
    UnknownCheckpointError,
    find_route,
)


def _cp(id_: int, lat: float, lng: float, label: str = "") -> Checkpoint:
    cp = Checkpoint(label=label or f"CP{id_}", lat=lat, lng=lng)
    cp.id = id_
    return cp


def _build():
    # 1 --100m-- 2 --50m-- 3      (chain)
    #  \___________150m__________/ (direct but longer)
    # 4 isolated (no edges)
    checkpoints = {
        1: _cp(1, 9.5000, 76.5000, "Start"),
        2: _cp(2, 9.5010, 76.5000, "Mid"),
        3: _cp(3, 9.5020, 76.5000, "End"),
        4: _cp(4, 9.6000, 76.6000, "Island"),
    }
    g = nx.Graph()
    for cp in checkpoints.values():
        g.add_node(cp.id, lat=cp.lat, lng=cp.lng, label=cp.label)
    g.add_edge(1, 2, distance=100.0, time=71)
    g.add_edge(2, 3, distance=50.0, time=36)
    g.add_edge(1, 3, distance=150.0, time=107)
    return g, checkpoints


def test_direct_shortest_path_picks_lower_weight():
    g, cps = _build()
    result = find_route(g, cps, 1, 3)
    assert isinstance(result, RouteResult)
    # 1->2->3 = 150 total, ties with direct 1->3 = 150; A* returns a valid
    # shortest path either way. Assert total is the minimum.
    assert result.total_distance_meters == 150.0
    assert result.steps[0].checkpoint_id == 1
    assert result.steps[-1].checkpoint_id == 3


def test_shortest_prefers_cheaper_when_direct_is_costlier():
    g, cps = _build()
    # Make the direct edge expensive so the chain must win.
    g[1][3]["distance"] = 500.0
    result = find_route(g, cps, 1, 3)
    assert [s.checkpoint_id for s in result.steps] == [1, 2, 3]
    assert result.total_distance_meters == 150.0
    assert result.total_time_seconds == 107


def test_same_start_and_end_is_zero_length():
    g, cps = _build()
    result = find_route(g, cps, 2, 2)
    assert len(result.steps) == 1
    assert result.steps[0].checkpoint_id == 2
    assert result.total_distance_meters == 0.0
    assert result.total_time_seconds == 0


def test_no_path_disconnected_raises():
    g, cps = _build()
    with pytest.raises(NoRouteError):
        find_route(g, cps, 1, 4)


def test_unknown_checkpoint_raises():
    g, cps = _build()
    with pytest.raises(UnknownCheckpointError):
        find_route(g, cps, 1, 999)


def test_route_endpoint_on_seeded_graph(client):
    """Integration: /route over a small graph created through the API."""
    from sqlalchemy import create_engine, text

    from app.core.security import hash_password

    from .conftest import TEST_URL_SYNC

    engine = create_engine(TEST_URL_SYNC)
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (name, email, password_hash, role) "
                "VALUES ('A', 'route@test.dev', :p, 'admin')"
            ),
            {"p": hash_password("Passw0rd!x")},
        )
    engine.dispose()

    token = client.post(
        "/auth/login", data={"username": "route@test.dev", "password": "Passw0rd!x"}
    ).json()["access_token"]
    auth = {"Authorization": f"Bearer {token}"}

    a = client.post(
        "/checkpoints", json={"label": "A", "lat": 9.5, "lng": 76.5}, headers=auth
    ).json()["id"]
    b = client.post(
        "/checkpoints", json={"label": "B", "lat": 9.501, "lng": 76.5}, headers=auth
    ).json()["id"]
    c = client.post(
        "/checkpoints", json={"label": "C", "lat": 9.502, "lng": 76.5}, headers=auth
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
    client.post(
        "/edges",
        json={
            "checkpoint_a_id": b,
            "checkpoint_b_id": c,
            "distance_meters": 50,
            "walking_time_estimate_sec": 36,
        },
        headers=auth,
    )

    resp = client.get(f"/route?from_id={a}&to_id={c}")
    assert resp.status_code == 200
    body = resp.json()
    assert [s["checkpoint_id"] for s in body["steps"]] == [a, b, c]
    assert body["total_distance_meters"] == 150.0
    assert body["total_time_seconds"] == 107

    # disconnected destination -> 422
    d = client.post(
        "/checkpoints", json={"label": "D", "lat": 9.9, "lng": 76.9}, headers=auth
    ).json()["id"]
    assert client.get(f"/route?from_id={a}&to_id={d}").status_code == 422

    # unknown checkpoint -> 404
    assert client.get(f"/route?from_id={a}&to_id=999999").status_code == 404
