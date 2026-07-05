import app.models  # noqa: F401  (registers all models on Base.metadata)
from app.db.base import Base

EXPECTED_TABLES = {
    "users",
    "buildings",
    "departments",
    "rooms",
    "checkpoints",
    "edges",
    "qrcodes",
    "events",
    "sync_snapshots",
}


def test_all_entities_registered() -> None:
    assert EXPECTED_TABLES == set(Base.metadata.tables.keys())


def test_event_location_check_constraint_present() -> None:
    events = Base.metadata.tables["events"]
    names = {c.name for c in events.constraints}
    assert "ck_event_exactly_one_location" in names


def test_edge_pair_unique() -> None:
    edges = Base.metadata.tables["edges"]
    names = {c.name for c in edges.constraints}
    assert "uq_edge_pair" in names
