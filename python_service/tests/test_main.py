"""
Tests for the GroceryPlanner AI Service.

Covers health check, AI endpoints, job management, artifacts, and feedback.
"""

import os
import pytest
import tempfile
from fastapi.testclient import TestClient
from main import app
from database import Base, get_engine, reset_engine

# Create a temporary database file for tests
_test_db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["AI_DATABASE_URL"] = f"sqlite:///{_test_db_file.name}"


@pytest.fixture(scope="function")
def db_session():
    """Create a fresh database for each test."""
    # Reset to ensure we get a fresh engine
    reset_engine()

    # Create tables
    engine = get_engine()
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    yield

    # Cleanup
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db_session):
    """Create test client with fresh database."""
    return TestClient(app)


# =============================================================================
# Health Check Tests
# =============================================================================

def test_health_check(client):
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "grocery-planner-ai"
    assert "version" in data


# =============================================================================
# Categorization Tests
# =============================================================================

def test_categorize_item(client):
    """Test item categorization endpoint."""
    payload = {
        "item_name": "Organic Whole Milk",
        "candidate_labels": ["Produce", "Dairy", "Meat"]
    }
    request_data = {
        "request_id": "req_123",
        "tenant_id": "tenant_abc",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": payload
    }

    response = client.post("/api/v1/categorize", json=request_data)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["payload"]["category"] == "Dairy"
    assert data["payload"]["confidence"] > 0.9


def test_categorize_creates_artifact(client):
    """Test that categorization creates an artifact."""
    request_data = {
        "request_id": "req_artifact_test",
        "tenant_id": "tenant_abc",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Bread", "candidate_labels": ["Produce", "Bakery"]}
    }

    response = client.post("/api/v1/categorize", json=request_data)
    assert response.status_code == 200

    # Check artifact was created
    artifacts_response = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_abc"},
        headers={"X-Tenant-ID": "tenant_abc"}
    )
    assert artifacts_response.status_code == 200
    artifacts = artifacts_response.json()["artifacts"]
    assert len(artifacts) >= 1

    artifact = next((a for a in artifacts if a["request_id"] == "req_artifact_test"), None)
    assert artifact is not None
    assert artifact["feature"] == "categorization"
    assert artifact["status"] == "success"


# =============================================================================
# Receipt Extraction Tests
# =============================================================================

def test_extract_receipt(client):
    """Test receipt extraction endpoint."""
    payload = {
        "image_base64": "fake_base64_string"
    }
    request_data = {
        "request_id": "req_456",
        "tenant_id": "tenant_abc",
        "user_id": "user_1",
        "feature": "extraction",
        "payload": payload
    }

    response = client.post("/api/v1/extract-receipt", json=request_data)
    assert response.status_code == 200
    data = response.json()
    assert len(data["payload"]["items"]) > 0
    assert data["payload"]["total"] == 5.48


# =============================================================================
# Embedding Tests
# =============================================================================

def test_embedding(client):
    """Test embedding generation endpoint."""
    payload = {
        "text": "Spicy Chicken Curry"
    }
    request_data = {
        "request_id": "req_789",
        "tenant_id": "tenant_abc",
        "user_id": "user_1",
        "feature": "embedding",
        "payload": payload
    }

    response = client.post("/api/v1/embed", json=request_data)
    assert response.status_code == 200
    data = response.json()
    vector = data["payload"]["vector"]
    assert len(vector) == 384
    assert isinstance(vector[0], float)


# =============================================================================
# Job Management Tests
# =============================================================================

def test_submit_job(client):
    """Test job submission."""
    request_data = {
        "tenant_id": "tenant_abc",
        "user_id": "user_1",
        "feature": "receipt_extraction",
        "payload": {"image_base64": "test_image"}
    }

    response = client.post("/api/v1/jobs", json=request_data)
    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data or "id" in data
    assert data["status"] in ["queued", "running", "succeeded"]
    assert data["feature"] == "receipt_extraction"


