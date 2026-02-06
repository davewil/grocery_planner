"""Receipt OCR using Ollama with vision models (llava)."""

import json
import logging
from typing import Optional
import httpx
from config import settings

logger = logging.getLogger("grocery-planner-ai.ollama-ocr")

RECEIPT_PROMPT = """Extract all items from this receipt image.
Return a JSON object with this EXACT structure:
{
  "merchant": "Store Name",
  "date": "YYYY-MM-DD",
  "currency": "GBP",
  "items": [
    {"name": "Item Name", "quantity": 1, "unit": null, "price": 1.99, "confidence": 0.95}
  ],
  "total": 35.20
}

Rules:
- Extract EVERY line item visible on the receipt
- Prices should be numbers only (no currency symbols)
- Use null for unknown units
- Use 1 for unknown quantities
- Date format must be YYYY-MM-DD
- Detect the currency from the receipt (GBP for £, USD for $, EUR for €)
- Include discount/offer lines as separate items with negative prices
- confidence should be 0.0-1.0 based on how clearly you can read the item
- If a field is not visible, use null
- Return ONLY the JSON object, no other text
"""


def extract_receipt_ollama(image_base64: str) -> dict:
    """Extract receipt data using Ollama vision model.

    Args:
        image_base64: Base64-encoded image data (without data URI prefix).

    Returns:
        Dict with keys: items, total, merchant, date, currency.
    """
    url = f"{settings.OLLAMA_BASE_URL}/api/generate"

    logger.info(
        "Calling Ollama for receipt extraction",
        extra={"model": settings.OLLAMA_MODEL, "url": url},
    )

    payload = {
        "model": settings.OLLAMA_MODEL,
        "prompt": RECEIPT_PROMPT,
        "images": [image_base64],
        "stream": False,
    }

    with httpx.Client(timeout=settings.OLLAMA_OCR_TIMEOUT) as client:
        response = client.post(url, json=payload)
        response.raise_for_status()

    data = response.json()
    response_text = data.get("response", "")

    logger.debug("Ollama response", extra={"response_length": len(response_text)})

    return parse_ollama_response(response_text)


def parse_ollama_response(response_text: str) -> dict:
    """Parse Ollama's response into standard format.

    Handles responses that may be wrapped in markdown code blocks.
    """
    text = response_text.strip()

    # Remove markdown code block wrapper if present
    if text.startswith("```"):
        lines = text.split("\n")
        if lines[-1].strip() == "```":
            text = "\n".join(lines[1:-1])
        else:
            text = "\n".join(lines[1:])

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        logger.error(f"Failed to parse Ollama response as JSON: {text[:200]}")
        return {
            "items": [],
            "total": None,
            "merchant": None,
            "date": None,
            "currency": "USD",
        }

    items = []
    for item in data.get("items", []):
        items.append({
            "name": item.get("name", "Unknown"),
            "quantity": item.get("quantity", 1),
            "unit": item.get("unit"),
            "price": item.get("price"),
            "confidence": item.get("confidence", 0.9),
        })

    result = {
        "items": items,
        "total": data.get("total"),
        "merchant": data.get("merchant"),
        "date": data.get("date"),
        "currency": data.get("currency", "USD"),
    }

    logger.info(
        f"Ollama extracted {len(items)} items, "
        f"merchant={result['merchant']}, total={result['total']}"
    )

    return result
