#!/usr/bin/env sh
set -e

# Apply migrations, then start the API. In the container DATABASE_URL points
# at the `db` service host (see docker-compose.yml).
echo "Running database migrations..."
alembic upgrade head

echo "Starting TrailMate API..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
