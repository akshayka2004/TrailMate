"""Navigation graph builder + A* pathfinding over the campus path network.

The routing graph is built at *waypoint* granularity from two sources:

- Edge.path: legacy per-checkpoint-pair drawn paths (kept for backward
  compatibility with paths already drawn this way — the chain's first/last
  point IS the checkpoint, so it's directly attached).
- PathSegment: free-drawn walkable paths, not tied to any checkpoint pair —
  admin traces the real road/sidewalk network directly.

Every point from both sources becomes its own graph node, connected to its
neighbors in the drawn sequence with a weight equal to the real distance
between them (never a stale stored value). Waypoints from *different*
sources that end up physically close together (paths crossing at a real
intersection) are connected too, and every checkpoint is snapped onto the
nearest nearby network point — this is what lets a route shortcut across
the whole drawn network instead of being forced through whichever
checkpoint-to-checkpoint edges happen to exist. It only ever connects
points an admin actually drew; it never invents new connectivity.
"""

import math
from dataclasses import dataclass

import networkx as nx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Checkpoint, Edge, PathSegment

# Assumed walking pace used to convert a waypoint segment's real distance
# into a time estimate — matches the seed data / edge-creation convention
# elsewhere in the app.
WALK_SPEED_M_PER_S = 1.4

# Two waypoints from *different* drawn paths within this distance of each
# other are treated as the same real-world spot (a path intersection) and
# get connected, enabling a route to cut from one drawn path onto another.
SNAP_THRESHOLD_M = 12.0

# A checkpoint within this distance of a network waypoint is considered to
# be "at" that point on the path — more generous than SNAP_THRESHOLD_M since
# a checkpoint is a user-placed point (e.g. a building entrance) that won't
# always sit exactly on the traced line.
CHECKPOINT_SNAP_THRESHOLD_M = 40.0


class NoRouteError(Exception):
    """No path exists between the two checkpoints."""


class UnknownCheckpointError(Exception):
    """A referenced checkpoint id is not in the graph."""


@dataclass
class RouteStep:
    checkpoint_id: int
    label: str
    lat: float
    lng: float


@dataclass
class RouteResult:
    steps: list[RouteStep]
    total_distance_meters: float
    total_time_seconds: int
    polyline: list[list[float]]


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lng2 - lng1)
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def _source_group(key: str) -> str:
    # "wp:edge:12:3" -> "edge:12", "wp:seg:5:0" -> "seg:5" — waypoints in the
    # same group came from the same drawn line, and are already connected by
    # the chain itself, so cross-shortcut logic skips pairs within a group.
    _, kind, source_id, _ = key.split(":")
    return f"{kind}:{source_id}"


