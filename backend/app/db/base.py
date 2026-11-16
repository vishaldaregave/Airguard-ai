"""
AirGuard AI - SQLAlchemy Base & Session Management
"""
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

# For development, default SQLite or PostgreSQL when configured
connect_args = {"check_same_thread": False} if settings.DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    echo=settings.DEBUG and False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def init_db():
    """Initializes and registers all database tables, migrating schema if needed."""
    from app.db import models  # noqa: F401
    Base.metadata.create_all(bind=engine)

    # SQLite schema upgrade helper for newly introduced columns
    try:
        with engine.connect() as conn:
            # Check columns in evaluated_observation_logs
            cols = [r[1] for r in conn.execute(text("PRAGMA table_info(evaluated_observation_logs);")).fetchall()]
            if cols:
                if "status" not in cols:
                    conn.execute(text("ALTER TABLE evaluated_observation_logs ADD COLUMN status VARCHAR(32) DEFAULT 'COMPLETED';"))
                if "revision" not in cols:
                    conn.execute(text("ALTER TABLE evaluated_observation_logs ADD COLUMN revision INTEGER DEFAULT 0;"))
                if "is_correction" not in cols:
                    conn.execute(text("ALTER TABLE evaluated_observation_logs ADD COLUMN is_correction BOOLEAN DEFAULT 0;"))
                conn.commit()
    except Exception:
        pass


def get_db():
    """Dependency injection helper for database sessions."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
