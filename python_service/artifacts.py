"""
Artifact service for storing AI request/response data.

Provides persistence of AI operations for debugging, evaluation, and audit.
"""

import json
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from database import AIArtifact, AIFeedback
import logging

logger = logging.getLogger("grocery-planner-ai.artifacts")


def generate_artifact_id() -> str:
    """Generate a unique artifact ID."""
    return f"art_{uuid.uuid4().hex[:16]}"


def generate_feedback_id() -> str:
    """Generate a unique feedback ID."""
    return f"fb_{uuid.uuid4().hex[:16]}"


def create_artifact(
    db: Session,
    request_id: str,
    tenant_id: str,
    user_id: str,
    feature: str,
    input_payload: dict,
    output_payload: Optional[dict] = None,
    status: str = "success",
    error_message: Optional[str] = None,
    model_id: Optional[str] = None,
    model_version: Optional[str] = None,
    latency_ms: Optional[float] = None,
    cost: Optional[float] = None,
    job_id: Optional[str] = None,
) -> AIArtifact:
    """
    Create an artifact record for an AI operation.

    Args:
        db: Database session
        request_id: Original request ID from caller
        tenant_id: Tenant ID for scoping
        user_id: User who made the request
        feature: Feature name
        input_payload: Input data
        output_payload: Output data (if successful)
        status: Operation status ("success" or "error")
        error_message: Error message (if failed)
        model_id: Model identifier used
        model_version: Model version used
        latency_ms: Operation latency
        cost: Operation cost
        job_id: Associated job ID (for async operations)

    Returns:
        Created AIArtifact instance
    """
    artifact = AIArtifact(
        id=generate_artifact_id(),
        request_id=request_id,
        tenant_id=tenant_id,
        user_id=user_id,
        feature=feature,
        input_payload=json.dumps(input_payload),
        output_payload=json.dumps(output_payload) if output_payload else None,
        status=status,
        error_message=error_message,
        model_id=model_id,
        model_version=model_version,
        latency_ms=latency_ms,
        cost=cost,
        job_id=job_id,
        created_at=datetime.utcnow(),
    )
    db.add(artifact)
    db.commit()
    db.refresh(artifact)

    logger.info(
        "Artifact created",
        extra={
            "artifact_id": artifact.id,
            "request_id": request_id,
            "tenant_id": tenant_id,
            "feature": feature,
            "status": status,
            "latency_ms": latency_ms,
        }
    )

    return artifact


def get_artifact(db: Session, artifact_id: str, tenant_id: str) -> Optional[AIArtifact]:
    """
    Get an artifact by ID, scoped to tenant.

    Args:
        db: Database session
        artifact_id: Artifact identifier
        tenant_id: Tenant ID for access control

    Returns:
        AIArtifact if found and belongs to tenant, None otherwise
    """
    return db.query(AIArtifact).filter(
        AIArtifact.id == artifact_id,
        AIArtifact.tenant_id == tenant_id
    ).first()


def get_artifact_by_request_id(db: Session, request_id: str, tenant_id: str) -> Optional[AIArtifact]:
    """
    Get an artifact by request ID, scoped to tenant.

    Args:
        db: Database session
        request_id: Original request ID
        tenant_id: Tenant ID for access control

    Returns:
        AIArtifact if found and belongs to tenant, None otherwise
    """
    return db.query(AIArtifact).filter(
        AIArtifact.request_id == request_id,
        AIArtifact.tenant_id == tenant_id
    ).first()


def list_artifacts(
    db: Session,
    tenant_id: str,
    feature: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
) -> list[AIArtifact]:
    """
    List artifacts for a tenant with optional filtering.

    Args:
        db: Database session
        tenant_id: Tenant ID for scoping
        feature: Optional feature filter
        status: Optional status filter
        limit: Maximum results
        offset: Pagination offset

    Returns:
        List of matching AIArtifact records
    """
    query = db.query(AIArtifact).filter(AIArtifact.tenant_id == tenant_id)

    if feature:
        query = query.filter(AIArtifact.feature == feature)
    if status:
        query = query.filter(AIArtifact.status == status)

    return query.order_by(AIArtifact.created_at.desc()).offset(offset).limit(limit).all()


def add_feedback(
    db: Session,
    tenant_id: str,
    user_id: str,
    rating: str,
    note: Optional[str] = None,
    artifact_id: Optional[str] = None,
    job_id: Optional[str] = None,
) -> AIFeedback:
    """
    Add user feedback for an AI operation.

    Args:
        db: Database session
        tenant_id: Tenant ID
        user_id: User providing feedback
        rating: Rating value ("thumbs_up" or "thumbs_down")
        note: Optional feedback note
        artifact_id: Associated artifact ID
        job_id: Associated job ID

    Returns:
        Created AIFeedback instance
    """
    if not artifact_id and not job_id:
        raise ValueError("Either artifact_id or job_id must be provided")

    feedback = AIFeedback(
        id=generate_feedback_id(),
        tenant_id=tenant_id,
        user_id=user_id,
        rating=rating,
        note=note,
        artifact_id=artifact_id,
        job_id=job_id,
        created_at=datetime.utcnow(),
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)

    logger.info(
        "Feedback added",
        extra={
            "feedback_id": feedback.id,
            "tenant_id": tenant_id,
            "rating": rating,
            "artifact_id": artifact_id,
            "job_id": job_id,
        }
    )

    return feedback


def get_feedback_for_artifact(db: Session, artifact_id: str, tenant_id: str) -> list[AIFeedback]:
    """Get all feedback for an artifact."""
    return db.query(AIFeedback).filter(
        AIFeedback.artifact_id == artifact_id,
        AIFeedback.tenant_id == tenant_id
    ).all()


def artifact_to_dict(artifact: AIArtifact) -> dict:
    """Convert an artifact to a dictionary for API responses."""
    return {
        "id": artifact.id,
        "request_id": artifact.request_id,
        "tenant_id": artifact.tenant_id,
        "user_id": artifact.user_id,
        "feature": artifact.feature,
        "input_payload": json.loads(artifact.input_payload) if artifact.input_payload else None,
        "output_payload": json.loads(artifact.output_payload) if artifact.output_payload else None,
        "status": artifact.status,
        "error_message": artifact.error_message,
        "model_id": artifact.model_id,
        "model_version": artifact.model_version,
        "latency_ms": artifact.latency_ms,
        "cost": artifact.cost,
        "job_id": artifact.job_id,
        "created_at": artifact.created_at.isoformat() if artifact.created_at else None,
    }


def feedback_to_dict(feedback: AIFeedback) -> dict:
    """Convert feedback to a dictionary for API responses."""
    return {
        "id": feedback.id,
        "tenant_id": feedback.tenant_id,
        "user_id": feedback.user_id,
        "rating": feedback.rating,
        "note": feedback.note,
        "artifact_id": feedback.artifact_id,
        "job_id": feedback.job_id,
        "created_at": feedback.created_at.isoformat() if feedback.created_at else None,
    }
