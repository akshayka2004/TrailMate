# TrailMate - Master Prompt for Claude Code

Paste this whole file as the first message in a new Claude Code session (or save it as `CLAUDE.md` in the repo root so Claude Code auto-loads it every session). It is written to remove ambiguity - Claude Code should not need to guess folder names, commands, or conventions.

---

## 0. How to Use This File

- If working across three repos (backend/web/mobile), copy the relevant sections into a `CLAUDE.md` at the root of each repo, plus keep Sections 1-6 (shared context) in all three.
- If working in one monorepo, put this entire file at the repo root as `CLAUDE.md`.
- Before writing any code, Claude Code should restate the current phase (Section 8) and its acceptance criteria back to the user, then proceed.
- Never skip ahead to a later phase without the current phase's acceptance criteria met.
- Never invent a dependency, folder path, or command not listed here. If something is missing, stop and ask.

---

## 1. Project Context

**TrailMate** - Smart Campus Navigation and Information Management System for Saintgits College of Engineering.

**Problem:** New students, visitors, parents, faculty struggle to locate departments, labs, seminar halls, classrooms, offices on a large campus.

**Solution:** Native mobile app for search/navigation + web admin portal for managing campus data, backed by a shared REST API and database.

**Four pillars - every decision must respect these:**
1. Graph-based pathfinding (A*), not a third-party maps routing API.
2. GPS + QR-code checkpoints for hybrid outdoor/indoor positioning. No BLE beacons, no UWB, no paid indoor-positioning SDKs.
3. Offline-first mobile app - search and navigation must work with zero internet connectivity using locally cached data.
4. Admin-driven map creation - an admin walks the physical campus using a special mode in the mobile app to drop checkpoints and generate QR codes; refinement happens later in the web dashboard.

If any generated code or design contradicts these four pillars, stop and flag it instead of proceeding.

---

## 2. Technology Stack (locked - do not substitute)

| Layer | Technology | Notes |
|---|---|---|
| Mobile app | Flutter (Dart), stable channel | Target Android + iOS |
| Mobile state | Riverpod | Use `riverpod_generator` + code generation |
| Mobile local storage | Hive | Typed adapters, not raw maps |
| Mobile networking | Dio | With interceptors for JWT refresh |
| Mobile maps | flutter_map (Leaflet-based) | Not google_maps_flutter |
| Mobile QR | mobile_scanner | Camera permission handling required |
| Mobile secure storage | flutter_secure_storage | For JWT/refresh tokens only |
| Web admin | React 18 + Vite | TypeScript, not JavaScript |
| Web styling | Tailwind CSS + shadcn/ui | No CSS-in-JS libraries |
| Web maps | react-leaflet | Matches mobile's Leaflet base for consistent tile source |
| Web graph editor | React Flow | For checkpoint/route editing |
| Web forms | React Hook Form + Zod | Zod for schema validation matching backend Pydantic models |
| Web data layer | TanStack Query | Zustand only for local UI state (not server state) |
| Backend | FastAPI (Python 3.11+) | Async endpoints where DB driver supports it |
| ORM | SQLAlchemy 2.0 style (not legacy Query API) | With Alembic for migrations |
| Validation | Pydantic v2 | |
| Auth | JWT (access + refresh) + OAuth2 password flow, RBAC | `python-jose` or `pyjwt`, `passlib[bcrypt]` for hashing |
| Graph engine | NetworkX | A* via `networkx.astar_path` |
| Image processing | Pillow | |
| QR generation | `qrcode` (Python lib) | |
| Database | PostgreSQL 15+ with PostGIS extension | |
| File storage | Supabase Storage | Via REST API, not a heavy SDK unless needed |
| API docs | FastAPI auto-generated Swagger/OpenAPI | Keep at `/docs` |
| Deployment | Docker + Docker Compose, Nginx reverse proxy, Ubuntu VPS (backend+db), Vercel (web) | |
| Version control | Git + GitHub | Conventional commits (see Section 6) |

Do not swap any of the above without asking first and stating the tradeoff.

---

## 3. Repository Structure (exact - create this if it does not exist)

### If monorepo:
```
trailmate/
├── backend/
│   ├── app/
│   │   ├── api/            # route modules, one file per resource
│   │   ├── core/           # config.py, security.py, deps.py
│   │   ├── db/             # session.py, base.py
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic schemas
│   │   ├── services/       # business logic (graph builder, A*, qr gen)
│   │   └── main.py
│   ├── alembic/
│   ├── tests/
│   ├── requirements.txt
│   ├── .env.example
│   └── Dockerfile
├── web/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   ├── lib/            # api client, query client setup
│   │   ├── stores/         # zustand stores
│   │   └── types/
│   ├── .env.example
│   └── package.json
├── mobile/
│   ├── lib/
│   │   ├── data/           # dio client, hive adapters, repositories
│   │   ├── domain/         # models, use-cases
│   │   ├── presentation/   # screens, widgets, riverpod providers
│   │   └── main.dart
│   ├── pubspec.yaml
├── docker-compose.yml
├── CLAUDE.md
└── README.md
```

