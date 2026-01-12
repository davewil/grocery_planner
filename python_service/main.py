"""
GroceryPlanner AI Service

FastAPI application providing AI capabilities for the GroceryPlanner application.
Features include categorization, receipt extraction, embeddings, and more.
"""

import time
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from schemas import (
    BaseRequest, BaseResponse,
    CategorizationRequestPayload, CategorizationResponsePayload,
    ExtractionRequestPayload, ExtractionResponsePayload, ExtractedItem,
    EmbeddingRequestPayload, EmbeddingResponsePayload,
    JobSubmitRequest, JobStatusResponse, JobListResponse,
    ArtifactResponse, ArtifactListResponse,
    FeedbackRequest, FeedbackResponse,
)
from database import init_db, get_db, JobStatus
from jobs import submit_job, get_job, list_jobs, job_to_dict, register_job_handler
from artifacts import (
    create_artifact, get_artifact, list_artifacts, artifact_to_dict,
    add_feedback, feedback_to_dict
)
from middleware import (
    setup_structured_logging,
    RequestTracingMiddleware,
    TenantValidationMiddleware,
    request_id_var,
)
from config import settings
import logging

# Setup structured logging
setup_structured_logging()
logger = logging.getLogger("grocery-planner-ai")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Initialize database
    logger.info("Initializing database...")
    init_db()

    # Load models here (e.g. BERT, LayoutLM) when implementing real inference
    logger.info("AI Service starting up...")

    yield

    # Cleanup
    logger.info("AI Service shutting down...")


app = FastAPI(
    title="GroceryPlanner AI Service",
    description="AI capabilities for the GroceryPlanner application",
    version="1.0.0",
    lifespan=lifespan,
)

# Add middleware (order matters - first added is outermost)
app.add_middleware(TenantValidationMiddleware)
app.add_middleware(RequestTracingMiddleware)


# =============================================================================
# Health Check
# =============================================================================

@app.get("/health")
def health_check():
    """Health check endpoint for load balancers and monitoring."""
    return {"status": "ok", "service": "grocery-planner-ai", "version": "1.0.0"}


# =============================================================================
# Synchronous AI Endpoints (with artifact storage)
# =============================================================================

@app.post("/api/v1/categorize", response_model=BaseResponse)
async def categorize_item(request: BaseRequest, db: Session = Depends(get_db)):
    """
    Predicts the category for a given grocery item name.

    Uses zero-shot classification to match items to categories.
    """
    start_time = time.time()
    model_id = "mock-classifier"
    model_version = "1.0.0"

    try:
        payload = CategorizationRequestPayload(**request.payload)

        # MOCK IMPLEMENTATION
        # In real impl: self.classifier(payload.item_name, payload.candidate_labels)
        predicted_category = "Produce"
        confidence = 0.95

        item_lower = payload.item_name.lower()
        if "milk" in item_lower:
            predicted_category = "Dairy"
        elif "bread" in item_lower:
            predicted_category = "Bakery"
        elif "chicken" in item_lower:
            predicted_category = "Meat"

        response_payload = CategorizationResponsePayload(
            category=predicted_category,
            confidence=confidence
        )

        latency_ms = (time.time() - start_time) * 1000

        # Store artifact
        create_artifact(
            db=db,
            request_id=request.request_id,
            tenant_id=request.tenant_id,
            user_id=request.user_id,
            feature="categorization",
            input_payload=request.payload,
            output_payload=response_payload.model_dump(),
            status="success",
            model_id=model_id,
            model_version=model_version,
            latency_ms=latency_ms,
        )

        return BaseResponse(
            request_id=request.request_id,
            payload=response_payload.model_dump()
        )

    except Exception as e:
        latency_ms = (time.time() - start_time) * 1000
        logger.error(f"Error processing request {request.request_id}: {str(e)}")

        # Store error artifact
        create_artifact(
            db=db,
            request_id=request.request_id,
            tenant_id=request.tenant_id,
            user_id=request.user_id,
            feature="categorization",
            input_payload=request.payload,
            status="error",
            error_message=str(e),
            model_id=model_id,
            model_version=model_version,
            latency_ms=latency_ms,
        )

        return BaseResponse(
            request_id=request.request_id,
            status="error",
            payload={},
            error=str(e)
        )


