"""
Tests for receipt OCR processing module.

Tests cover image preprocessing, text extraction, receipt parsing,
and the full processing pipeline.
"""

import pytest
from unittest.mock import patch, MagicMock
import numpy as np

from receipt_ocr import (
    preprocess_image, extract_text, parse_receipt, process_receipt
)
from schemas import ExtractionResult


class TestPreprocessImage:
    """Tests for image preprocessing."""

    def test_file_not_found(self):
        """Should raise FileNotFoundError for missing file."""
        with pytest.raises(FileNotFoundError, match="Image file not found"):
            preprocess_image("/nonexistent/path/image.jpg")

    @patch('receipt_ocr.Path.exists')
    @patch('receipt_ocr.Image.open')
    @patch('receipt_ocr.cv2.fastNlMeansDenoising')
    @patch('receipt_ocr.cv2.createCLAHE')
    @patch('receipt_ocr.cv2.adaptiveThreshold')
    def test_preprocessing_pipeline(
        self, mock_threshold, mock_clahe, mock_denoise, mock_image_open, mock_exists
    ):
        """Should execute full preprocessing pipeline."""
        # Mock path exists
        mock_exists.return_value = True

        # Mock PIL image
        mock_pil = MagicMock()
        mock_pil.mode = 'RGB'
        mock_pil_array = np.random.randint(0, 255, (1000, 800, 3), dtype=np.uint8)
        mock_image_open.return_value = mock_pil

        # Mock preprocessing steps
        gray_image = np.random.randint(0, 255, (1000, 800), dtype=np.uint8)
        mock_denoise.return_value = gray_image

        mock_clahe_obj = MagicMock()
        mock_clahe_obj.apply.return_value = gray_image
        mock_clahe.return_value = mock_clahe_obj

        binary_image = np.random.randint(0, 255, (1000, 800), dtype=np.uint8)
        mock_threshold.return_value = binary_image

        with patch('receipt_ocr.np.array', return_value=mock_pil_array):
            with patch('receipt_ocr.cv2.cvtColor', return_value=gray_image):
                result = preprocess_image("/fake/path/receipt.jpg")

        assert isinstance(result, np.ndarray)
        mock_denoise.assert_called_once()
        mock_clahe.assert_called_once()
        mock_threshold.assert_called_once()

    @patch('receipt_ocr.Path.exists')
    @patch('receipt_ocr.Image.open')
    def test_handles_large_images(self, mock_image_open, mock_exists):
        """Should resize images larger than 4000px."""
        # Mock path exists
        mock_exists.return_value = True

        # Create a mock large image
        mock_pil = MagicMock()
        mock_pil.mode = 'L'
        large_image = np.random.randint(0, 255, (5000, 4500), dtype=np.uint8)

        mock_image_open.return_value = mock_pil

        with patch('receipt_ocr.np.array', return_value=large_image):
            with patch('receipt_ocr.cv2.fastNlMeansDenoising', return_value=large_image):
                with patch('receipt_ocr.cv2.createCLAHE') as mock_clahe:
                    with patch('receipt_ocr.cv2.adaptiveThreshold', return_value=large_image):
                        with patch('receipt_ocr.cv2.resize', return_value=large_image) as mock_resize:
                            mock_clahe_obj = MagicMock()
                            mock_clahe_obj.apply.return_value = large_image
                            mock_clahe.return_value = mock_clahe_obj

                            preprocess_image("/fake/large_receipt.jpg")

                            # Should have called resize
                            mock_resize.assert_called_once()


class TestExtractText:
    """Tests for OCR text extraction."""

    @patch('receipt_ocr.pytesseract.image_to_string')
    def test_extract_text_success(self, mock_tesseract):
        """Should extract text using Tesseract."""
        mock_tesseract.return_value = "WALMART\n01/15/2024\nMILK 3.99\nBREAD 2.49\nTOTAL 6.48"

        image = np.zeros((100, 100), dtype=np.uint8)
        result = extract_text(image)

        assert "WALMART" in result
        assert "TOTAL 6.48" in result
        mock_tesseract.assert_called_once()

    @patch('receipt_ocr.pytesseract.image_to_string')
    def test_tesseract_not_found(self, mock_tesseract):
        """Should raise RuntimeError if Tesseract not installed."""
        import pytesseract
        mock_tesseract.side_effect = pytesseract.TesseractNotFoundError()

        image = np.zeros((100, 100), dtype=np.uint8)

        with pytest.raises(RuntimeError, match="Tesseract OCR not found"):
            extract_text(image)


