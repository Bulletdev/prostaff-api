#!/bin/bash
# ProStaff API - Application-Specific Security Tests
# Runs tests for multi-tenancy, SSRF, secrets, and other app-specific vulnerabilities

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="security_tests/reports"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      ProStaff API - Application Security Test Suite           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_PASSED=0
TOTAL_FAILED=0

run_test() {
  TEST_NAME=$1
  SCRIPT=$2

  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Running: $TEST_NAME${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if [ ! -f "$SCRIPT" ]; then
    echo -e "${RED}[SKIP]${NC} Script not found: $SCRIPT"
    return
  fi

  if bash "$SCRIPT"; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} $TEST_NAME passed"
    TOTAL_PASSED=$((TOTAL_PASSED + 1))
  else
    echo ""
    echo -e "${RED}[FAILED]${NC} $TEST_NAME failed"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
  fi
}

# Check if API is running
echo "Checking if API is running..."
if ! curl -s http://localhost:3333/up > /dev/null 2>&1; then
  echo -e "${YELLOW}WARNING: API is not running at http://localhost:3333${NC}"
  echo ""
  echo "Start the API first:"
  echo "  docker compose up -d"
  echo ""
  echo "Some tests will be skipped..."
  echo ""
fi

# Run tests
run_test "Multi-Tenancy Isolation" "$SCRIPT_DIR/test-multi-tenancy-isolation.sh"
run_test "SSRF Protection" "$SCRIPT_DIR/test-ssrf-protection.sh"
run_test "Secrets Scanning" "$SCRIPT_DIR/scan-secrets.sh"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        FINAL SUMMARY                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "Total suites run: $((TOTAL_PASSED + TOTAL_FAILED))"
echo -e "${GREEN}Passed: $TOTAL_PASSED${NC}"
echo -e "${RED}Failed: $TOTAL_FAILED${NC}"
echo ""

if [ $TOTAL_FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All application security tests passed!${NC}"
  echo ""
  echo "Reports available at:"
  echo "  - $REPORT_DIR/multi-tenancy/multi-tenancy-report.json"
  echo "  - $REPORT_DIR/ssrf/ssrf-report.json"
  echo "  - $REPORT_DIR/secrets/secrets-summary.json"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Some tests failed. Review reports in $REPORT_DIR/${NC}"
  echo ""
  echo "Critical issues found. Please fix before deploying to production."
  echo ""
  exit 1
fi