@app.post("/api/v1/extract-receipt", response_model=BaseResponse)
async def extract_receipt_endpoint(request: BaseRequest, db: Session = Depends(get_db)):
    """
    Extracts items from a receipt image.

    Uses OCR and layout analysis to identify line items, prices, and totals.
    When USE_VLLM_OCR=true, uses vLLM-served VLM for real OCR.
    Otherwise returns mock data for development.
    """
    start_time = time.time()

    try:
        payload = ExtractionRequestPayload(**request.payload)

        if settings.USE_VLLM_OCR:
            # Real OCR via vLLM
            from ocr_service import extract_receipt

            model_id = settings.VLLM_MODEL
            model_version = "vllm"

            # Get image data
            if payload.image_base64:
                image_b64 = payload.image_base64
            elif payload.image_url:
                # Fetch image from URL
                import httpx
                async with httpx.AsyncClient() as client:
                    resp = await client.get(payload.image_url)
                    import base64
                    image_b64 = base64.b64encode(resp.content).decode()
            else:
                raise ValueError("Either image_base64 or image_url required")

            result = await extract_receipt(image_b64)

            response_payload = ExtractionResponsePayload(
                items=[ExtractedItem(**item) for item in result["items"]],
                total=result["total"],
                merchant=result["merchant"],
                date=result["date"]
            )
        else:
            # MOCK IMPLEMENTATION for development
            model_id = "mock-ocr"
            model_version = "1.0.0"

            mock_items = [
                ExtractedItem(name="Bananas", quantity=1.0, unit="bunch", price=1.99, confidence=0.98),
                ExtractedItem(name="Milk", quantity=1.0, unit="gallon", price=3.49, confidence=0.95)
            ]

            response_payload = ExtractionResponsePayload(
                items=mock_items,
                total=5.48,
                merchant="Mock Supermarket",
                date="2024-01-01"
            )

        latency_ms = (time.time() - start_time) * 1000

        # Store artifact
        create_artifact(
            db=db,
            request_id=request.request_id,
            tenant_id=request.tenant_id,
            user_id=request.user_id,
            feature="receipt_extraction",
            input_payload=request.payload,
            output_payload=response_payload.model_dump(),
            status="success",
            model_id=model_id,
            model_version=model_version,
            latency_ms=latency_ms,
        )

        return BaseResponse(
            request_id=request.request_id,
            payload=response_payload.model_dump()
        )

    except Exception as e:
        latency_ms = (time.time() - start_time) * 1000
        logger.error(f"Error extracting receipt {request.request_id}: {str(e)}")

        create_artifact(
            db=db,
            request_id=request.request_id,
            tenant_id=request.tenant_id,
            user_id=request.user_id,
            feature="receipt_extraction",
            input_payload=request.payload,
            status="error",
            error_message=str(e),
            model_id="mock-ocr" if not settings.USE_VLLM_OCR else settings.VLLM_MODEL,
            model_version="1.0.0" if not settings.USE_VLLM_OCR else "vllm",
            latency_ms=latency_ms,
        )

        return BaseResponse(
            request_id=request.request_id,
            status="error",
            payload={},
            error=str(e)
        )


@app.post("/api/v1/embed", response_model=BaseResponse)
async def generate_embedding(request: BaseRequest, db: Session = Depends(get_db)):
    """
    Generates a vector embedding for the given text.

    Uses sentence transformers to create semantic embeddings for search.
    """
    start_time = time.time()
    model_id = "mock-embedder"
    model_version = "1.0.0"

    try:
        _ = EmbeddingRequestPayload(**request.payload)

        # MOCK IMPLEMENTATION (384 dimensions for MiniLM)
        mock_vector = [0.1] * 384

        response_payload = EmbeddingResponsePayload(vector=mock_vector)

        latency_ms = (time.time() - start_time) * 1000

        # Store artifact (note: we don't store the full vector to save space)
        create_artifact(
            db=db,
            request_id=request.request_id,
            tenant_id=request.tenant_id,
            user_id=request.user_id,
            feature="embedding",
            input_payload=request.payload,
            output_payload={"vector_dim": len(mock_vector)},  # Just store dimensions
            status="success",
            model_id=model_id,
            model_version=model_version,
            latency_ms=latency_ms,
        )

        return BaseResponse(
            request_id=request.request_id,
            payload=response_payload.model_dump()
        )

    except Exception as e:
        latency_ms = (time.time() - start_time) * 1000
        logger.error(f"Error generating embedding {request.request_id}: {str(e)}")

        create_artifact(
            db=db,
            request_id=request.request_id,
            tenant_id=request.tenant_id,
            user_id=request.user_id,
            feature="embedding",
            input_payload=request.payload,
            status="error",
            error_message=str(e),
            model_id=model_id,
            model_version=model_version,
            latency_ms=latency_ms,
        )

        return BaseResponse(
            request_id=request.request_id,
            status="error",
            payload={},
            error=str(e)
        )


# =============================================================================
# Job Management Endpoints
# =============================================================================