async def build_graph(db: AsyncSession) -> tuple[nx.Graph, dict[int, Checkpoint]]:
    cp_rows = (await db.execute(select(Checkpoint))).scalars().all()
    edge_rows = (await db.execute(select(Edge))).scalars().all()
    segment_rows = (await db.execute(select(PathSegment))).scalars().all()

    checkpoints = {cp.id: cp for cp in cp_rows}
    graph: nx.Graph = nx.Graph()
    for cp in cp_rows:
        graph.add_node(cp.id, lat=cp.lat, lng=cp.lng, label=cp.label)

    def connect(u: str | int, v: str | int) -> None:
        lat1, lng1 = graph.nodes[u]["lat"], graph.nodes[u]["lng"]
        lat2, lng2 = graph.nodes[v]["lat"], graph.nodes[v]["lng"]
        d = _haversine_m(lat1, lng1, lat2, lng2)
        graph.add_edge(u, v, distance=d, time=max(1, round(d / WALK_SPEED_M_PER_S)))

    waypoint_keys: list[str] = []

    for edge in edge_rows:
        if not edge.path:
            # No drawn path — a single straight hop, using the stored
            # (approximate) distance/time rather than recomputing.
            graph.add_edge(
                edge.checkpoint_a_id,
                edge.checkpoint_b_id,
                distance=edge.distance_meters,
                time=edge.walking_time_estimate_sec,
            )
            continue

        chain: list[str | int] = [edge.checkpoint_a_id]
        for i, (lat, lng) in enumerate(edge.path):
            key = f"wp:edge:{edge.id}:{i}"
            graph.add_node(key, lat=lat, lng=lng, label=None)
            waypoint_keys.append(key)
            chain.append(key)
        chain.append(edge.checkpoint_b_id)
        for u, v in zip(chain, chain[1:]):
            connect(u, v)

    for segment in segment_rows:
        chain = []
        for i, (lat, lng) in enumerate(segment.points):
            key = f"wp:seg:{segment.id}:{i}"
            graph.add_node(key, lat=lat, lng=lng, label=None)
            waypoint_keys.append(key)
            chain.append(key)
        for u, v in zip(chain, chain[1:]):
            connect(u, v)

    # Cross-path shortcuts: waypoints from *different* drawn lines within
    # SNAP_THRESHOLD_M of each other represent the same real intersection.
    for i, k1 in enumerate(waypoint_keys):
        group1 = _source_group(k1)
        lat1, lng1 = graph.nodes[k1]["lat"], graph.nodes[k1]["lng"]
        for k2 in waypoint_keys[i + 1 :]:
            if _source_group(k2) == group1 or graph.has_edge(k1, k2):
                continue
            lat2, lng2 = graph.nodes[k2]["lat"], graph.nodes[k2]["lng"]
            d = _haversine_m(lat1, lng1, lat2, lng2)
            if 0 < d <= SNAP_THRESHOLD_M:
                graph.add_edge(k1, k2, distance=d, time=max(1, round(d / WALK_SPEED_M_PER_S)))

    # Snap every checkpoint onto the nearest network waypoint — this is what
    # lets a free-drawn PathSegment (which has no checkpoint of its own)
    # actually serve a checkpoint standing near it, and gives checkpoints
    # that already have a direct edge extra shortcut options too.
    for cp in cp_rows:
        best_key: str | None = None
        best_d = CHECKPOINT_SNAP_THRESHOLD_M
        for key in waypoint_keys:
            d = _haversine_m(cp.lat, cp.lng, graph.nodes[key]["lat"], graph.nodes[key]["lng"])
            if d < best_d:
                best_d = d
                best_key = key
        if best_key is not None and not graph.has_edge(cp.id, best_key):
            connect(cp.id, best_key)

    return graph, checkpoints


def find_route(
    graph: nx.Graph,
    checkpoints: dict[int, Checkpoint],
    from_id: int,
    to_id: int,
) -> RouteResult:
    if from_id not in checkpoints or to_id not in checkpoints:
        raise UnknownCheckpointError

    if from_id == to_id:
        cp = checkpoints[from_id]
        return RouteResult(
            steps=[RouteStep(cp.id, cp.label, cp.lat, cp.lng)],
            total_distance_meters=0.0,
            total_time_seconds=0,
            polyline=[[cp.lat, cp.lng]],
        )

    goal_lat, goal_lng = checkpoints[to_id].lat, checkpoints[to_id].lng

    def heuristic(u: str | int, _v: str | int) -> float:
        # Admissible: straight-line distance never overestimates walking
        # cost. Works for both checkpoint and waypoint nodes since both
        # carry lat/lng graph-node attributes.
        node = graph.nodes[u]
        return _haversine_m(node["lat"], node["lng"], goal_lat, goal_lng)

    try:
        node_path = nx.astar_path(
            graph, from_id, to_id, heuristic=heuristic, weight="distance"
        )
    except nx.NetworkXNoPath:
        raise NoRouteError
    except nx.NodeNotFound:
        raise UnknownCheckpointError

    steps: list[RouteStep] = []
    polyline: list[list[float]] = []
    total_distance = 0.0
    total_time = 0
    for i, node_id in enumerate(node_path):
        node = graph.nodes[node_id]
        polyline.append([node["lat"], node["lng"]])
        if isinstance(node_id, int):
            # Waypoints (string keys) are geometry only — the stop list
            # stays checkpoint-only.
            steps.append(RouteStep(node_id, node["label"], node["lat"], node["lng"]))
        if i > 0:
            edge_data = graph.get_edge_data(node_path[i - 1], node_id)
            total_distance += edge_data["distance"]
            total_time += edge_data["time"]

    return RouteResult(
        steps=steps,
        total_distance_meters=round(total_distance, 2),
        total_time_seconds=total_time,
        polyline=polyline,
    )
