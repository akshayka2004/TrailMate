import psycopg2
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.base import Base
from app.db.session import get_db
from app.main import app

ADMIN_URL = "postgresql://trailmate:trailmate@localhost:5432/postgres"
TEST_DB = "trailmate_test"
TEST_URL_SYNC = f"postgresql+psycopg2://trailmate:trailmate@localhost:5432/{TEST_DB}"
TEST_URL_ASYNC = f"postgresql+asyncpg://trailmate:trailmate@localhost:5432/{TEST_DB}"


@pytest.fixture(scope="session", autouse=True)
def test_database():
    conn = psycopg2.connect(ADMIN_URL)
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS {TEST_DB} WITH (FORCE)")
        cur.execute(f"CREATE DATABASE {TEST_DB}")
    conn.close()

    sync_engine = create_engine(TEST_URL_SYNC)
    with sync_engine.begin() as c:
        c.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
    Base.metadata.create_all(sync_engine)
    sync_engine.dispose()
    yield


@pytest.fixture()
def client(test_database):
    async_engine = create_async_engine(TEST_URL_ASYNC)
    TestSession = async_sessionmaker(async_engine, expire_on_commit=False)

    async def override_get_db():
        async with TestSession() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

    # wipe users between tests via a fresh sync connection
    sync_engine = create_engine(TEST_URL_SYNC)
    with sync_engine.begin() as conn:
        conn.execute(text("TRUNCATE users RESTART IDENTITY CASCADE"))
    sync_engine.dispose()