If a separate-repos setup is chosen instead, use the same internal folder structure inside each repo.

**Rule:** Claude Code must not invent alternate folder names (e.g. `src/` instead of `app/` for backend). If unsure, check this tree first.

---

## 4. Data Model (do not redesign without flagging changes)

- **User**: id, name, email, password_hash, role (`admin` | `staff` | `student`), created_at
- **Building**: id, name, description, image_url, lat, lng, footprint (PostGIS geometry, nullable)
- **Department**: id, name, building_id (FK)
- **Room**: id, name, type (`classroom`|`lab`|`seminar_hall`|`office`), floor, building_id (FK)
- **Checkpoint**: id, label, lat, lng, qr_code_id (FK nullable), building_id (FK nullable - null means outdoor node)
- **Edge**: id, checkpoint_a_id (FK), checkpoint_b_id (FK), distance_meters (float), walking_time_estimate_sec (int), is_indoor (bool)
- **QRCode**: id, checkpoint_id (FK), payload (unique string/hash), image_url
- **Event**: id, title, description, location_id (FK to Building or Room - use polymorphic or nullable dual FK, decide in Phase 1 and document the choice), start_time, end_time, poster_url
- **SyncSnapshot**: id, version (int, incrementing), generated_at, payload_url (points to a JSON blob in Supabase Storage with the full graph + metadata)

Navigation graph = `Checkpoint` nodes + `Edge` weighted edges. A* runs over this. Buildings/Rooms/Departments resolve to their nearest Checkpoint(s) for search-to-route lookups.

**Before writing migrations:** confirm nullable fields, unique constraints (e.g. `email` unique, `qr_code.payload` unique), and cascade rules (e.g. deleting a Building should not silently orphan Checkpoints - decide and document ON DELETE behavior per FK).

---

## 5. Environment & Setup Commands (exact)

