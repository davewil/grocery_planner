from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any, Union

# --- Base Schemas ---

class BaseRequest(BaseModel):
    request_id: str
    tenant_id: str
    user_id: str
    feature: str
    payload: Dict[str, Any]
    metadata: Optional[Dict[str, Any]] = {}

class BaseResponse(BaseModel):
    request_id: str
    status: str = "success" # success, error
    payload: Dict[str, Any]
    error: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = {}

# --- Feature: Smart Categorization ---

class CategorizationRequestPayload(BaseModel):
    item_name: str
    candidate_labels: List[str]

class CategorizationResponsePayload(BaseModel):
    category: str
    confidence: float

# --- Feature: Receipt Extraction ---

class ExtractionRequestPayload(BaseModel):
    image_url: Optional[str] = None
    image_base64: Optional[str] = None

class ExtractedItem(BaseModel):
    name: str
    quantity: float
    unit: Optional[str] = None
    price: Optional[float] = None
    confidence: float

class ExtractionResponsePayload(BaseModel):
    items: List[ExtractedItem]
    total: Optional[float] = None
    merchant: Optional[str] = None
    date: Optional[str] = None

# --- Feature: Semantic Search ---

class EmbeddingRequestPayload(BaseModel):
    text: str

class EmbeddingResponsePayload(BaseModel):
    vector: List[float]
