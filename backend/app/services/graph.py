"""Navigation graph builder + A* pathfinding over Checkpoints/Edges."""

import math
from dataclasses import dataclass

import networkx as nx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Checkpoint, Edge


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


def _haversine_m(a: Checkpoint, b: Checkpoint) -> float:
    r = 6371000.0
    p1, p2 = math.radians(a.lat), math.radians(b.lat)
    dphi = math.radians(b.lat - a.lat)
    dlmb = math.radians(b.lng - a.lng)
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


async def build_graph(db: AsyncSession) -> tuple[nx.Graph, dict[int, Checkpoint]]:
    """Load all checkpoints/edges into an undirected weighted NetworkX graph.

    Edge weight = distance_meters. Each node stores lat/lng/label so the A*
    heuristic can use straight-line distance.
    """
    cp_rows = (await db.execute(select(Checkpoint))).scalars().all()
    edge_rows = (await db.execute(select(Edge))).scalars().all()

    checkpoints = {cp.id: cp for cp in cp_rows}
    graph: nx.Graph = nx.Graph()
    for cp in cp_rows:
        graph.add_node(cp.id, lat=cp.lat, lng=cp.lng, label=cp.label)
    for edge in edge_rows:
        graph.add_edge(
            edge.checkpoint_a_id,
            edge.checkpoint_b_id,
            distance=edge.distance_meters,
            time=edge.walking_time_estimate_sec,
        )
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
        )

    def heuristic(u: int, v: int) -> float:
        # Admissible: straight-line distance never overestimates walking cost.
        return _haversine_m(checkpoints[u], checkpoints[v])

    try:
        node_path = nx.astar_path(
            graph, from_id, to_id, heuristic=heuristic, weight="distance"
        )
    except nx.NetworkXNoPath:
        raise NoRouteError
    except nx.NodeNotFound:
        raise UnknownCheckpointError

    steps: list[RouteStep] = []
    total_distance = 0.0
    total_time = 0
    for i, node_id in enumerate(node_path):
        cp = checkpoints[node_id]
        steps.append(RouteStep(cp.id, cp.label, cp.lat, cp.lng))
        if i > 0:
            edge_data = graph.get_edge_data(node_path[i - 1], node_id)
            total_distance += edge_data["distance"]
            total_time += edge_data["time"]

    return RouteResult(
        steps=steps,
        total_distance_meters=round(total_distance, 2),
        total_time_seconds=total_time,
    )