@app.post("/api/v1/jobs", response_model=JobStatusResponse)
async def submit_async_job(request: JobSubmitRequest, db: Session = Depends(get_db)):
    """
    Submit a job for background processing.

    Returns immediately with a job ID that can be polled for status.
    """
    job = submit_job(
        db=db,
        tenant_id=request.tenant_id,
        user_id=request.user_id,
        feature=request.feature,
        input_payload=request.payload,
        model_id=request.model_id,
        model_version=request.model_version,
    )

    return JobStatusResponse(
        job_id=job.id,
        status=job.status.value,
        feature=job.feature,
        created_at=job.created_at.isoformat(),
    )


@app.get("/api/v1/jobs/{job_id}", response_model=JobStatusResponse)
async def get_job_status(
    job_id: str,
    tenant_id: str = Query(..., description="Tenant ID for access control"),
    db: Session = Depends(get_db)
):
    """
    Get the status of a background job.

    Returns full job details including output if completed.
    """
    job = get_job(db, job_id, tenant_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    return JobStatusResponse(**job_to_dict(job))


@app.get("/api/v1/jobs", response_model=JobListResponse)
async def list_tenant_jobs(
    tenant_id: str = Query(..., description="Tenant ID for access control"),
    feature: Optional[str] = Query(None, description="Filter by feature"),
    status: Optional[str] = Query(None, description="Filter by status"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """
    List jobs for a tenant.

    Supports filtering by feature and status with pagination.
    """
    status_enum = JobStatus(status) if status else None
    jobs = list_jobs(db, tenant_id, feature=feature, status=status_enum, limit=limit, offset=offset)

    return JobListResponse(
        jobs=[job_to_dict(job) for job in jobs],
        total=len(jobs),
        limit=limit,
        offset=offset,
    )


# =============================================================================
# Artifact Endpoints
# =============================================================================

@app.get("/api/v1/artifacts/{artifact_id}", response_model=ArtifactResponse)
async def get_artifact_details(
    artifact_id: str,
    tenant_id: str = Query(..., description="Tenant ID for access control"),
    db: Session = Depends(get_db)
):
    """
    Get details of an AI artifact.

    Returns full artifact including input/output payloads.
    """
    artifact = get_artifact(db, artifact_id, tenant_id)
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")

    return ArtifactResponse(**artifact_to_dict(artifact))


@app.get("/api/v1/artifacts", response_model=ArtifactListResponse)
async def list_tenant_artifacts(
    tenant_id: str = Query(..., description="Tenant ID for access control"),
    feature: Optional[str] = Query(None, description="Filter by feature"),
    status: Optional[str] = Query(None, description="Filter by status"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """
    List artifacts for a tenant.

    Supports filtering by feature and status with pagination.
    """
    artifacts = list_artifacts(db, tenant_id, feature=feature, status=status, limit=limit, offset=offset)

    return ArtifactListResponse(
        artifacts=[artifact_to_dict(a) for a in artifacts],
        total=len(artifacts),
        limit=limit,
        offset=offset,
    )


# =============================================================================
# Feedback Endpoints
# =============================================================================

@app.post("/api/v1/feedback", response_model=FeedbackResponse)
async def submit_feedback(request: FeedbackRequest, db: Session = Depends(get_db)):
    """
    Submit feedback for an AI operation.

    Accepts thumbs up/down ratings with optional notes.
    """
    feedback = add_feedback(
        db=db,
        tenant_id=request.tenant_id,
        user_id=request.user_id,
        rating=request.rating,
        note=request.note,
        artifact_id=request.artifact_id,
        job_id=request.job_id,
    )

    return FeedbackResponse(**feedback_to_dict(feedback))


# =============================================================================
# Register Job Handlers
# =============================================================================

@register_job_handler("receipt_extraction")
async def handle_receipt_extraction(input_payload: dict) -> dict:
    """Background handler for receipt extraction jobs."""
    if settings.USE_VLLM_OCR:
        from ocr_service import extract_receipt

        image_b64 = input_payload.get("image_base64")
        if not image_b64:
            raise ValueError("image_base64 required in payload")

        return await extract_receipt(image_b64)
    else:
        # MOCK IMPLEMENTATION for development
        return {
            "items": [
                {"name": "Bananas", "quantity": 1.0, "unit": "bunch", "price": 1.99, "confidence": 0.98},
                {"name": "Milk", "quantity": 1.0, "unit": "gallon", "price": 3.49, "confidence": 0.95}
            ],
            "total": 5.48,
            "merchant": "Mock Supermarket",
            "date": "2024-01-01"
        }


@register_job_handler("embedding_batch")
async def handle_embedding_batch(input_payload: dict) -> dict:
    """Background handler for batch embedding jobs."""
    texts = input_payload.get("texts", [])
    # MOCK IMPLEMENTATION
    return {
        "vectors": [[0.1] * 384 for _ in texts],
        "count": len(texts)
    }
