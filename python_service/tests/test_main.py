from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "grocery-planner-ai"}

def test_categorize_item():
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

def test_extract_receipt():
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

def test_embedding():
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
