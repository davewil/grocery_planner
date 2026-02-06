"""
Receipt OCR Processing Module

Handles image preprocessing, OCR text extraction, and receipt parsing
using Tesseract OCR with regex-based extraction (MVP approach).
"""

import re
import logging
from typing import Dict, Optional
from pathlib import Path

import cv2
import numpy as np
import pytesseract
from PIL import Image

from schemas import (
    ExtractionResult, MerchantInfo, DateInfo, MoneyInfo, LineItem
)

logger = logging.getLogger("grocery-planner-ai")


def _load_and_prepare(image_path: str) -> np.ndarray:
    """Load image and convert to grayscale numpy array, resizing if needed."""
    path = Path(image_path)
    if not path.exists():
        raise FileNotFoundError(f"Image file not found: {image_path}")

    try:
        pil_image = Image.open(image_path)
        pil_image.load()  # Force load to detect corrupt files early
    except Exception as e:
        raise ValueError(f"Cannot load image: {e}")

    # Convert to RGB if needed (handles RGBA, P, etc.)
    if pil_image.mode not in ('RGB', 'L'):
        pil_image = pil_image.convert('RGB')

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

    return gray


def _preprocess_grayscale(gray: np.ndarray) -> np.ndarray:
    """Light preprocessing: denoise + contrast. Best for Tesseract 5 LSTM."""
    denoised = cv2.fastNlMeansDenoising(gray, None, h=10, templateWindowSize=7, searchWindowSize=21)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(denoised)


def _preprocess_binary(gray: np.ndarray) -> np.ndarray:
    """Aggressive preprocessing with binarization. Better for clean scans."""
    denoised = cv2.fastNlMeansDenoising(gray, None, h=10, templateWindowSize=7, searchWindowSize=21)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(denoised)
    return cv2.adaptiveThreshold(
        enhanced, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
    )


def preprocess_image(image_path: str) -> np.ndarray:
    """
    Preprocess receipt image for better OCR accuracy.

    Tries grayscale-only preprocessing first (better for Tesseract 5 LSTM
    with phone photos), falls back to binary thresholding if grayscale
    produces poor results.

    Args:
        image_path: Path to the receipt image file

    Returns:
        Preprocessed image as numpy array

    Raises:
        FileNotFoundError: If image file doesn't exist
        ValueError: If image cannot be loaded
    """
    try:
        gray = _load_and_prepare(image_path)

        # Try grayscale preprocessing first (best for LSTM engine with phone photos)
        grayscale_result = _preprocess_grayscale(gray)

        logger.info(f"Preprocessed image: {image_path}")
        return grayscale_result

    except FileNotFoundError:
        raise
    except Exception as e:
        logger.error(f"Failed to preprocess image {image_path}: {e}")
        raise ValueError(f"Cannot load or process image: {e}")


def _ocr_quality_score(text: str) -> float:
    """Score OCR output quality based on readable content indicators."""
    if not text.strip():
        return 0.0
    lines = [ln.strip() for ln in text.split('\n') if ln.strip()]
    if not lines:
        return 0.0

    score = 0.0
    # Reward lines with recognizable price patterns (£X.XX, $X.XX, X.XX)
    price_lines = sum(1 for ln in lines if re.search(r'[£$€]?\d+\.\d{2}', ln))
    score += price_lines * 10

    # Reward lines with high alpha ratio (readable words)
    for line in lines:
        alpha = sum(c.isalpha() for c in line)
        if len(line) > 0 and alpha / len(line) > 0.5:
            score += 2

    # Reward finding key receipt keywords
    full_text_upper = text.upper()
    for keyword in ['TOTAL', 'SUBTOTAL', 'TESCO', 'DATE', 'CARD', 'OFFER']:
        if keyword in full_text_upper:
            score += 5

    return score


