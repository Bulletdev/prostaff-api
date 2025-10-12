#!/bin/bash
# OWASP ZAP Full Scan
# Active scan with authentication (use with caution)

set -e

# Find project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET_URL=${1:-"http://host.docker.internal:3333"}
REPORT_DIR="$PROJECT_ROOT/security_tests/reports/zap"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  WARNING: Full Active Scan${NC}"
echo "This will actively test for vulnerabilities and may:"
echo "  • Generate significant traffic"
echo "  • Trigger security alerts"
echo "  • Modify data in the application"
echo ""
echo "Target: $TARGET_URL"

# Confirm for non-local targets
if [[ ! "$TARGET_URL" =~ localhost|127.0.0.1|host.docker.internal ]]; then
  echo -e "${RED}⚠️  WARNING: Non-local target detected!${NC}"
  read -p "Are you sure you want to scan $TARGET_URL? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

mkdir -p "$REPORT_DIR"

echo -e "${GREEN}🔍 Starting ZAP Full Scan${NC}"

# Run ZAP full scan
docker run --rm \
  --network=host \
  -v "$(pwd)/$REPORT_DIR:/zap/wrk:rw" \
  owasp/zap2docker-stable \
  zap-full-scan.py \
  -t "$TARGET_URL" \
  -g gen.conf \
  -r "full-scan-${TIMESTAMP}.html" \
  -J "full-scan-${TIMESTAMP}.json" \
  -w "full-scan-${TIMESTAMP}.md"

echo -e "${GREEN}✅ Full scan complete!${NC}"
echo "HTML Report: $REPORT_DIR/full-scan-${TIMESTAMP}.html"
echo "JSON Report: $REPORT_DIR/full-scan-${TIMESTAMP}.json"
