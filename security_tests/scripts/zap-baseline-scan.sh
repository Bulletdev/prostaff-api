#!/bin/bash
# OWASP ZAP Baseline Scan
# Quick passive scan for common vulnerabilities

set -e

# Find project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET_URL=${1:-"http://host.docker.internal:3333"}
REPORT_DIR="$PROJECT_ROOT/security_tests/reports/zap"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔍 Starting ZAP Baseline Scan${NC}"
echo "Target: $TARGET_URL"
echo "Reports: $REPORT_DIR"

mkdir -p "$REPORT_DIR"

# Run ZAP baseline scan
docker run --rm \
  --network=host \
  -v "$(pwd)/$REPORT_DIR:/zap/wrk:rw" \
  owasp/zap2docker-stable \
  zap-baseline.py \
  -t "$TARGET_URL" \
  -g gen.conf \
  -r "baseline-scan-${TIMESTAMP}.html" \
  -J "baseline-scan-${TIMESTAMP}.json" \
  -w "baseline-scan-${TIMESTAMP}.md"

echo -e "${GREEN}✅ Baseline scan complete!${NC}"
echo "HTML Report: $REPORT_DIR/baseline-scan-${TIMESTAMP}.html"
echo "JSON Report: $REPORT_DIR/baseline-scan-${TIMESTAMP}.json"
