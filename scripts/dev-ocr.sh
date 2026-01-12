#!/bin/bash
#
# Development script for running the full OCR stack.
#
# Usage:
#   ./scripts/dev-ocr.sh                    # Start full stack with mock OCR
#   ./scripts/dev-ocr.sh --with-vllm        # Start with real vLLM OCR
#   ./scripts/dev-ocr.sh --vllm-only        # Start only vLLM server
#   ./scripts/dev-ocr.sh --python-only      # Start only Python AI service
#
# Prerequisites:
#   - vLLM installed (pip install vllm)
#   - Python dependencies (cd python_service && pip install -r requirements.txt)
#   - Model downloaded (huggingface-cli download nanonets/Nanonets-OCR-s)
#
# Environment variables:
#   VLLM_MODEL      - Model to serve (default: nanonets/Nanonets-OCR-s)
#   VLLM_PORT       - vLLM server port (default: 8001)
#   AI_SERVICE_PORT - Python AI service port (default: 8000)
#   MAX_MODEL_LEN   - Maximum model context length (default: 4096)
#

set -e

# Configuration
VLLM_MODEL="${VLLM_MODEL:-nanonets/Nanonets-OCR-s}"
VLLM_PORT="${VLLM_PORT:-8001}"
AI_SERVICE_PORT="${AI_SERVICE_PORT:-8000}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track PIDs for cleanup
VLLM_PID=""
PYTHON_PID=""

cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    if [ -n "$VLLM_PID" ]; then
        kill $VLLM_PID 2>/dev/null || true
        echo "Stopped vLLM server"
    fi
    if [ -n "$PYTHON_PID" ]; then
        kill $PYTHON_PID 2>/dev/null || true
        echo "Stopped Python AI service"
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=${3:-30}
    local attempt=0

    echo -e "${YELLOW}Waiting for $name to be ready...${NC}"
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}$name is ready!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    echo -e "${RED}$name failed to start after $max_attempts attempts${NC}"
    return 1
}

start_vllm() {
    echo -e "${GREEN}Starting vLLM server...${NC}"
    echo "Model: $VLLM_MODEL"
    echo "Port: $VLLM_PORT"
    echo "Max context length: $MAX_MODEL_LEN"

    vllm serve "$VLLM_MODEL" \
        --host 0.0.0.0 \
        --port "$VLLM_PORT" \
        --max-model-len "$MAX_MODEL_LEN" \
        --trust-remote-code &
    VLLM_PID=$!

    wait_for_service "http://localhost:$VLLM_PORT/health" "vLLM" 60
}

start_python_service() {
    local use_vllm=$1

    echo -e "${GREEN}Starting Python AI service...${NC}"
    echo "Port: $AI_SERVICE_PORT"
    echo "USE_VLLM_OCR: $use_vllm"

    cd "$(dirname "$0")/../python_service"

    USE_VLLM_OCR="$use_vllm" \
    VLLM_BASE_URL="http://localhost:$VLLM_PORT/v1" \
    VLLM_MODEL="$VLLM_MODEL" \
    uvicorn main:app --host 0.0.0.0 --port "$AI_SERVICE_PORT" --reload &
    PYTHON_PID=$!

    cd - > /dev/null

    wait_for_service "http://localhost:$AI_SERVICE_PORT/health" "Python AI service"
}

start_elixir() {
    echo -e "${GREEN}Starting Elixir application...${NC}"
    cd "$(dirname "$0")/.."
    AI_SERVICE_URL="http://localhost:$AI_SERVICE_PORT" mix phx.server
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --with-vllm     Start full stack with real vLLM OCR"
    echo "  --vllm-only     Start only vLLM server"
    echo "  --python-only   Start only Python AI service (mock mode)"
    echo "  --help          Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  VLLM_MODEL      Model to serve (default: nanonets/Nanonets-OCR-s)"
    echo "  VLLM_PORT       vLLM server port (default: 8001)"
    echo "  AI_SERVICE_PORT Python AI service port (default: 8000)"
    echo "  MAX_MODEL_LEN   Maximum model context length (default: 4096)"
}

# Main
case "${1:-}" in
    --with-vllm)
        echo -e "${GREEN}Starting full stack with vLLM OCR${NC}"
        start_vllm
        start_python_service "true"
        start_elixir
        ;;
    --vllm-only)
        echo -e "${GREEN}Starting vLLM server only${NC}"
        start_vllm
        echo -e "\n${GREEN}vLLM server running. Press Ctrl+C to stop.${NC}"
        wait $VLLM_PID
        ;;
    --python-only)
        echo -e "${GREEN}Starting Python AI service only (mock mode)${NC}"
        start_python_service "false"
        echo -e "\n${GREEN}Python AI service running. Press Ctrl+C to stop.${NC}"
        wait $PYTHON_PID
        ;;
    --help|-h)
        print_usage
        exit 0
        ;;
    "")
        echo -e "${GREEN}Starting full stack with mock OCR${NC}"
        echo -e "${YELLOW}Use --with-vllm to enable real OCR${NC}"
        start_python_service "false"
        start_elixir
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        print_usage
        exit 1
        ;;
esac
