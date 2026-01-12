"""
Configuration settings for the AI service.

Environment variables:
- VLLM_BASE_URL: Base URL for vLLM server (default: http://localhost:8001/v1)
- VLLM_MODEL: Model to use for OCR (default: nanonets/Nanonets-OCR-s)
- OCR_MAX_TOKENS: Maximum tokens for OCR response (default: 4000)
- OCR_TIMEOUT: Timeout in seconds for OCR requests (default: 60)
"""

import os


class Settings:
    """Application settings loaded from environment variables."""

    VLLM_BASE_URL: str = os.getenv("VLLM_BASE_URL", "http://localhost:8001/v1")
    VLLM_MODEL: str = os.getenv("VLLM_MODEL", "nanonets/Nanonets-OCR-s")
    OCR_MAX_TOKENS: int = int(os.getenv("OCR_MAX_TOKENS", "4000"))
    OCR_TIMEOUT: int = int(os.getenv("OCR_TIMEOUT", "60"))

    # Feature flags for gradual rollout
    USE_VLLM_OCR: bool = os.getenv("USE_VLLM_OCR", "false").lower() == "true"


settings = Settings()
