#!/bin/bash
# OWASP ZAP API Scan
# Scans API using OpenAPI/Swagger definition

set -e

# Find project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET_URL=${1:-"http://host.docker.internal:3333"}
API_SPEC=${2:-"http://host.docker.internal:3333/api-docs/v1/swagger.json"}
REPORT_DIR="$PROJECT_ROOT/security_tests/reports/zap"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔍 Starting ZAP API Scan${NC}"
echo "Target: $TARGET_URL"
echo "API Spec: $API_SPEC"
echo "Reports: $REPORT_DIR"

mkdir -p "$REPORT_DIR"

# Run ZAP API scan
docker run --rm \
  --network=host \
  -v "$(pwd)/$REPORT_DIR:/zap/wrk:rw" \
  owasp/zap2docker-stable \
  zap-api-scan.py \
  -t "$API_SPEC" \
  -f openapi \
  -g gen.conf \
  -r "api-scan-${TIMESTAMP}.html" \
  -J "api-scan-${TIMESTAMP}.json" \
  -w "api-scan-${TIMESTAMP}.md"

echo -e "${GREEN}✅ API scan complete!${NC}"
echo "HTML Report: $REPORT_DIR/api-scan-${TIMESTAMP}.html"
echo "JSON Report: $REPORT_DIR/api-scan-${TIMESTAMP}.json"
