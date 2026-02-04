"""
Job service for managing background AI tasks.

Provides job submission, status tracking, and execution management.
"""

import json
import uuid
import asyncio
from datetime import datetime
from typing import Optional, Callable, Awaitable
from concurrent.futures import ThreadPoolExecutor

from sqlalchemy.orm import Session

from database import AIJob, JobStatus, SessionLocal
import logging

logger = logging.getLogger("grocery-planner-ai.jobs")

# Thread pool for background job execution
_executor = ThreadPoolExecutor(max_workers=4)

# Registry of job handlers by feature name
_job_handlers: dict[str, Callable[[dict], Awaitable[dict]]] = {}


def register_job_handler(feature: str):
    """Decorator to register a job handler for a specific feature."""
    def decorator(func: Callable[[dict], Awaitable[dict]]):
        _job_handlers[feature] = func
        return func
    return decorator


def generate_job_id() -> str:
    """Generate a unique job ID."""
    return f"job_{uuid.uuid4().hex[:16]}"


def create_job(
    db: Session,
    job_id: str,
    tenant_id: str,
    user_id: str,
    feature: str,
    input_payload: dict,
    model_id: Optional[str] = None,
    model_version: Optional[str] = None,
) -> AIJob:
    """
    Create a new job record in queued status.

    Args:
        db: Database session
        job_id: Unique job identifier
        tenant_id: Tenant (account) ID for scoping
        user_id: User who submitted the job
        feature: Feature name (e.g., "receipt_extraction")
        input_payload: Input data for the job
        model_id: Optional model identifier
        model_version: Optional model version

    Returns:
        Created AIJob instance
    """
    job = AIJob(
        id=job_id,
        tenant_id=tenant_id,
        user_id=user_id,
        feature=feature,
        status=JobStatus.QUEUED,
        input_payload=json.dumps(input_payload),
        model_id=model_id,
        model_version=model_version,
        created_at=datetime.utcnow(),
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    logger.info(
        "Job created",
        extra={
            "job_id": job_id,
            "tenant_id": tenant_id,
            "feature": feature,
            "status": JobStatus.QUEUED.value,
        }
    )

    return job


def get_job(db: Session, job_id: str, tenant_id: str) -> Optional[AIJob]:
    """
    Get a job by ID, scoped to tenant.

    Args:
        db: Database session
        job_id: Job identifier
        tenant_id: Tenant ID for access control

    Returns:
        AIJob if found and belongs to tenant, None otherwise
    """
    return db.query(AIJob).filter(
        AIJob.id == job_id,
        AIJob.tenant_id == tenant_id
    ).first()


def list_jobs(
    db: Session,
    tenant_id: str,
    feature: Optional[str] = None,
    status: Optional[JobStatus] = None,
    limit: int = 50,
    offset: int = 0,
) -> list[AIJob]:
    """
    List jobs for a tenant with optional filtering.

    Args:
        db: Database session
        tenant_id: Tenant ID for scoping
        feature: Optional feature filter
        status: Optional status filter
        limit: Maximum results
        offset: Pagination offset

    Returns:
        List of matching AIJob records
    """
    query = db.query(AIJob).filter(AIJob.tenant_id == tenant_id)

    if feature:
        query = query.filter(AIJob.feature == feature)
    if status:
        query = query.filter(AIJob.status == status)

    return query.order_by(AIJob.created_at.desc()).offset(offset).limit(limit).all()


def update_job_status(
    db: Session,
    job: AIJob,
    status: JobStatus,
    output_payload: Optional[dict] = None,
    error_message: Optional[str] = None,
    latency_ms: Optional[float] = None,
    cost: Optional[float] = None,
) -> AIJob:
    """
    Update job status and related fields.

    Args:
        db: Database session
        job: Job to update
        status: New status
        output_payload: Optional output data
        error_message: Optional error message (for failed status)
        latency_ms: Optional execution latency
        cost: Optional cost metric

    Returns:
        Updated AIJob instance
    """
    job.status = status

    if status == JobStatus.RUNNING:
        job.started_at = datetime.utcnow()
    elif status in (JobStatus.SUCCEEDED, JobStatus.FAILED):
        job.finished_at = datetime.utcnow()

    if output_payload is not None:
        job.output_payload = json.dumps(output_payload)
    if error_message is not None:
        job.error_message = error_message
    if latency_ms is not None:
        job.latency_ms = latency_ms
    if cost is not None:
        job.cost = cost

    db.commit()
    db.refresh(job)

    logger.info(
        "Job status updated",
        extra={
            "job_id": job.id,
            "tenant_id": job.tenant_id,
            "feature": job.feature,
            "status": status.value,
            "latency_ms": latency_ms,
        }
    )

    return job


async def execute_job(job_id: str, tenant_id: str) -> None:
    """
    Execute a job asynchronously.

    This function runs the appropriate handler for the job's feature
    and updates the job status accordingly.

    Args:
        job_id: Job identifier
        tenant_id: Tenant ID for scoping
    """
    db = SessionLocal()
    try:
        job = get_job(db, job_id, tenant_id)
        if not job:
            logger.error(f"Job not found: {job_id}")
            return

        if job.status != JobStatus.QUEUED:
            logger.warning(f"Job {job_id} is not in queued status: {job.status}")
            return

        # Get the handler for this feature
        handler = _job_handlers.get(job.feature)
        if not handler:
            update_job_status(
                db, job, JobStatus.FAILED,
                error_message=f"No handler registered for feature: {job.feature}"
            )
            return

        # Mark as running
        update_job_status(db, job, JobStatus.RUNNING)
        start_time = datetime.utcnow()

        try:
            # Parse input and execute handler
            input_payload = json.loads(job.input_payload) if job.input_payload else {}
            result = await handler(input_payload)

            # Calculate latency
            latency_ms = (datetime.utcnow() - start_time).total_seconds() * 1000

            # Mark as succeeded
            update_job_status(
                db, job, JobStatus.SUCCEEDED,
                output_payload=result,
                latency_ms=latency_ms,
            )

        except Exception as e:
            latency_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
            logger.exception(f"Job {job_id} failed: {e}")
            update_job_status(
                db, job, JobStatus.FAILED,
                error_message=str(e),
                latency_ms=latency_ms,
            )

    finally:
        db.close()


def submit_job(
    db: Session,
    tenant_id: str,
    user_id: str,
    feature: str,
    input_payload: dict,
    model_id: Optional[str] = None,
    model_version: Optional[str] = None,
) -> AIJob:
    """
    Submit a new job for background execution.

    Creates the job record and schedules it for execution.

    Args:
        db: Database session
        tenant_id: Tenant ID
        user_id: User ID
        feature: Feature name
        input_payload: Input data
        model_id: Optional model identifier
        model_version: Optional model version

    Returns:
        Created AIJob instance
    """
    job_id = generate_job_id()
    job = create_job(
        db=db,
        job_id=job_id,
        tenant_id=tenant_id,
        user_id=user_id,
        feature=feature,
        input_payload=input_payload,
        model_id=model_id,
        model_version=model_version,
    )

    # Schedule job execution
    asyncio.create_task(execute_job(job_id, tenant_id))

    return job


def job_to_dict(job: AIJob) -> dict:
    """Convert a job to a dictionary for API responses."""
    return {
        "id": job.id,
        "tenant_id": job.tenant_id,
        "user_id": job.user_id,
        "feature": job.feature,
        "status": job.status.value if isinstance(job.status, JobStatus) else job.status,
        "input_payload": json.loads(job.input_payload) if job.input_payload else None,
        "output_payload": json.loads(job.output_payload) if job.output_payload else None,
        "error_message": job.error_message,
        "model_id": job.model_id,
        "model_version": job.model_version,
        "created_at": job.created_at.isoformat() if job.created_at else None,
        "started_at": job.started_at.isoformat() if job.started_at else None,
        "finished_at": job.finished_at.isoformat() if job.finished_at else None,
        "latency_ms": job.latency_ms,
        "cost": job.cost,
    }
