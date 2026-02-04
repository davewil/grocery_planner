#!/bin/bash
#
# Integration test runner for Elixir ↔ Python AI service.
#
# Starts the Python service on port 8099, runs integration tests, cleans up.
#
# Usage:
#   ./scripts/test-integration.sh
#   ./scripts/test-integration.sh --skip-python   # If Python is already running
#
# Prerequisites:
#   - Python dependencies installed (cd python_service && pip install -r requirements.txt)
#   - Tesseract OCR installed (apt-get install tesseract-ocr / brew install tesseract)
#

set -e

# Configuration
AI_SERVICE_PORT="${AI_SERVICE_PORT:-8099}"
AI_SERVICE_URL="http://localhost:${AI_SERVICE_PORT}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_PID=""
SKIP_PYTHON=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    if [ -n "$PYTHON_PID" ]; then
        kill "$PYTHON_PID" 2>/dev/null || true
        wait "$PYTHON_PID" 2>/dev/null || true
        echo "Stopped Python AI service (PID $PYTHON_PID)"
    fi
}

trap cleanup EXIT SIGINT SIGTERM

check_prerequisites() {
    local missing=0

    if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
        echo -e "${RED}Error: python3 not found${NC}"
        missing=1
    fi

    if ! command -v tesseract &>/dev/null; then
        echo -e "${YELLOW}Warning: tesseract not found — OCR will use mock/fallback mode${NC}"
    fi

    if [ ! -f "$PROJECT_ROOT/python_service/requirements.txt" ]; then
        echo -e "${RED}Error: python_service/requirements.txt not found${NC}"
        missing=1
    fi

    if [ $missing -ne 0 ]; then
        echo -e "${RED}Prerequisites check failed. See above.${NC}"
        exit 1
    fi
}

wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=${3:-30}
    local attempt=0

    echo -e "${YELLOW}Waiting for $name at $url...${NC}"
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}$name is ready!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    echo -e "${RED}$name failed to start after $max_attempts attempts${NC}"
    return 1
}

start_python_service() {
    echo -e "${GREEN}Starting Python AI service on port $AI_SERVICE_PORT...${NC}"

    cd "$PROJECT_ROOT/python_service"

    USE_TESSERACT_OCR=true \
    USE_VLLM_OCR=false \
    uvicorn main:app --host 127.0.0.1 --port "$AI_SERVICE_PORT" &
    PYTHON_PID=$!

    cd "$PROJECT_ROOT"

    if ! wait_for_service "$AI_SERVICE_URL/health" "Python AI service" 30; then
        echo -e "${RED}Failed to start Python service. Check logs above.${NC}"
        exit 1
    fi
}

run_integration_tests() {
    echo -e "\n${GREEN}Running integration tests...${NC}"
    echo "AI_SERVICE_URL=$AI_SERVICE_URL"

    cd "$PROJECT_ROOT"
    AI_SERVICE_URL="$AI_SERVICE_URL" mix test.integration
}

# Parse arguments
case "${1:-}" in
    --skip-python)
        SKIP_PYTHON=true
        ;;
    --help|-h)
        echo "Usage: $0 [--skip-python] [--help]"
        echo ""
        echo "Options:"
        echo "  --skip-python  Skip starting Python service (if already running)"
        echo "  --help         Show this help"
        exit 0
        ;;
esac

# Main
echo -e "${GREEN}=== Elixir ↔ Python Integration Tests ===${NC}"

check_prerequisites

if [ "$SKIP_PYTHON" = false ]; then
    start_python_service
else
    echo -e "${YELLOW}Skipping Python service start (--skip-python)${NC}"
    if ! curl -sf "$AI_SERVICE_URL/health" > /dev/null 2>&1; then
        echo -e "${RED}Python service not reachable at $AI_SERVICE_URL${NC}"
        exit 1
    fi
    echo -e "${GREEN}Python service is running at $AI_SERVICE_URL${NC}"
fi

run_integration_tests
echo -e "\n${GREEN}=== Integration tests complete ===${NC}"
