#!/bin/bash
# ProStaff API Load Testing Runner
# Usage: ./run-tests.sh [test-type] [environment]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
TEST_TYPE=${1:-smoke}
ENVIRONMENT=${2:-local}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${SCRIPT_DIR}/results/${TEST_TYPE}_${TIMESTAMP}"

# Environment URLs
declare -A ENV_URLS=(
  [local]="http://localhost:3333"
  [staging]="https://staging-api.prostaff.gg"
  [production]="https://api.prostaff.gg"
)

# Test scenarios (using absolute paths)
declare -A TEST_FILES=(
  [smoke]="${SCRIPT_DIR}/scenarios/smoke-test.js"
  [load]="${SCRIPT_DIR}/scenarios/load-test.js"
  [stress]="${SCRIPT_DIR}/scenarios/stress-test.js"
  [spike]="${SCRIPT_DIR}/scenarios/spike-test.js"
  [soak]="${SCRIPT_DIR}/scenarios/soak-test.js"
)

# Validate test type
if [[ ! -v TEST_FILES[$TEST_TYPE] ]]; then
  echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
  echo "Available tests: ${!TEST_FILES[@]}"
  exit 1
fi

# Validate environment
if [[ ! -v ENV_URLS[$ENVIRONMENT] ]]; then
  echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
  echo "Available environments: ${!ENV_URLS[@]}"
  exit 1
fi

BASE_URL=${ENV_URLS[$ENVIRONMENT]}
TEST_FILE=${TEST_FILES[$TEST_TYPE]}

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}❌ k6 is not installed${NC}"
    echo "Run: ./load_tests/k6-setup.sh"
    exit 1
fi

# Check if test file exists
if [[ ! -f "$TEST_FILE" ]]; then
    echo -e "${RED}❌ Test file not found: $TEST_FILE${NC}"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Warning for production
if [[ "$ENVIRONMENT" == "production" ]]; then
  echo -e "${RED}⚠️  WARNING: Running load tests against PRODUCTION!${NC}"
  read -p "Are you sure? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo -e "${GREEN}🚀 Starting k6 Load Test${NC}"
echo "=================================="
echo "Test Type:    $TEST_TYPE"
echo "Environment:  $ENVIRONMENT"
echo "Target URL:   $BASE_URL"
echo "Results:      $RESULTS_DIR"
echo "=================================="
echo ""

# Load test credentials from .env if exists
ENV_FILE="${PROJECT_ROOT}/.env"
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Run k6 test
k6 run \
  --out json="${RESULTS_DIR}/results.json" \
  --summary-export="${RESULTS_DIR}/summary.json" \
  -e BASE_URL="$BASE_URL" \
  -e TEST_EMAIL="${TEST_EMAIL:-test@prostaff.gg}" \
  -e TEST_PASSWORD="${TEST_PASSWORD:-Test123!@#}" \
  "$TEST_FILE" | tee "${RESULTS_DIR}/output.log"

# Check exit code
if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}✅ Test completed successfully!${NC}"
  echo "Results saved to: $RESULTS_DIR"
else
  echo -e "\n${RED}❌ Test failed!${NC}"
  exit 1
fi

# Generate HTML report if k6 summary tool is available
if command -v k6-reporter &> /dev/null; then
  echo -e "\n${YELLOW}📊 Generating HTML report...${NC}"
  k6-reporter "${RESULTS_DIR}/results.json" --output "${RESULTS_DIR}/report.html"
  echo -e "${GREEN}✅ HTML report: ${RESULTS_DIR}/report.html${NC}"
fi

# Display summary
echo -e "\n${GREEN}📊 Test Summary${NC}"
echo "=================================="
if command -v jq &> /dev/null; then
  jq -r '.metrics | to_entries[] | select(.key | contains("http_req")) | "\(.key): \(.value.values)"' "${RESULTS_DIR}/summary.json" 2>/dev/null || echo "See ${RESULTS_DIR}/summary.json for details"
else
  echo "Install 'jq' for formatted summary output"
  echo "See: ${RESULTS_DIR}/summary.json"
fi
echo "=================================="
