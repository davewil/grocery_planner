from fastapi import FastAPI
from contextlib import asynccontextmanager
from schemas import (
    BaseRequest, BaseResponse,
    CategorizationRequestPayload, CategorizationResponsePayload,
    ExtractionRequestPayload, ExtractionResponsePayload, ExtractedItem,
    EmbeddingRequestPayload, EmbeddingResponsePayload
)
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("grocery-planner-ai")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load models here (e.g. BERT, LayoutLM)
    logger.info("Loading models...")
    yield
    # Clean up models
    logger.info("Shutting down...")

app = FastAPI(title="GroceryPlanner AI Service", lifespan=lifespan)

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "grocery-planner-ai"}

@app.post("/api/v1/categorize", response_model=BaseResponse)
async def categorize_item(request: BaseRequest):
    """
    Predicts the category for a given grocery item name.
    """
    try:
        # Validate payload structure
        payload = CategorizationRequestPayload(**request.payload)

        # MOCK IMPLEMENTATION
        # In real impl, we would use self.classifier(payload.item_name, payload.candidate_labels)

        predicted_category = "Produce" # Default mock
        confidence = 0.95

        # Simple deterministic mock logic for testing
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
        
        return BaseResponse(
            request_id=request.request_id,
            payload=response_payload.model_dump()
        )

    except Exception as e:
        logger.error(f"Error processing request {request.request_id}: {str(e)}")
        return BaseResponse(
            request_id=request.request_id,
            status="error",
            payload={},
            error=str(e)
        )

@app.post("/api/v1/extract-receipt", response_model=BaseResponse)
async def extract_receipt(request: BaseRequest):
    """
    Extracts items from a receipt image.
    """
    try:
        # Validate payload structure
        _ = ExtractionRequestPayload(**request.payload)

        # MOCK IMPLEMENTATION
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
        
        return BaseResponse(
            request_id=request.request_id,
            payload=response_payload.model_dump()
        )
        
    except Exception as e:
        logger.error(f"Error extracting receipt {request.request_id}: {str(e)}")
        return BaseResponse(
            request_id=request.request_id,
            status="error",
            payload={},
            error=str(e)
        )

@app.post("/api/v1/embed", response_model=BaseResponse)
async def generate_embedding(request: BaseRequest):
    """
    Generates a vector embedding for the given text.
    """
    try:
        # Validate payload structure
        _ = EmbeddingRequestPayload(**request.payload)

        # MOCK IMPLEMENTATION (384 dimensions for MiniLM)
        mock_vector = [0.1] * 384 
        
        response_payload = EmbeddingResponsePayload(
            vector=mock_vector
        )
        
        return BaseResponse(
            request_id=request.request_id,
            payload=response_payload.model_dump()
        )
        
    except Exception as e:
        logger.error(f"Error generating embedding {request.request_id}: {str(e)}")
        return BaseResponse(
            request_id=request.request_id,
            status="error",
            payload={},
            error=str(e)
        )