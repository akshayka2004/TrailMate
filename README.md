# TrailMate

Smart Campus Navigation and Information Management System for Saintgits College of Engineering.

Monorepo:

- `backend/` — FastAPI + SQLAlchemy 2.0 + PostgreSQL/PostGIS. Navigation graph + A* via NetworkX.
- `web/` — React 18 + Vite + TypeScript + Tailwind. Admin portal.
- `mobile/` — Flutter app. Offline-first search + navigation.
- `design-system/` — Persisted UI design system (MASTER.md is source of truth).

## Local setup

### Database

```bash
docker compose up -d db
```

### Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows (source venv/bin/activate on Unix)
pip install -r requirements.txt
copy .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

Swagger docs: http://localhost:8000/docs

### Web

```bash
cd web
npm install
copy .env.example .env
npm run dev
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

See `CLAUDE.md` for full project rules, data model, and build phases.