def test_get_job_status(client):
    """Test getting job status."""
    # Submit a job first
    request_data = {
        "tenant_id": "tenant_xyz",
        "user_id": "user_2",
        "feature": "receipt_extraction",
        "payload": {"image_base64": "test"}
    }

    submit_response = client.post("/api/v1/jobs", json=request_data)
    job_id = submit_response.json().get("job_id") or submit_response.json().get("id")

    # Get job status
    response = client.get(
        f"/api/v1/jobs/{job_id}",
        params={"tenant_id": "tenant_xyz"},
        headers={"X-Tenant-ID": "tenant_xyz"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["feature"] == "receipt_extraction"


def test_list_jobs(client):
    """Test listing jobs for a tenant."""
    # Submit a job
    request_data = {
        "tenant_id": "tenant_list",
        "user_id": "user_1",
        "feature": "embedding_batch",
        "payload": {"texts": ["test1", "test2"]}
    }
    client.post("/api/v1/jobs", json=request_data)

    # List jobs
    response = client.get(
        "/api/v1/jobs",
        params={"tenant_id": "tenant_list"},
        headers={"X-Tenant-ID": "tenant_list"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "jobs" in data
    assert data["total"] >= 1


def test_job_tenant_isolation(client):
    """Test that jobs are isolated by tenant."""
    # Submit job for tenant A
    client.post("/api/v1/jobs", json={
        "tenant_id": "tenant_a",
        "user_id": "user_1",
        "feature": "receipt_extraction",
        "payload": {}
    })

    # Submit job for tenant B
    client.post("/api/v1/jobs", json={
        "tenant_id": "tenant_b",
        "user_id": "user_1",
        "feature": "receipt_extraction",
        "payload": {}
    })

    # List jobs for tenant A
    response_a = client.get(
        "/api/v1/jobs",
        params={"tenant_id": "tenant_a"},
        headers={"X-Tenant-ID": "tenant_a"}
    )
    jobs_a = response_a.json()["jobs"]

    # List jobs for tenant B
    response_b = client.get(
        "/api/v1/jobs",
        params={"tenant_id": "tenant_b"},
        headers={"X-Tenant-ID": "tenant_b"}
    )
    jobs_b = response_b.json()["jobs"]

    # Each tenant should only see their own jobs
    assert all(j["tenant_id"] == "tenant_a" for j in jobs_a)
    assert all(j["tenant_id"] == "tenant_b" for j in jobs_b)


# =============================================================================
# Artifact Tests
# =============================================================================

def test_list_artifacts(client):
    """Test listing artifacts for a tenant."""
    # Create an artifact by making an AI request
    client.post("/api/v1/categorize", json={
        "request_id": "req_list_test",
        "tenant_id": "tenant_artifacts",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Apple", "candidate_labels": ["Produce", "Dairy"]}
    })

    # List artifacts
    response = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_artifacts"},
        headers={"X-Tenant-ID": "tenant_artifacts"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1


def test_get_artifact(client):
    """Test getting a specific artifact."""
    # Create an artifact
    client.post("/api/v1/categorize", json={
        "request_id": "req_get_artifact",
        "tenant_id": "tenant_get",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Cheese", "candidate_labels": ["Dairy"]}
    })

    # List to get the artifact ID
    list_response = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_get"},
        headers={"X-Tenant-ID": "tenant_get"}
    )
    artifact_id = list_response.json()["artifacts"][0]["id"]

    # Get specific artifact
    response = client.get(
        f"/api/v1/artifacts/{artifact_id}",
        params={"tenant_id": "tenant_get"},
        headers={"X-Tenant-ID": "tenant_get"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == artifact_id
    assert data["feature"] == "categorization"


def test_artifact_tenant_isolation(client):
    """Test that artifacts are isolated by tenant."""
    # Create artifact for tenant A
    client.post("/api/v1/categorize", json={
        "request_id": "req_tenant_a",
        "tenant_id": "tenant_iso_a",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Milk", "candidate_labels": ["Dairy"]}
    })

    # Create artifact for tenant B
    client.post("/api/v1/categorize", json={
        "request_id": "req_tenant_b",
        "tenant_id": "tenant_iso_b",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Bread", "candidate_labels": ["Bakery"]}
    })

    # Each tenant should only see their own artifacts
    response_a = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_iso_a"},
        headers={"X-Tenant-ID": "tenant_iso_a"}
    )
    response_b = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_iso_b"},
        headers={"X-Tenant-ID": "tenant_iso_b"}
    )

    artifacts_a = response_a.json()["artifacts"]
    artifacts_b = response_b.json()["artifacts"]

    assert all(a["tenant_id"] == "tenant_iso_a" for a in artifacts_a)
    assert all(a["tenant_id"] == "tenant_iso_b" for a in artifacts_b)


# =============================================================================
# Feedback Tests
# =============================================================================

def test_submit_feedback(client):
    """Test feedback submission."""
    # Create an artifact first
    client.post("/api/v1/categorize", json={
        "request_id": "req_feedback",
        "tenant_id": "tenant_feedback",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Chicken", "candidate_labels": ["Meat"]}
    })

    # Get the artifact ID
    list_response = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_feedback"},
        headers={"X-Tenant-ID": "tenant_feedback"}
    )
    artifact_id = list_response.json()["artifacts"][0]["id"]

    # Submit feedback
    response = client.post("/api/v1/feedback", json={
        "tenant_id": "tenant_feedback",
        "user_id": "user_1",
        "rating": "thumbs_up",
        "note": "Great categorization!",
        "artifact_id": artifact_id
    })
    assert response.status_code == 200
    data = response.json()
    assert data["rating"] == "thumbs_up"
    assert data["note"] == "Great categorization!"
    assert data["artifact_id"] == artifact_id


def test_submit_feedback_thumbs_down(client):
    """Test negative feedback submission."""
    # Create an artifact
    client.post("/api/v1/categorize", json={
        "request_id": "req_feedback_down",
        "tenant_id": "tenant_feedback_down",
        "user_id": "user_1",
        "feature": "categorization",
        "payload": {"item_name": "Mystery Item", "candidate_labels": ["Other"]}
    })

    list_response = client.get(
        "/api/v1/artifacts",
        params={"tenant_id": "tenant_feedback_down"},
        headers={"X-Tenant-ID": "tenant_feedback_down"}
    )
    artifact_id = list_response.json()["artifacts"][0]["id"]

    response = client.post("/api/v1/feedback", json={
        "tenant_id": "tenant_feedback_down",
        "user_id": "user_1",
        "rating": "thumbs_down",
        "note": "Wrong category",
        "artifact_id": artifact_id
    })
    assert response.status_code == 200
    assert response.json()["rating"] == "thumbs_down"


# =============================================================================
# Request Tracing Tests
# =============================================================================

def test_request_id_in_response(client):
    """Test that request ID is returned in response headers."""
    response = client.get("/health", headers={"X-Request-ID": "trace_123"})
    assert response.headers.get("X-Request-ID") == "trace_123"


def test_generated_request_id(client):
    """Test that a request ID is generated if not provided."""
    response = client.get("/health")
    request_id = response.headers.get("X-Request-ID")
    assert request_id is not None
    assert request_id.startswith("req_")


# =============================================================================
# Tenant Validation Tests
# =============================================================================

def test_get_endpoint_requires_tenant_header(client):
    """Test that GET endpoints require X-Tenant-ID header."""
    response = client.get("/api/v1/jobs")
    # Should return 400 for missing tenant
    assert response.status_code == 400
    assert "X-Tenant-ID" in response.json()["error"]
