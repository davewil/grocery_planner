"""
Tests for the OCR service module.
"""

import pytest

# Import the parsing function - this doesn't require vLLM to be running
from ocr_service import parse_receipt_markdown


class TestParseReceiptMarkdown:
    """Tests for the markdown parser."""

    def test_parses_basic_receipt(self):
        """Test parsing a well-formatted receipt markdown."""
        markdown = """
## Items
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Bananas | 1 | bunch | $1.99 |
| Milk | 1 | gallon | $3.49 |
| Bread | 2 | loaf | 2.50 |

## Summary
- **Total**: $7.98
- **Merchant**: Test Store
- **Date**: 2024-01-15
"""
        result = parse_receipt_markdown(markdown)

        assert len(result["items"]) == 3
        assert result["items"][0]["name"] == "Bananas"
        assert result["items"][0]["quantity"] == 1.0
        assert result["items"][0]["unit"] == "bunch"  # units are preserved
        assert result["items"][0]["price"] == 1.99
        assert result["items"][1]["name"] == "Milk"
        assert result["items"][1]["unit"] == "gallon"
        assert result["items"][2]["name"] == "Bread"
        assert result["items"][2]["quantity"] == 2.0
        assert result["total"] == 7.98
        assert result["merchant"] == "Test Store"
        assert result["date"] == "2024-01-15"

    def test_handles_missing_summary(self):
        """Test parsing when summary section is missing."""
        markdown = """
## Items
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Apple | 3 | - | 0.99 |
"""
        result = parse_receipt_markdown(markdown)

        assert len(result["items"]) == 1
        assert result["items"][0]["name"] == "Apple"
        assert result["items"][0]["quantity"] == 3.0
        assert result["items"][0]["unit"] is None  # "-" normalized to None
        assert result["total"] is None
        assert result["merchant"] is None
        assert result["date"] is None

    def test_handles_partial_summary(self):
        """Test parsing when only some summary fields are present."""
        markdown = """
## Items
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Coffee | 1 | bag | 12.99 |

## Summary
- **Total**: $12.99
"""
        result = parse_receipt_markdown(markdown)

        assert result["total"] == 12.99
        assert result["merchant"] is None
        assert result["date"] is None

    def test_handles_various_price_formats(self):
        """Test parsing different price formats."""
        markdown = """
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Item A | 1 | - | $5.99 |
| Item B | 1 | - | 3.50 |
| Item C | 1 | - | 10.00 |
"""
        result = parse_receipt_markdown(markdown)

        assert len(result["items"]) == 3
        assert result["items"][0]["price"] == 5.99
        assert result["items"][1]["price"] == 3.50
        assert result["items"][2]["price"] == 10.00

    def test_skips_header_rows(self):
        """Test that header and separator rows are skipped."""
        markdown = """
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Real Item | 1 | each | 5.00 |
"""
        result = parse_receipt_markdown(markdown)

        assert len(result["items"]) == 1
        assert result["items"][0]["name"] == "Real Item"

    def test_handles_non_numeric_quantity(self):
        """Test handling of non-numeric quantity values."""
        markdown = """
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Mystery Item | some | - | 1.99 |
"""
        result = parse_receipt_markdown(markdown)

        assert len(result["items"]) == 1
        assert result["items"][0]["quantity"] == 1.0  # Defaults to 1.0

    def test_handles_empty_markdown(self):
        """Test handling of empty or minimal input."""
        result = parse_receipt_markdown("")

        assert result["items"] == []
        assert result["total"] is None
        assert result["merchant"] is None
        assert result["date"] is None

    def test_normalizes_unknown_merchant(self):
        """Test that 'Unknown' merchant is normalized to None."""
        markdown = """
## Summary
- **Merchant**: Unknown
"""
        result = parse_receipt_markdown(markdown)
        assert result["merchant"] is None

    def test_handles_extra_whitespace(self):
        """Test parsing with extra whitespace in table cells."""
        markdown = """
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
|   Spaced Item   |   2   |   kg   |   4.99   |
"""
        result = parse_receipt_markdown(markdown)

        assert len(result["items"]) == 1
        assert result["items"][0]["name"] == "Spaced Item"
        assert result["items"][0]["quantity"] == 2.0
        assert result["items"][0]["price"] == 4.99

    def test_confidence_always_set(self):
        """Test that confidence is always set to 0.9."""
        markdown = """
| Item | Quantity | Unit | Price |
|------|----------|------|-------|
| Test | 1 | - | 1.00 |
"""
        result = parse_receipt_markdown(markdown)

        assert result["items"][0]["confidence"] == 0.9


class TestExtractReceiptIntegration:
    """Integration tests that require vLLM to be running."""

    @pytest.mark.skip(reason="Requires vLLM server running")
    @pytest.mark.asyncio
    async def test_extract_receipt_real_image(self):
        """Test extraction with a real receipt image."""
        import base64
        from pathlib import Path
        from ocr_service import extract_receipt

        # Load test image
        test_image = Path("tests/fixtures/sample_receipt.png")
        if not test_image.exists():
            pytest.skip("Test image not found")

        image_b64 = base64.b64encode(test_image.read_bytes()).decode()
        result = await extract_receipt(image_b64)

        assert "items" in result
        assert isinstance(result["items"], list)
        # Don't assert specific items since OCR output varies
