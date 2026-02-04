"""
Database module for AI job tracking and artifact storage.

Uses SQLite for simplicity and persistence without requiring additional infrastructure.
"""

import os
from datetime import datetime
from enum import Enum

from sqlalchemy import create_engine, Column, String, Text, Float, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import sessionmaker, relationship, declarative_base

Base = declarative_base()

# Lazy initialization for engine and session
_engine = None
_SessionLocal = None


def get_database_url() -> str:
    """Get database URL from environment or use default."""
    return os.getenv("AI_DATABASE_URL", "sqlite:///./ai_service.db")


def get_engine():
    """Get or create the database engine."""
    global _engine
    if _engine is None:
        database_url = get_database_url()
        connect_args = {"check_same_thread": False} if "sqlite" in database_url else {}
        _engine = create_engine(database_url, connect_args=connect_args)
    return _engine


def get_session_local():
    """Get or create the session factory."""
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=get_engine())
    return _SessionLocal


def reset_engine():
    """Reset the engine for testing purposes."""
    global _engine, _SessionLocal
    _engine = None
    _SessionLocal = None


# For backwards compatibility
@property
def engine():
    return get_engine()


@property
def SessionLocal():
    return get_session_local()


class JobStatus(str, Enum):
    """Status values for AI jobs."""
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class AIJob(Base):
    """
    Tracks background AI jobs.

    Jobs are tenant-scoped and include full status tracking with timestamps.
    """
    __tablename__ = "ai_jobs"

    id = Column(String(64), primary_key=True, index=True)
    tenant_id = Column(String(64), nullable=False, index=True)
    user_id = Column(String(64), nullable=False)
    feature = Column(String(64), nullable=False, index=True)
    status = Column(SQLEnum(JobStatus), default=JobStatus.QUEUED, nullable=False)

    # Input/output storage
    input_payload = Column(Text, nullable=True)  # JSON string
    output_payload = Column(Text, nullable=True)  # JSON string
    error_message = Column(Text, nullable=True)

    # Metadata
    model_id = Column(String(128), nullable=True)
    model_version = Column(String(32), nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    started_at = Column(DateTime, nullable=True)
    finished_at = Column(DateTime, nullable=True)

    # Metrics
    latency_ms = Column(Float, nullable=True)
    cost = Column(Float, nullable=True)

    # Relationships
    artifacts = relationship("AIArtifact", back_populates="job", cascade="all, delete-orphan")
    feedback = relationship("AIFeedback", back_populates="job", cascade="all, delete-orphan")


class AIArtifact(Base):
    """
    Stores AI request/response artifacts for debugging and evaluation.

    Each artifact captures the full context of an AI operation.
    """
    __tablename__ = "ai_artifacts"

    id = Column(String(64), primary_key=True, index=True)
    job_id = Column(String(64), ForeignKey("ai_jobs.id"), nullable=True, index=True)
    request_id = Column(String(64), nullable=False, index=True)
    tenant_id = Column(String(64), nullable=False, index=True)
    user_id = Column(String(64), nullable=False)
    feature = Column(String(64), nullable=False, index=True)

    # Input/output
    input_payload = Column(Text, nullable=False)  # JSON string
    output_payload = Column(Text, nullable=True)  # JSON string

    # Status
    status = Column(String(16), default="success", nullable=False)
    error_message = Column(Text, nullable=True)

    # Metadata
    model_id = Column(String(128), nullable=True)
    model_version = Column(String(32), nullable=True)

    # Timestamps and metrics
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    latency_ms = Column(Float, nullable=True)
    cost = Column(Float, nullable=True)

    # Relationships
    job = relationship("AIJob", back_populates="artifacts")
    feedback = relationship("AIFeedback", back_populates="artifact", cascade="all, delete-orphan")


class AIFeedback(Base):
    """
    User feedback on AI outputs for evaluation and improvement.
    """
    __tablename__ = "ai_feedback"

    id = Column(String(64), primary_key=True, index=True)
    artifact_id = Column(String(64), ForeignKey("ai_artifacts.id"), nullable=True, index=True)
    job_id = Column(String(64), ForeignKey("ai_jobs.id"), nullable=True, index=True)
    tenant_id = Column(String(64), nullable=False, index=True)
    user_id = Column(String(64), nullable=False)

    # Feedback data
    rating = Column(String(16), nullable=False)  # "thumbs_up", "thumbs_down"
    note = Column(Text, nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    artifact = relationship("AIArtifact", back_populates="feedback")
    job = relationship("AIJob", back_populates="feedback")


def init_db():
    """Create all database tables."""
    Base.metadata.create_all(bind=get_engine())


def get_db():
    """Dependency for getting database sessions."""
    session_factory = get_session_local()
    db = session_factory()
    try:
        yield db
    finally:
        db.close()
