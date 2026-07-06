# TrailMate Deployment (Phase 8)

## Local full stack (Docker)

Brings up PostGIS + backend (with migrations) + Nginx reverse proxy:

```bash
# from repo root
export JWT_SECRET=$(openssl rand -hex 32)   # or set in a root .env
docker compose up --build
```

- API via Nginx: http://localhost/ (docs at http://localhost/docs)
- API direct: http://localhost:8000
- The backend container runs `alembic upgrade head` on start (see
  `backend/entrypoint.sh`), then serves uvicorn.

Local dev without Docker for the app tier still works — just start the DB:

```bash
docker compose up -d db
```

Seed sample data after the stack is healthy:

```bash
docker compose exec backend python -m app.db.seed
```

## VPS (Ubuntu) — backend + db + nginx

1. Install Docker + Docker Compose plugin.
2. Clone the repo, set a strong `JWT_SECRET` (and `SUPABASE_URL` /
   `SUPABASE_KEY`) in a root `.env` (never commit it).
3. `docker compose up -d --build`.
4. Point DNS A record at the VPS. Then enable HTTPS with Let's Encrypt:

   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d api.trailmate.example.com
   ```

   Certbot rewrites `nginx/nginx.conf`'s server block to add the 443
   listener + certificate and redirect 80 -> 443. (When running Nginx
   inside the compose file, run certbot on the host or mount the certs
   into the nginx container — document whichever the VPS uses.)

## Web (Vercel)

- Import the `web/` directory as a Vite project (`vercel.json` sets the
  build command, output dir, and SPA rewrite).
- Set the `VITE_API_BASE_URL` env var to the deployed API origin
  (see `web/.env.production.example`).

## Supabase Storage

- Create a public bucket `trailmate-public`.
- Set `SUPABASE_URL` and `SUPABASE_KEY` (service role) on the backend.
- `app/services/storage.py` uploads building images / QR PNGs / posters
  via the Storage REST API. When unset, `is_configured()` is False and
  the API serves bytes directly (current default).

## API reference

- Swagger UI: `/docs`, OpenAPI JSON: `/openapi.json`.
- Postman collection: `backend/docs/trailmate.postman_collection.json`
  (run **Login** first — it stores the tokens as collection variables).
