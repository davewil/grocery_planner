"""
Middleware for request tracing, structured logging, and tenant validation.
"""

import time
import uuid
import json
import logging
from typing import Callable
from contextvars import ContextVar

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

# Optional OpenTelemetry trace context
try:
    from opentelemetry import trace as otel_trace
    _otel_available = True
except ImportError:
    _otel_available = False

# Context variables for request-scoped data
request_id_var: ContextVar[str] = ContextVar("request_id", default="")
tenant_id_var: ContextVar[str] = ContextVar("tenant_id", default="")


class StructuredLogger(logging.Formatter):
    """
    JSON formatter for structured logging.

    Outputs logs as JSON objects with consistent fields for parsing
    by log aggregation systems.
    """

    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add request context if available
        if request_id := request_id_var.get():
            log_data["request_id"] = request_id
        if tenant_id := tenant_id_var.get():
            log_data["tenant_id"] = tenant_id

        # Add OpenTelemetry trace context if available
        if _otel_available:
            span = otel_trace.get_current_span()
            ctx = span.get_span_context() if span else None
            if ctx and ctx.is_valid:
                log_data["trace_id"] = format(ctx.trace_id, "032x")
                log_data["span_id"] = format(ctx.span_id, "016x")

        # Add extra fields from the log record
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id
        if hasattr(record, "tenant_id"):
            log_data["tenant_id"] = record.tenant_id
        if hasattr(record, "feature"):
            log_data["feature"] = record.feature
        if hasattr(record, "status"):
            log_data["status"] = record.status
        if hasattr(record, "latency_ms"):
            log_data["latency_ms"] = record.latency_ms
        if hasattr(record, "job_id"):
            log_data["job_id"] = record.job_id
        if hasattr(record, "artifact_id"):
            log_data["artifact_id"] = record.artifact_id

        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data)


def setup_structured_logging(level: int = logging.INFO) -> None:
    """
    Configure structured JSON logging for the application.

    Args:
        level: Logging level (default: INFO)
    """
    handler = logging.StreamHandler()
    handler.setFormatter(StructuredLogger())

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    root_logger.handlers = [handler]

    # Configure specific loggers
    for logger_name in ["grocery-planner-ai", "grocery-planner-ai.jobs", "grocery-planner-ai.artifacts"]:
        logger = logging.getLogger(logger_name)
        logger.setLevel(level)
        logger.handlers = [handler]
        logger.propagate = False


class RequestTracingMiddleware(BaseHTTPMiddleware):
    """
    Middleware for request tracing and logging.

    - Generates or propagates request IDs
    - Logs request/response with timing
    - Stores request context for downstream use
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Get or generate request ID
        request_id = request.headers.get("X-Request-ID", f"req_{uuid.uuid4().hex[:16]}")
        request_id_var.set(request_id)

        # Extract tenant ID from headers or body (will be set properly in API handlers)
        tenant_id = request.headers.get("X-Tenant-ID", "")
        tenant_id_var.set(tenant_id)

        # Store in request state for handler access
        request.state.request_id = request_id
        request.state.tenant_id = tenant_id

        logger = logging.getLogger("grocery-planner-ai")
        start_time = time.time()

        # Log request
        logger.info(
            f"Request started: {request.method} {request.url.path}",
            extra={
                "request_id": request_id,
                "tenant_id": tenant_id,
                "method": request.method,
                "path": request.url.path,
            }
        )

        try:
            response = await call_next(request)
            latency_ms = (time.time() - start_time) * 1000

            # Log response
            logger.info(
                f"Request completed: {request.method} {request.url.path}",
                extra={
                    "request_id": request_id,
                    "tenant_id": tenant_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "latency_ms": round(latency_ms, 2),
                }
            )

            # Add request ID to response headers
            response.headers["X-Request-ID"] = request_id

            return response

        except Exception as e:
            latency_ms = (time.time() - start_time) * 1000
            logger.exception(
                f"Request failed: {request.method} {request.url.path}",
                extra={
                    "request_id": request_id,
                    "tenant_id": tenant_id,
                    "method": request.method,
                    "path": request.url.path,
                    "latency_ms": round(latency_ms, 2),
                    "error": str(e),
                }
            )
            raise


class TenantValidationMiddleware(BaseHTTPMiddleware):
    """
    Middleware to validate tenant context on API requests.

    Ensures that all AI API calls include valid tenant information.
    """

    # Paths that don't require tenant validation
    EXEMPT_PATHS = {"/health", "/docs", "/openapi.json", "/redoc"}

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Skip validation for exempt paths
        if request.url.path in self.EXEMPT_PATHS:
            return await call_next(request)

        # Skip validation for non-API paths
        if not request.url.path.startswith("/api/"):
            return await call_next(request)

        # For POST requests, tenant_id should be in the body (handled by Pydantic)
        # For GET requests to jobs/artifacts, tenant_id should be in headers
        if request.method == "GET":
            tenant_id = request.headers.get("X-Tenant-ID")
            if not tenant_id:
                return Response(
                    content=json.dumps({
                        "error": "Missing X-Tenant-ID header",
                        "detail": "Tenant context is required for all API requests"
                    }),
                    status_code=400,
                    media_type="application/json"
                )
            tenant_id_var.set(tenant_id)
            request.state.tenant_id = tenant_id

        return await call_next(request)
