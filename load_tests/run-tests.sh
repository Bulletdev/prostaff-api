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
  echo -e "${RED}[ERROR] Invalid test type: $TEST_TYPE${NC}"
  echo "Available tests: ${!TEST_FILES[@]}"
  exit 1
fi

# Validate environment
if [[ ! -v ENV_URLS[$ENVIRONMENT] ]]; then
  echo -e "${RED}[ERROR] Invalid environment: $ENVIRONMENT${NC}"
  echo "Available environments: ${!ENV_URLS[@]}"
  exit 1
fi

BASE_URL=${ENV_URLS[$ENVIRONMENT]}
TEST_FILE=${TEST_FILES[$TEST_TYPE]}

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}[ERROR] k6 is not installed${NC}"
    echo "Run: ./load_tests/k6-setup.sh"
    exit 1
fi

# Check if test file exists
if [[ ! -f "$TEST_FILE" ]]; then
    echo -e "${RED}[ERROR] Test file not found: $TEST_FILE${NC}"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Warning for production
if [[ "$ENVIRONMENT" == "production" ]]; then
  echo -e "${RED}[WARNING] Running load tests against PRODUCTION!${NC}"
  read -p "Are you sure? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo -e "${GREEN}[START] Starting k6 Load Test${NC}"
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

# Check k6 exit code (for script errors)
K6_EXIT_CODE=$?

# Check for threshold failures in output log (look for ✗ symbol in THRESHOLDS section)
THRESHOLDS_FAILED=0
if [[ -f "${RESULTS_DIR}/output.log" ]]; then
  # Count failed thresholds (lines with ✗ after THRESHOLDS header)
  THRESHOLDS_FAILED=$(grep -A 20 "THRESHOLDS" "${RESULTS_DIR}/output.log" | grep -c "✗" || echo 0)
fi

# Display summary
echo -e "\n${GREEN}[SUMMARY] Test Summary${NC}"
echo "=================================="
if command -v jq &> /dev/null && [[ -f "${RESULTS_DIR}/summary.json" ]]; then
  # Display key HTTP metrics
  echo "http_reqs: $(jq -r '.metrics.http_reqs.count // "N/A"' "${RESULTS_DIR}/summary.json" 2>/dev/null)"
  echo "http_req_duration avg: $(jq -r '(.metrics.http_req_duration.avg // 0) | floor' "${RESULTS_DIR}/summary.json" 2>/dev/null)ms"
  echo "http_req_duration p95: $(jq -r '(.metrics.http_req_duration."p(95)" // 0) | floor' "${RESULTS_DIR}/summary.json" 2>/dev/null)ms"
  echo "http_req_failed rate: $(jq -r '((.metrics.http_req_failed.value // 0) * 100) | floor' "${RESULTS_DIR}/summary.json" 2>/dev/null)%"
  echo "checks passed: $(jq -r '.metrics.checks.passes // "N/A"' "${RESULTS_DIR}/summary.json" 2>/dev/null)"
  echo "checks failed: $(jq -r '.metrics.checks.fails // "N/A"' "${RESULTS_DIR}/summary.json" 2>/dev/null)"
else
  echo "Install 'jq' for formatted summary output"
  echo "See: ${RESULTS_DIR}/summary.json"
fi
echo "=================================="

# Generate HTML report if k6 summary tool is available
if command -v k6-reporter &> /dev/null; then
  echo -e "\n${YELLOW}[REPORT] Generating HTML report...${NC}"
  k6-reporter "${RESULTS_DIR}/results.json" --output "${RESULTS_DIR}/report.html"
  echo -e "${GREEN}[SUCCESS] HTML report: ${RESULTS_DIR}/report.html${NC}"
fi

# Final status check
if [ $K6_EXIT_CODE -ne 0 ]; then
  echo -e "\n${RED}[FAILED] Test execution failed!${NC}"
  echo "Results saved to: $RESULTS_DIR"
  exit 1
elif [ "$THRESHOLDS_FAILED" -gt 0 ]; then
  echo -e "\n${RED}[FAILED] $THRESHOLDS_FAILED threshold(s) failed!${NC}"
  echo "Results saved to: $RESULTS_DIR"
  exit 1
else
  echo -e "\n${GREEN}[SUCCESS] Test completed successfully!${NC}"
  echo "Results saved to: $RESULTS_DIR"
fi