class TestParseReceipt:
    """Tests for receipt parsing."""

    def test_parse_simple_receipt(self):
        """Should parse a simple receipt with basic format."""
        raw_text = """WALMART SUPERCENTER
123 Main St
01/15/2024

MILK                    3.99
BREAD                   2.49
EGGS                    4.29

SUBTOTAL               10.77
TAX                     0.86
TOTAL                  11.63

THANK YOU
"""
        result = parse_receipt(raw_text)

        assert isinstance(result, ExtractionResult)
        assert result.merchant.name == "WALMART SUPERCENTER"
        assert result.merchant.confidence > 0.5
        assert result.date.value == "01/15/2024"
        assert result.date.confidence > 0.7
        assert result.total.amount == "11.63"
        assert result.total.confidence > 0.8
        assert len(result.line_items) >= 2  # Should extract at least some items
        assert result.overall_confidence > 0.0

    def test_parse_receipt_with_quantities(self):
        """Should parse receipts with quantity information."""
        raw_text = """TARGET
Store #1234
12/25/2023

BANANAS   2.5 @ $0.69    $1.73
APPLES    3 x $1.29      $3.87

TOTAL                    $5.60
"""
        result = parse_receipt(raw_text)

        assert result.merchant.name == "TARGET"
        assert result.date.value == "12/25/2023"
        assert result.total.amount == "5.60"
        assert len(result.line_items) >= 1

        # Check if quantity was parsed for any item
        items_with_qty = [item for item in result.line_items if item.quantity and item.quantity > 1]
        assert len(items_with_qty) >= 1

    def test_parse_empty_text(self):
        """Should handle empty OCR text gracefully."""
        result = parse_receipt("")

        assert isinstance(result, ExtractionResult)
        assert result.merchant.confidence == 0.0
        assert result.date.confidence == 0.0
        assert result.total.confidence == 0.0
        assert len(result.line_items) == 0
        assert result.overall_confidence == 0.0

    def test_parse_minimal_receipt(self):
        """Should handle receipts with minimal information."""
        raw_text = """Some Store Name
ITEM 1   5.00
"""
        result = parse_receipt(raw_text)

        assert result.merchant.name == "Some Store Name"
        assert result.merchant.confidence > 0.5
        # May or may not extract items depending on format
        assert result.overall_confidence >= 0.0

    def test_date_format_variations(self):
        """Should recognize multiple date formats."""
        test_cases = [
            ("Receipt\n01/15/2024\nITEM 5.00", "01/15/2024"),
            ("Receipt\n2024-01-15\nITEM 5.00", "2024-01-15"),
            ("Receipt\nJan 15, 2024\nITEM 5.00", "Jan 15, 2024"),
        ]

        for raw_text, expected_date in test_cases:
            result = parse_receipt(raw_text)
            assert result.date.value == expected_date

    def test_total_keyword_variations(self):
        """Should recognize different total keywords."""
        test_cases = [
            "TOTAL: $10.00",
            "SUBTOTAL 10.00",
            "AMOUNT DUE $10.00",
            "BALANCE $10.00",
        ]

        for line in test_cases:
            raw_text = f"Store\n{line}"
            result = parse_receipt(raw_text)
            assert result.total.amount == "10.00"
            assert result.total.confidence > 0.8


class TestProcessReceipt:
    """Tests for full receipt processing pipeline."""

    @patch('receipt_ocr.extract_text')
    @patch('receipt_ocr.preprocess_image')
    def test_full_pipeline(self, mock_preprocess, mock_extract):
        """Should execute full processing pipeline."""
        # Mock preprocessing
        mock_image = np.zeros((100, 100), dtype=np.uint8)
        mock_preprocess.return_value = mock_image

        # Mock OCR
        mock_extract.return_value = """GROCERY STORE
01/20/2024
MILK    3.99
BREAD   2.49
TOTAL   6.48
"""

        with patch('receipt_ocr.Path.exists', return_value=True):
            result = process_receipt("/fake/receipt.jpg")

        assert isinstance(result, ExtractionResult)
        assert result.merchant.name == "GROCERY STORE"
        assert result.date.value == "01/20/2024"
        assert result.total.amount == "6.48"
        assert result.overall_confidence > 0.0

        mock_preprocess.assert_called_once()
        mock_extract.assert_called_once()

    @patch('receipt_ocr.preprocess_image')
    def test_file_not_found_error(self, mock_preprocess):
        """Should propagate FileNotFoundError from preprocessing."""
        mock_preprocess.side_effect = FileNotFoundError("Image file not found")

        with pytest.raises(FileNotFoundError):
            process_receipt("/nonexistent/receipt.jpg")

    @patch('receipt_ocr.extract_text')
    @patch('receipt_ocr.preprocess_image')
    def test_tesseract_runtime_error(self, mock_preprocess, mock_extract):
        """Should propagate RuntimeError from OCR."""
        mock_preprocess.return_value = np.zeros((100, 100), dtype=np.uint8)
        mock_extract.side_effect = RuntimeError("Tesseract OCR not found")

        with pytest.raises(RuntimeError, match="Tesseract"):
            process_receipt("/fake/receipt.jpg")

    @patch('receipt_ocr.extract_text')
    @patch('receipt_ocr.preprocess_image')
    def test_with_custom_options(self, mock_preprocess, mock_extract):
        """Should accept custom processing options."""
        mock_preprocess.return_value = np.zeros((100, 100), dtype=np.uint8)
        mock_extract.return_value = "STORE\nTOTAL 10.00"

        with patch('receipt_ocr.Path.exists', return_value=True):
            result = process_receipt(
                "/fake/receipt.jpg",
                options={"enhance": True, "deskew": True}
            )

        assert isinstance(result, ExtractionResult)
        # Options don't change behavior in MVP, but should not cause errors
