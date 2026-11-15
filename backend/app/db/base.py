"""
AirGuard AI - SQLAlchemy Base & Session Management
"""
from sqlalchemy import create_engine
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


def get_db():
    """Dependency injection helper for database sessions."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
