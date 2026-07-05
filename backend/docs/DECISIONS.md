# Schema Decisions (Phase 1)

Decisions required by CLAUDE.md Section 4, documented here.

## Event location: nullable dual FK (not polymorphic)

`events.building_id` and `events.room_id` are both nullable FKs with a CHECK
constraint (`ck_event_exactly_one_location`) enforcing exactly one is set.
Chosen over polymorphic association: simpler joins, DB-enforced integrity, no
ORM magic.

## ON DELETE behavior per FK

| FK | Rule | Reason |
|---|---|---|
| `departments.building_id` | CASCADE | Department cannot exist without its building |
| `rooms.building_id` | CASCADE | Same |
| `checkpoints.building_id` | RESTRICT | Deleting a building must fail loudly while checkpoints reference it — never silently orphan or delete graph nodes. Admin reassigns/deletes checkpoints first |
| `checkpoints.qr_code_id` | SET NULL | Checkpoint survives QR deletion; QR can be regenerated (`use_alter` FK to break the circular reference with `qrcodes`) |
| `edges.checkpoint_a_id` / `checkpoint_b_id` | CASCADE | Edge is meaningless without both endpoints |
| `qrcodes.checkpoint_id` | CASCADE | QR is meaningless without its checkpoint; UNIQUE — one QR per checkpoint |
| `events.building_id` / `room_id` | CASCADE | Event at a deleted location is dead data |

## Unique constraints

- `users.email`
- `buildings.name`
- `qrcodes.payload`, `qrcodes.checkpoint_id`
- `sync_snapshots.version`
- `edges (checkpoint_a_id, checkpoint_b_id)` — `uq_edge_pair`, prevents duplicate
  edges (addition beyond Section 4 spec, flagged here). Edges are undirected;
  the graph builder treats (a,b) as bidirectional, so only one row per pair.

## Types

- Roles / room types: native Postgres enums (`user_role`, `room_type`).
- `buildings.footprint`: PostGIS `geometry(POLYGON, 4326)`, nullable.
- Timestamps: `TIMESTAMPTZ`.
- PKs: integer identity (campus-scale data; no need for UUIDs).
