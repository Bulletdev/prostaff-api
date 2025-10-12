#!/bin/bash
# Brakeman Rails Security Scanner

set -e

# Find project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

REPORT_DIR="$PROJECT_ROOT/security_tests/reports/brakeman"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔍 Running Brakeman Security Scan${NC}"

mkdir -p "$REPORT_DIR"

if command -v brakeman &> /dev/null; then
  echo -e "${YELLOW}Using local Brakeman installation${NC}"

  brakeman \
    --rails7 \
    --output "$REPORT_DIR/brakeman-${TIMESTAMP}.html" \
    --format html \
    --summary

  brakeman \
    --rails7 \
    --output "$REPORT_DIR/brakeman-${TIMESTAMP}.json" \
    --format json
else
  echo -e "${YELLOW}Using Brakeman Docker image${NC}"

  docker run --rm \
    -v "$(pwd):/app:ro" \
    -v "$(pwd)/$REPORT_DIR:/reports:rw" \
    presidentbeef/brakeman:latest \
    --rails7 \
    --output "/reports/brakeman-${TIMESTAMP}.html" \
    --format html \
    --summary

  docker run --rm \
    -v "$(pwd):/app:ro" \
    -v "$(pwd)/$REPORT_DIR:/reports:rw" \
    presidentbeef/brakeman:latest \
    --rails7 \
    --output "/reports/brakeman-${TIMESTAMP}.json" \
    --format json
fi

echo -e "${GREEN}✅ Brakeman scan complete!${NC}"
echo "HTML Report: $REPORT_DIR/brakeman-${TIMESTAMP}.html"
echo "JSON Report: $REPORT_DIR/brakeman-${TIMESTAMP}.json"

if command -v jq &> /dev/null && [ -f "$REPORT_DIR/brakeman-${TIMESTAMP}.json" ]; then
  echo ""
  echo "=== Security Issues Summary ==="
  jq -r '
    "Total Warnings: \(.warnings | length)",
    "High Confidence: \([.warnings[] | select(.confidence == "High")] | length)",
    "Medium Confidence: \([.warnings[] | select(.confidence == "Medium")] | length)",
    "Low Confidence: \([.warnings[] | select(.confidence == "Low")] | length)"
  ' "$REPORT_DIR/brakeman-${TIMESTAMP}.json"
fi