### Backend
```bash
cd backend
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env    # fill in DATABASE_URL, JWT_SECRET, SUPABASE_URL, SUPABASE_KEY
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

### Web
```bash
cd web
npm install
cp .env.example .env    # fill in VITE_API_BASE_URL
npm run dev
```

### Mobile
```bash
cd mobile
flutter pub get
flutter run
```

### Database (local dev via Docker)
```bash
docker compose up -d db
```

**Rule:** Claude Code must always check for an existing `.env` before overwriting one, and must never print secret values back into chat or commit `.env` to git (only `.env.example` with placeholder values is committed).

---

## 6. Coding Standards & Git Workflow

- **Python**: PEP8, type hints on every function signature, `black` + `ruff` for formatting/linting, run before every commit.
- **TypeScript**: strict mode on (`"strict": true` in tsconfig), no `any` unless justified with a comment, ESLint + Prettier.
- **Dart**: follow `flutter_lints` defaults, null-safety throughout.
- **Naming**: snake_case for Python/SQL, camelCase for TS/Dart, PascalCase for classes/components/models in all languages.
- **Commits**: Conventional Commits format - `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`. One logical change per commit.
- **Branches**: `feature/<phase-name>-<short-desc>`, `fix/<short-desc>`. Never commit directly to `main`.
- **Tests**: every new backend endpoint gets at least one pytest test (happy path + one failure case). Every new frontend data-fetching hook gets a basic render/mock test. Do not mark a phase complete without passing tests.
- **Secrets**: never hardcode API keys, DB URLs, or JWT secrets in source. Always via `.env` + `os.environ` / `import.meta.env` / `--dart-define`.

---

## 7. Anti-Mistake Checklist (Claude Code must self-check before finishing any task)

Before saying a task is done, confirm:
1. Did I run the relevant tests/linter, not just claim it works?
2. Did I use the exact folder structure from Section 3, not a new one?
3. Did I use the exact tech stack from Section 2, not a substitute?
4. If I touched the DB schema, did I create an Alembic migration (never edit the DB by hand)?
5. Did I avoid destructive operations (DROP, DELETE without WHERE, force-push) without explicit user confirmation?
6. Did I avoid committing secrets or `.env` files?
7. Does this change respect the four pillars in Section 1 (offline-first, graph-based routing, GPS+QR hybrid, admin-walk map creation)?
8. If ambiguous, did I state my assumption out loud instead of silently guessing?
9. Did I keep changes scoped to the current phase (Section 8) instead of jumping ahead?

If any answer is "no" or "unsure," stop and surface it before proceeding.

---

## 8. Build Phases & Acceptance Criteria

Work one phase at a time. Do not start the next phase until acceptance criteria are met and confirmed with the user.

**Phase 0 - Setup**
- Repo structure from Section 3 created.
- Docker Compose brings up PostgreSQL+PostGIS locally.
- FastAPI app boots and `/docs` loads.
- Vite app boots to a blank page with Tailwind working.
- Flutter app boots to a default screen on an emulator.
- ✅ Done when: all four run locally with the commands in Section 5.

**Phase 1 - Data layer**
- SQLAlchemy models for all entities in Section 4.
- Alembic migration applied cleanly from scratch.
- Seed script populates a small sample campus (3-5 buildings, ~15 checkpoints, edges connecting them).
- ✅ Done when: `alembic upgrade head` + seed script leaves a queryable sample dataset.

**Phase 2 - Auth**
- `/auth/register`, `/auth/login`, `/auth/refresh` endpoints.
- Password hashing via passlib/bcrypt.
- RBAC dependency (`require_role("admin")`) usable on any route.
- Login screens wired on web and mobile, storing tokens securely.
- ✅ Done when: an admin user can log in from both web and mobile and receive a valid JWT.

**Phase 3 - Admin CRUD (web)**
- Full CRUD screens for Buildings, Departments, Rooms.
- Checkpoint placement on a map (react-leaflet) with lat/lng capture.
- Route/edge graph editor (React Flow) connecting checkpoints.
- QR code generation + downloadable image per checkpoint.
- ✅ Done when: an admin can create a full mini campus graph entirely through the web UI.

**Phase 4 - Navigation engine (backend)**
- Service that builds a NetworkX graph from DB (Checkpoints + Edges).
- `/route?from_id=&to_id=` endpoint returning ordered checkpoint path + total distance/time via A*.
- Unit tests covering: direct path, no path (disconnected graph), same start/end.
- ✅ Done when: hitting `/route` with two seeded checkpoint IDs returns a correct shortest path.

**Phase 5 - Mobile navigation**
- Search screen for buildings/rooms/departments.
- Map screen rendering the returned route as a polyline over flutter_map.
- Live GPS tracking with nearest-checkpoint snapping.
- QR scan flow to confirm/correct current checkpoint.
- ✅ Done when: a user can search a room, see a route, and walk it with position updating on the map.

**Phase 6 - Offline support**
- `/sync/snapshot` endpoint returns full graph + metadata as JSON, versioned.
- Hive schema mirrors the snapshot; mobile caches it on first successful sync.
- Search and route calculation fall back to the cached graph when offline (client-side A* or cached precomputed routes - decide and document which).
- Background sync re-pulls snapshot when connectivity returns and version has incremented.
- ✅ Done when: airplane mode does not break search or navigation for previously-synced data.

**Phase 7 - Admin walk mode (mobile)**
- Special mobile flow: admin drops a checkpoint at current GPS location, generates a QR code for it, prints/displays it, and can immediately scan it to confirm placement.
- Pushes new checkpoints to backend in real time or in a batch at the end of the walk.
- ✅ Done when: an admin can build a new section of campus graph purely by walking with the app, with no manual lat/lng entry required.

**Phase 8 - Polish & deployment**
- Dockerfile for backend, docker-compose for full local stack.
- Nginx config for reverse proxy + HTTPS (Let's Encrypt) on the VPS.
- Web deployed to Vercel with correct env vars.
- Supabase Storage wired for building images, QR images, event posters.
- Postman collection exported and committed to `backend/docs/`.
- ✅ Done when: a fresh visitor can hit the deployed web portal and a released mobile build can hit the deployed API successfully end to end.

---

## 9. Sample `.env.example` Files

### backend/.env.example
```
DATABASE_URL=postgresql+asyncpg://trailmate:trailmate@localhost:5432/trailmate
JWT_SECRET=change_me
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
SUPABASE_URL=
SUPABASE_KEY=
```

### web/.env.example
```
VITE_API_BASE_URL=http://localhost:8000
```

---

## 10. First Message to Send Claude Code

Once this file is saved as `CLAUDE.md`, start the actual session with something like:

> "Read CLAUDE.md. Confirm you understand the four pillars, the stack, and the repo structure. Then start Phase 0 and stop once the acceptance criteria are met so I can review before Phase 1."
