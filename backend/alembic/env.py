import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool
from sqlalchemy import text

from alembic import context

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Alembic runs synchronously; swap the async driver for psycopg2.
_database_url = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://trailmate:trailmate@localhost:5432/trailmate",
).replace("+asyncpg", "+psycopg2")
config.set_main_option("sqlalchemy.url", _database_url)

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# add your model's MetaData object here
# for 'autogenerate' support
import app.models  # noqa: E402, F401  (registers all models on Base.metadata)
from app.db.base import Base  # noqa: E402

target_metadata = Base.metadata


def include_object(object, name, type_, reflected, compare_to):
    # Never touch tables that exist in the DB but not in our models
    # (PostGIS/tiger geocoder ships spatial_ref_sys and friends).
    if type_ == "table" and reflected and name not in target_metadata.tables:
        return False
    return True


# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.

    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        # postgis/postgis image puts tiger geocoder schemas on the search_path;
        # tiger.edges would collide with our public.edges during autogenerate.
        connection.execute(text("SET search_path TO public"))
        # Commit ends the implicit transaction so alembic manages its own;
        # SET search_path is session-scoped and survives the commit.
        connection.commit()
        connection.dialect.default_schema_name = "public"
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_object=include_object,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