def extract_text(image: np.ndarray) -> str:
    """
    Run Tesseract OCR to extract text from preprocessed image.

    Tries multiple PSM modes and picks the best result.

    Args:
        image: Preprocessed image as numpy array

    Returns:
        Raw OCR text output

    Raises:
        RuntimeError: If Tesseract is not installed or fails
    """
    try:
        # Try multiple PSM modes and pick the best result
        # PSM 4 = single column variable sizes, PSM 6 = uniform block, PSM 3 = fully automatic
        best_text = ""
        best_score = -1.0

        for psm in [6, 4, 3]:
            config = f'--oem 1 --psm {psm}'
            text = pytesseract.image_to_string(image, config=config)
            score = _ocr_quality_score(text)
            logger.debug(f"PSM {psm}: score={score:.1f}, chars={len(text)}")
            if score > best_score:
                best_score = score
                best_text = text

        logger.info(f"Extracted {len(best_text)} characters via OCR (best score: {best_score:.1f})")
        logger.debug(f"Raw OCR output:\n{best_text}")
        return best_text

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
    # Debug logging for OCR quality
    logger.info(f"OCR raw text (first 500 chars): {raw_text[:500]}")

    lines = [line.strip() for line in raw_text.split('\n') if line.strip()]

    result = ExtractionResult(raw_ocr_text=raw_text)

    if not lines:
        logger.warning("No text extracted from receipt")
        return result

    # Extract merchant - skip lines with mostly non-alpha characters (likely OCR noise)
    merchant_name = None
    merchant_confidence = 0.0
    for line in lines[:5]:  # Check first 5 lines
        alpha_chars = sum(c.isalpha() for c in line)
        if alpha_chars >= max(2, len(line) * 0.5):  # At least 50% alpha or 2+ chars
            merchant_name = line
            merchant_confidence = 0.6
            break

    if not merchant_name and lines:  # Fallback to first line
        merchant_name = lines[0]
        merchant_confidence = 0.4

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
    # Currency-agnostic: supports £, $, €
    total_patterns = [
        (r'(?:^|\s)TOTAL\s*[:£$€]?\s*[£$€]?(\d+\.\d{2})', 0.9),  # TOTAL gets higher confidence
        (r'(?:AMOUNT\s+DUE|BALANCE)\s*[:£$€]?\s*[£$€]?(\d+\.\d{2})', 0.85),
        (r'SUBTOTAL\s*[:£$€]?\s*[£$€]?(\d+\.\d{2})', 0.75),  # SUBTOTAL is fallback
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

    # Detect currency from raw text
    currency = "USD"
    if '£' in raw_text:
        currency = "GBP"
    elif '€' in raw_text:
        currency = "EUR"

    result.total = MoneyInfo(
        amount=total_amount,
        currency=currency,
        confidence=total_confidence
    )

    # Extract line items - patterns for items with prices
    # Currency-agnostic (£, $, €), flexible decimal places, minimum 2-char item names
    line_item_patterns = [
        # Pattern: "ITEM NAME  QTY @ £X.XX  £TOTAL"
        (r'^(.{2,}?)\s{2,}(\d+(?:\.\d+)?)\s*@\s*[£$€]?\s*(\d+\.?\d*)\s+[£$€]?\s*(\d+\.?\d*)', 'qty_at_price'),
        # Pattern: "ITEM NAME  QTY x £X.XX" or with total
        (r'^(.{2,}?)\s{2,}(\d+(?:\.\d+)?)\s*[xX]\s*[£$€]?\s*(\d+\.?\d*)(?:\s+[£$€]?\s*(\d+\.?\d*))?', 'qty_x_price'),
        # Pattern: "ITEM NAME     £X.XX" (2+ spaces before price, price at or near end)
        (r'^(.{2,}?)\s{2,}[£$€]?\s*(\d+\.?\d{0,2})\s*$', 'simple_currency'),
        # Pattern: "ITEM NAME     X.XX" (no currency symbol, 2+ spaces gap)
        (r'^(.{2,}?)\s{2,}(\d+\.\d{2})\s*$', 'simple'),
    ]

    skip_patterns = [
        r'\bSUBTOTAL\b', r'\bTOTAL\b', r'\bTAX\b', r'\bBALANCE\s*DUE\b',
        r'\bAMOUNT\s*DUE\b', r'\bTHANK\s*YOU\b', r'\bCASHIER\b',
        r'\bCHANGE\s*DUE\b', r'\bCARD\s*ENDING\b', r'\bPAYMENT\b',
        r'\bSAVINGS\b', r'\bPROMOTIONS?\b', r'\bCLUBCARD\b',
        r'\bSPECIAL\s*OFFER\b', r'\bVISA\b', r'^CARD\b',
        r'\bVAT\b', r'\bAID\b', r'\bPAN\b', r'\bAUTHOR\b',
    ]

    line_items = []

    def _clean_item_name(name: str) -> str:
        """Strip leading quantity prefix and OCR artifacts from item names."""
        # Remove leading "1 ", "I ", "1  " etc. (OCR often includes the qty column)
        cleaned = re.sub(r'^[1IlL|]\s+', '', name)
        # Remove leading OCR noise like "==", "--", "=="
        cleaned = re.sub(r'^[=\-|]+\s*', '', cleaned)
        return cleaned.strip()

    for line in lines:
        # Skip lines that look like headers, footers, or totals
        line_upper = line.upper()
        if any(re.search(p, line_upper) for p in skip_patterns):
            continue

        # Skip discount/negative price lines
        if re.search(r'-[£$€]?\d+\.\d{2}', line):
            continue

        # Try each pattern
        for pattern, pattern_type in line_item_patterns:
            match = re.search(pattern, line)
            if match:
                groups = match.groups()

                if pattern_type in ('simple', 'simple_currency'):
                    item_name = _clean_item_name(groups[0])
                    price = groups[1]

                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=1.0,
                        total_price=MoneyInfo(amount=price, currency=currency, confidence=0.75),
                        confidence=0.75
                    ))

                elif pattern_type == 'qty_at_price':
                    item_name = _clean_item_name(groups[0])
                    qty = float(groups[1])
                    unit_price = groups[2]
                    total_price = groups[3]

                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=qty,
                        unit_price=MoneyInfo(amount=unit_price, currency=currency, confidence=0.8),
                        total_price=MoneyInfo(amount=total_price, currency=currency, confidence=0.8),
                        confidence=0.8
                    ))

                elif pattern_type == 'qty_x_price':
                    item_name = _clean_item_name(groups[0])
                    qty = float(groups[1])
                    unit_price = groups[2]
                    total_price = groups[3] if len(groups) > 3 and groups[3] else None

                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=qty,
                        unit_price=MoneyInfo(amount=unit_price, currency=currency, confidence=0.8),
                        total_price=MoneyInfo(amount=total_price, currency=currency, confidence=0.8) if total_price else None,
                        confidence=0.8
                    ))

                break  # Stop trying patterns once we match

    # Second pass: catch lines with a price that weren't matched by strict patterns
    if len(line_items) == 0:
        logger.info("No items found with strict patterns, trying relaxed matching")
        for line in lines:
            line_upper = line.upper()
            if any(re.search(p, line_upper) for p in skip_patterns):
                continue
            if re.search(r'-[£$€]?\d+\.\d{2}', line):
                continue
            match = re.search(r'^(.+?)\s+[£$€]?(\d+\.\d{2})\s*$', line)
            if match:
                item_name = _clean_item_name(match.group(1))
                price = match.group(2)
                if len(item_name) >= 2:
                    line_items.append(LineItem(
                        raw_text=line,
                        parsed_name=item_name,
                        quantity=1.0,
                        total_price=MoneyInfo(amount=price, currency=currency, confidence=0.6),
                        confidence=0.6
                    ))

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

    Tries grayscale preprocessing first (best for phone photos with
    Tesseract 5 LSTM), then falls back to binary thresholding if the
    grayscale result is poor. Picks whichever produces better extraction.

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

    gray = _load_and_prepare(image_path)

    # Strategy 1: Grayscale (best for LSTM engine with phone photos)
    grayscale_img = _preprocess_grayscale(gray)
    grayscale_text = extract_text(grayscale_img)
    grayscale_score = _ocr_quality_score(grayscale_text)
    logger.info(f"Grayscale preprocessing score: {grayscale_score:.1f}")

    # Strategy 2: Binary thresholding (better for clean scans)
    binary_img = _preprocess_binary(gray)
    binary_text = extract_text(binary_img)
    binary_score = _ocr_quality_score(binary_text)
    logger.info(f"Binary preprocessing score: {binary_score:.1f}")

    # Pick the better result
    if grayscale_score >= binary_score:
        raw_text = grayscale_text
        logger.info("Selected grayscale preprocessing (better quality)")
    else:
        raw_text = binary_text
        logger.info("Selected binary preprocessing (better quality)")

    result = parse_receipt(raw_text)

    logger.info(f"Receipt processing complete with confidence {result.overall_confidence:.2f}")

    return result
