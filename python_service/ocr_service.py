"""
OCR service for extracting text from receipt images using Vision-Language Models.

This module provides integration with vLLM-served VLMs (like Nanonets-OCR-s or Qwen2-VL)
for extracting structured data from receipt images.
"""

import re
import logging
from typing import Optional

from openai import OpenAI

from config import settings

logger = logging.getLogger("grocery-planner-ai.ocr")

# Initialize OpenAI client pointing to vLLM
_client: Optional[OpenAI] = None


def get_client() -> OpenAI:
    """Get or create the OpenAI client for vLLM."""
    global _client
    if _client is None:
        _client = OpenAI(
            base_url=settings.VLLM_BASE_URL,
            api_key="not-needed",  # vLLM doesn't require auth by default
            timeout=settings.OCR_TIMEOUT,
        )
    return _client


RECEIPT_PROMPT = """Extract all items from this receipt image.
Return a markdown table with columns: Item, Quantity, Unit, Price
Also extract: Total, Merchant name, Date (if visible)

Format your response EXACTLY as:
## Items
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Item Name | 1 | each | 1.99 |
...

## Summary
- **Total**: $X.XX
- **Merchant**: Store Name
- **Date**: YYYY-MM-DD

Rules:
- Use "-" for unknown units
- Use "1" for unknown quantities
- Prices should be numbers only (no $ symbol in table)
- Date format must be YYYY-MM-DD
- If a field is not visible, omit it from Summary
"""


def extract_receipt_sync(image_base64: str) -> dict:
    """
    Extract items from receipt image using VLM (synchronous).

    Args:
        image_base64: Base64-encoded image data

    Returns:
        dict with keys: items, total, merchant, date
    """
    client = get_client()

    logger.info(
        "Calling vLLM for receipt extraction",
        extra={"model": settings.VLLM_MODEL, "image_size": len(image_base64)},
    )

    try:
        response = client.chat.completions.create(
            model=settings.VLLM_MODEL,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": RECEIPT_PROMPT},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{image_base64}"
                            },
                        },
                    ],
                }
            ],
            max_tokens=settings.OCR_MAX_TOKENS,
            temperature=0.1,  # Low temp for deterministic extraction
        )

        markdown_output = response.choices[0].message.content
        logger.debug("VLM response received", extra={"response_length": len(markdown_output)})

        return parse_receipt_markdown(markdown_output)

    except Exception as e:
        logger.error(f"vLLM OCR request failed: {e}")
        raise


async def extract_receipt(image_base64: str) -> dict:
    """
    Extract items from receipt image using VLM (async wrapper).

    This is an async wrapper around the sync function for compatibility
    with the existing async API handlers.

    Args:
        image_base64: Base64-encoded image data

    Returns:
        dict with keys: items, total, merchant, date
    """
    # For now, just call sync version
    # Could be made truly async with httpx if needed
    return extract_receipt_sync(image_base64)


def parse_receipt_markdown(markdown: str) -> dict:
    """
    Parse markdown output from VLM into structured data.

    Args:
        markdown: Markdown-formatted string from VLM

    Returns:
        dict with keys: items, total, merchant, date
    """
    items = []
    total = None
    merchant = None
    date = None

    # Process line by line to avoid cross-line matching issues
    for line in markdown.split("\n"):
        line = line.strip()

        # Skip empty lines or lines that don't look like table rows
        if not line or not line.startswith("|"):
            continue

        # Split by pipe and clean up
        parts = [p.strip() for p in line.split("|")]
        # Remove empty strings from start/end (from leading/trailing pipes)
        parts = [p for p in parts if p]

        # Need exactly 4 columns: Item, Quantity, Unit, Price
        if len(parts) != 4:
            continue

        name, qty_str, unit_str, price_str = parts

        # Skip header and separator rows
        if name.lower() in ["item", "---", "-", ""] or name.startswith("-"):
            continue
        if qty_str.lower() in ["quantity", "qty", "---", "-"]:
            continue

        # Parse price - remove $ and try to convert
        price_str = price_str.lstrip("$").strip()
        try:
            parsed_price = float(price_str)
        except ValueError:
            continue  # Skip rows with invalid prices

        # Parse quantity - handle non-numeric gracefully
        try:
            quantity = float(qty_str) if qty_str.replace(".", "").isdigit() else 1.0
        except ValueError:
            quantity = 1.0

        # Parse unit - normalize empty/dash to None
        parsed_unit = unit_str if unit_str not in ["-", "", "each", "ea"] else None

        items.append(
            {
                "name": name,
                "quantity": quantity,
                "unit": parsed_unit,
                "price": parsed_price,
                "confidence": 0.9,  # VLM outputs don't have confidence, assume high
            }
        )

    # Parse summary section
    total_match = re.search(r"\*\*Total\*\*:\s*\$?([\d.]+)", markdown, re.IGNORECASE)
    if total_match:
        try:
            total = float(total_match.group(1))
        except ValueError:
            pass

    merchant_match = re.search(r"\*\*Merchant\*\*:\s*(.+?)(?:\n|$)", markdown, re.IGNORECASE)
    if merchant_match:
        merchant = merchant_match.group(1).strip()
        # Clean up common artifacts
        if merchant.lower() in ["unknown", "n/a", "-"]:
            merchant = None

    date_match = re.search(r"\*\*Date\*\*:\s*(\d{4}-\d{2}-\d{2})", markdown, re.IGNORECASE)
    if date_match:
        date = date_match.group(1)

    logger.info(
        "Parsed receipt",
        extra={
            "item_count": len(items),
            "has_total": total is not None,
            "has_merchant": merchant is not None,
            "has_date": date is not None,
        },
    )

    return {
        "items": items,
        "total": total,
        "merchant": merchant,
        "date": date,
    }
