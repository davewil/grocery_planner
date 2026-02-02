"""
Receipt OCR Processing Module

Handles image preprocessing, OCR text extraction, and receipt parsing
using Tesseract OCR with regex-based extraction (MVP approach).
"""

import re
import logging
from typing import Dict, List, Optional, Tuple
from pathlib import Path

import cv2
import numpy as np
import pytesseract
from PIL import Image

from schemas import (
    ExtractionResult, MerchantInfo, DateInfo, MoneyInfo, LineItem
)

logger = logging.getLogger("grocery-planner-ai")


def preprocess_image(image_path: str) -> np.ndarray:
    """
    Preprocess receipt image for better OCR accuracy.

    Steps:
    1. Load image with PIL
    2. Convert to grayscale
    3. Enhance contrast
    4. Denoise with OpenCV
    5. Deskew if needed
    6. Resize if too large (>4000px)

    Args:
        image_path: Path to the receipt image file

    Returns:
        Preprocessed image as numpy array

    Raises:
        FileNotFoundError: If image file doesn't exist
        ValueError: If image cannot be loaded
    """
    path = Path(image_path)
    if not path.exists():
        raise FileNotFoundError(f"Image file not found: {image_path}")

    try:
        # Load with PIL first for format compatibility
        pil_image = Image.open(image_path)

        # Convert to RGB if needed (handles RGBA, P, etc.)
        if pil_image.mode not in ('RGB', 'L'):
            pil_image = pil_image.convert('RGB')

        # Convert to numpy array for OpenCV processing
        image = np.array(pil_image)

        # Convert to grayscale if not already
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        else:
            gray = image

        # Resize if too large (maintains aspect ratio)
        height, width = gray.shape
        max_dimension = 4000
        if max(height, width) > max_dimension:
            scale = max_dimension / max(height, width)
            new_width = int(width * scale)
            new_height = int(height * scale)
            gray = cv2.resize(gray, (new_width, new_height), interpolation=cv2.INTER_AREA)
            logger.info(f"Resized image from {width}x{height} to {new_width}x{new_height}")

        # Denoise - reduce noise while preserving edges
        denoised = cv2.fastNlMeansDenoising(gray, None, h=10, templateWindowSize=7, searchWindowSize=21)

        # Enhance contrast using CLAHE (Contrast Limited Adaptive Histogram Equalization)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(denoised)

        # Adaptive thresholding for better text extraction
        binary = cv2.adaptiveThreshold(
            enhanced, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )

        logger.info(f"Preprocessed image: {image_path}")
        return binary

    except Exception as e:
        logger.error(f"Failed to preprocess image {image_path}: {e}")
        raise ValueError(f"Cannot load or process image: {e}")


def extract_text(image: np.ndarray) -> str:
    """
    Run Tesseract OCR to extract text from preprocessed image.

    Uses LSTM engine with optimized config for receipt text.

    Args:
        image: Preprocessed image as numpy array

    Returns:
        Raw OCR text output

    Raises:
        RuntimeError: If Tesseract is not installed or fails
    """
    try:
        # Configure Tesseract for receipt-style text
        # PSM 6 = Assume a single uniform block of text
        # OEM 1 = LSTM engine only (more accurate for modern receipts)
        custom_config = r'--oem 1 --psm 6'

        text = pytesseract.image_to_string(image, config=custom_config)

        logger.info(f"Extracted {len(text)} characters via OCR")
        return text

    except pytesseract.TesseractNotFoundError:
        logger.error("Tesseract OCR is not installed or not in PATH")
        raise RuntimeError(
            "Tesseract OCR not found. Please install: apt-get install tesseract-ocr"
        )
    except Exception as e:
        logger.error(f"OCR extraction failed: {e}")
        raise RuntimeError(f"OCR processing failed: {e}")


