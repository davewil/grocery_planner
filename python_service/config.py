"""
Configuration settings for the AI service.

Environment variables:
- VLLM_BASE_URL: Base URL for vLLM server (default: http://localhost:8001/v1)
- VLLM_MODEL: Model to use for OCR (default: nanonets/Nanonets-OCR-s)
- OCR_MAX_TOKENS: Maximum tokens for OCR response (default: 4000)
- OCR_TIMEOUT: Timeout in seconds for OCR requests (default: 60)
- CLASSIFICATION_MODEL: Model for zero-shot classification (default: valhalla/distilbart-mnli-12-3)
- USE_REAL_CLASSIFICATION: Enable real ML classification (default: false)
- USE_OLLAMA_OCR: Use Ollama for receipt OCR (default: true, highest priority)
- OLLAMA_BASE_URL: Ollama API base URL (default: http://localhost:11434)
- OLLAMA_MODEL: Ollama model for OCR (default: llava)
- OLLAMA_OCR_TIMEOUT: Timeout in seconds for Ollama OCR requests (default: 120)
- USE_TESSERACT_OCR: Use Tesseract OCR as fallback when VLM is disabled (default: true)
"""

import os


class Settings:
    """Application settings loaded from environment variables."""

    VLLM_BASE_URL: str = os.getenv("VLLM_BASE_URL", "http://localhost:8001/v1")
    VLLM_MODEL: str = os.getenv("VLLM_MODEL", "nanonets/Nanonets-OCR-s")
    OCR_MAX_TOKENS: int = int(os.getenv("OCR_MAX_TOKENS", "4000"))
    OCR_TIMEOUT: int = int(os.getenv("OCR_TIMEOUT", "60"))

    # Feature flags for gradual rollout
    USE_OLLAMA_OCR: bool = os.getenv("USE_OLLAMA_OCR", "true").lower() == "true"
    USE_VLLM_OCR: bool = os.getenv("USE_VLLM_OCR", "false").lower() == "true"
    USE_TESSERACT_OCR: bool = os.getenv("USE_TESSERACT_OCR", "true").lower() == "true"

    # Ollama Vision OCR settings
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "llava")
    OLLAMA_OCR_TIMEOUT: int = int(os.getenv("OLLAMA_OCR_TIMEOUT", "120"))

    # Zero-shot classification settings
    CLASSIFICATION_MODEL: str = os.getenv(
        "CLASSIFICATION_MODEL", "valhalla/distilbart-mnli-12-3"
    )
    USE_REAL_CLASSIFICATION: bool = os.getenv(
        "USE_REAL_CLASSIFICATION", "false"
    ).lower() == "true"

    # Debug mode
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Tidewave AI-assisted debugging (only active when DEBUG=True)
    TIDEWAVE_ENABLED: bool = os.getenv("TIDEWAVE_ENABLED", "true").lower() == "true"

    # OpenTelemetry settings
    OTEL_ENABLED: bool = os.getenv("OTEL_ENABLED", "false").lower() == "true"
    OTEL_EXPORTER_OTLP_ENDPOINT: str = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"
    )
    OTEL_SERVICE_NAME: str = os.getenv("OTEL_SERVICE_NAME", "grocery-planner-ai")


settings = Settings()
