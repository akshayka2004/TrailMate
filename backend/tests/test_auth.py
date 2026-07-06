from typing import Annotated

from fastapi import Depends
from sqlalchemy import create_engine, text

from app.core.deps import require_role
from app.core.security import hash_password
from app.main import app
from app.models import User

from .conftest import TEST_URL_SYNC

ADMIN_EMAIL = "admin@test.dev"
ADMIN_PASSWORD = "Admin@12345"


@app.get("/_test/admin-only")
async def _admin_only(
    user: Annotated[User, Depends(require_role("admin"))],
) -> dict[str, str]:
    return {"hello": user.email}


def _create_admin() -> None:
    """Insert an admin directly (register endpoint only creates students)."""
    engine = create_engine(TEST_URL_SYNC)
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (name, email, password_hash, role) "
                "VALUES (:n, :e, :p, 'admin')"
            ),
            {"n": "Test Admin", "e": ADMIN_EMAIL, "p": hash_password(ADMIN_PASSWORD)},
        )
    engine.dispose()


def test_register_creates_student(client):
    resp = client.post(
        "/auth/register",
        json={"name": "Stu Dent", "email": "stu@test.dev", "password": "Passw0rd!x"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["email"] == "stu@test.dev"
    assert body["role"] == "student"
    assert "password" not in body


def test_register_duplicate_email_conflict(client):
    payload = {"name": "Stu", "email": "dup@test.dev", "password": "Passw0rd!x"}
    assert client.post("/auth/register", json=payload).status_code == 201
    assert client.post("/auth/register", json=payload).status_code == 409


def test_login_and_me(client):
    client.post(
        "/auth/register",
        json={"name": "Stu", "email": "login@test.dev", "password": "Passw0rd!x"},
    )
    resp = client.post(
        "/auth/login",
        data={"username": "login@test.dev", "password": "Passw0rd!x"},
    )
    assert resp.status_code == 200
    tokens = resp.json()
    assert tokens["token_type"] == "bearer"

    me = client.get(
        "/auth/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    assert me.status_code == 200
    assert me.json()["email"] == "login@test.dev"


def test_login_wrong_password_401(client):
    client.post(
        "/auth/register",
        json={"name": "Stu", "email": "wrong@test.dev", "password": "Passw0rd!x"},
    )
    resp = client.post(
        "/auth/login",
        data={"username": "wrong@test.dev", "password": "nope-nope-nope"},
    )
    assert resp.status_code == 401


def test_refresh_rotates_tokens(client):
    client.post(
        "/auth/register",
        json={"name": "Stu", "email": "ref@test.dev", "password": "Passw0rd!x"},
    )
    tokens = client.post(
        "/auth/login",
        data={"username": "ref@test.dev", "password": "Passw0rd!x"},
    ).json()

    resp = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert resp.status_code == 200
    assert "access_token" in resp.json()


def test_refresh_rejects_access_token(client):
    client.post(
        "/auth/register",
        json={"name": "Stu", "email": "ref2@test.dev", "password": "Passw0rd!x"},
    )
    tokens = client.post(
        "/auth/login",
        data={"username": "ref2@test.dev", "password": "Passw0rd!x"},
    ).json()

    resp = client.post("/auth/refresh", json={"refresh_token": tokens["access_token"]})
    assert resp.status_code == 401


def test_refresh_garbage_token_401(client):
    resp = client.post("/auth/refresh", json={"refresh_token": "garbage.token.here"})
    assert resp.status_code == 401


def test_rbac_admin_allowed(client):
    _create_admin()
    tokens = client.post(
        "/auth/login",
        data={"username": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    ).json()
    resp = client.get(
        "/_test/admin-only",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"hello": ADMIN_EMAIL}


def test_rbac_student_forbidden(client):
    client.post(
        "/auth/register",
        json={"name": "Stu", "email": "rbac@test.dev", "password": "Passw0rd!x"},
    )
    tokens = client.post(
        "/auth/login",
        data={"username": "rbac@test.dev", "password": "Passw0rd!x"},
    ).json()
    resp = client.get(
        "/_test/admin-only",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert resp.status_code == 403


def test_rbac_no_token_401(client):
    assert client.get("/_test/admin-only").status_code == 401