def parse_receipt(raw_text: str) -> ExtractionResult:
    """
    Parse raw OCR text to extract structured receipt data using regex.

    Extraction patterns:
    - Merchant: First non-empty line (often store name)
    - Date: Common date formats (MM/DD/YYYY, MM-DD-YY, etc.)
    - Line items: Patterns like "ITEM NAME  $X.XX" or "ITEM NAME  QTY @ $X.XX  $TOTAL"
    - Total: Lines with "TOTAL", "SUBTOTAL", "AMOUNT DUE" followed by amount

    Args:
        raw_text: Raw OCR output text

    Returns:
        ExtractionResult with parsed receipt data
    """
    lines = [line.strip() for line in raw_text.split('\n') if line.strip()]

    result = ExtractionResult(raw_ocr_text=raw_text)

    if not lines:
        logger.warning("No text extracted from receipt")
        return result

    # Extract merchant (first non-empty line, usually store name)
    merchant_name = lines[0] if lines else None
    merchant_confidence = 0.6 if merchant_name else 0.0
    result.merchant = MerchantInfo(name=merchant_name, confidence=merchant_confidence)

    # Extract date - multiple common formats
    date_patterns = [
        r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',  # MM/DD/YYYY or MM-DD-YY
        r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',    # YYYY-MM-DD
        r'\b([A-Z][a-z]{2}\s+\d{1,2},?\s+\d{4})\b',  # Jan 15, 2024
    ]

    date_value = None
    date_confidence = 0.0

    for line in lines:
        for pattern in date_patterns:
            match = re.search(pattern, line)
            if match:
                date_value = match.group(1)
                date_confidence = 0.8
                break
        if date_value:
            break

    result.date = DateInfo(value=date_value, confidence=date_confidence)

    # Extract total - look for total/subtotal keywords
    # Prioritize TOTAL over SUBTOTAL by checking TOTAL first
    total_patterns = [
        (r'(?:^|\s)TOTAL\s*[:$]?\s*\$?(\d+\.\d{2})', 0.9),  # TOTAL gets higher confidence
        (r'(?:AMOUNT\s+DUE|BALANCE)\s*[:$]?\s*\$?(\d+\.\d{2})', 0.85),
        (r'SUBTOTAL\s*[:$]?\s*\$?(\d+\.\d{2})', 0.75),  # SUBTOTAL is fallback
    ]

    total_amount = None
    total_confidence = 0.0

    # First pass: look for TOTAL keyword specifically
    for line in lines:
        line_upper = line.upper()
        if 'TOTAL' in line_upper and 'SUBTOTAL' not in line_upper:
            for pattern, conf in total_patterns:
                match = re.search(pattern, line_upper)
                if match:
                    total_amount = match.group(1)
                    total_confidence = conf
                    break
        if total_amount:
            break

    # Second pass: try all patterns if TOTAL not found
    if not total_amount:
        for line in lines:
            line_upper = line.upper()
            for pattern, conf in total_patterns:
                match = re.search(pattern, line_upper)
                if match:
                    total_amount = match.group(1)
                    total_confidence = conf
                    break
            if total_amount:
                break

    result.total = MoneyInfo(
        amount=total_amount,
        currency="USD",
        confidence=total_confidence
    )

    # Extract line items - patterns for items with prices
    line_item_patterns = [
        # Pattern: "ITEM NAME  QTY @ $X.XX  $TOTAL" (check this first for quantity info)
        (r'^(.+?)\s+(\d+(?:\.\d+)?)\s*@\s*\$?(\d+\.\d{2})\s+\$?(\d+\.\d{2})$', 'qty_at_price'),
        # Pattern: "ITEM NAME  QTY x $X.XX" or "ITEM NAME  QTY x $X.XX  $TOTAL"
        (r'^(.+?)\s+(\d+(?:\.\d+)?)\s*x\s*\$?(\d+\.\d{2})(?:\s+\$?(\d+\.\d{2}))?$', 'qty_x_price'),
        # Pattern: "ITEM NAME  $X.XX" or "ITEM NAME  X.XX" (simple case, no quantity)
        (r'^(.+?)\s+\$?(\d+\.\d{2})$', 'simple'),
    ]

    line_items = []

    for line in lines:
        # Skip lines that look like headers, footers, or totals
        line_upper = line.upper()
        if any(keyword in line_upper for keyword in [
            'TOTAL', 'SUBTOTAL', 'TAX', 'BALANCE', 'THANK', 'VISIT',
            'STORE', 'ADDRESS', 'PHONE', 'CASHIER', 'CARD', 'CHANGE'
        ]):
            continue

        # Try each pattern
        for pattern, pattern_type in line_item_patterns:
            match = re.search(pattern, line)
            if match:
                groups = match.groups()

                if pattern_type == 'simple':
                    # Simple: ITEM NAME  $X.XX
                    item_name = groups[0].strip()
                    price = groups[1]

                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=1.0,
                        total_price=MoneyInfo(amount=price, currency="USD", confidence=0.75),
                        confidence=0.75
                    ))

                elif pattern_type == 'qty_at_price':
                    # With quantity: ITEM NAME  QTY @ $X.XX  $TOTAL
                    item_name = groups[0].strip()
                    qty = float(groups[1])
                    unit_price = groups[2]
                    total_price = groups[3]

                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=qty,
                        unit_price=MoneyInfo(amount=unit_price, currency="USD", confidence=0.8),
                        total_price=MoneyInfo(amount=total_price, currency="USD", confidence=0.8),
                        confidence=0.8
                    ))

                elif pattern_type == 'qty_x_price':
                    # QTY x PRICE format (with optional total)
                    item_name = groups[0].strip()
                    qty = float(groups[1])
                    unit_price = groups[2]
                    total_price = groups[3] if len(groups) > 3 and groups[3] else None

                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=qty,
                        unit_price=MoneyInfo(amount=unit_price, currency="USD", confidence=0.8),
                        total_price=MoneyInfo(amount=total_price, currency="USD", confidence=0.8) if total_price else None,
                        confidence=0.8
                    ))

                break  # Stop trying patterns once we match

    result.line_items = line_items

    # Calculate overall confidence based on what we extracted
    confidence_factors = []
    if result.merchant.confidence > 0:
        confidence_factors.append(result.merchant.confidence)
    if result.date.confidence > 0:
        confidence_factors.append(result.date.confidence)
    if result.total.confidence > 0:
        confidence_factors.append(result.total.confidence)
    if line_items:
        avg_item_confidence = sum(item.confidence for item in line_items) / len(line_items)
        confidence_factors.append(avg_item_confidence)

    result.overall_confidence = sum(confidence_factors) / len(confidence_factors) if confidence_factors else 0.0

    logger.info(
        f"Parsed receipt: merchant={result.merchant.name}, "
        f"date={result.date.value}, total=${result.total.amount}, "
        f"items={len(line_items)}, confidence={result.overall_confidence:.2f}"
    )

    return result


def process_receipt(image_path: str, options: Optional[Dict] = None) -> ExtractionResult:
    """
    Full receipt processing pipeline.

    Steps:
    1. Preprocess image
    2. Extract text via Tesseract OCR
    3. Parse text to extract structured data

    Args:
        image_path: Path to receipt image file
        options: Optional processing options (reserved for future use)

    Returns:
        ExtractionResult with parsed receipt data

    Raises:
        FileNotFoundError: If image file doesn't exist
        ValueError: If image cannot be processed
        RuntimeError: If Tesseract fails
    """
    options = options or {}

    logger.info(f"Starting receipt processing: {image_path}")

    # Step 1: Preprocess
    preprocessed_image = preprocess_image(image_path)

    # Step 2: OCR
    raw_text = extract_text(preprocessed_image)

    # Step 3: Parse
    result = parse_receipt(raw_text)

    logger.info(f"Receipt processing complete with confidence {result.overall_confidence:.2f}")

    return result
