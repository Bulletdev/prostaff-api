#!/bin/bash
# Dependency Vulnerability Scanner
# Checks Gemfile.lock for known vulnerabilities

set -e

# Find project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

REPORT_DIR="$PROJECT_ROOT/security_tests/reports/dependency-check"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔍 Scanning Dependencies for Vulnerabilities${NC}"

mkdir -p "$REPORT_DIR"

# Method 1: Bundler Audit (fastest)
if command -v bundle-audit &> /dev/null; then
  echo -e "${YELLOW}Running Bundler Audit...${NC}"

  bundle-audit check --update 2>&1 | tee "$REPORT_DIR/bundler-audit-${TIMESTAMP}.txt"
else
  echo -e "${YELLOW}Installing bundle-audit...${NC}"
  gem install bundler-audit
  bundle-audit check --update 2>&1 | tee "$REPORT_DIR/bundler-audit-${TIMESTAMP}.txt"
fi

# Method 2: OWASP Dependency Check (comprehensive)
echo -e "${YELLOW}Running OWASP Dependency Check...${NC}"

docker run --rm \
  -v "$(pwd):/src:ro" \
  -v "$(pwd)/$REPORT_DIR:/report:rw" \
  owasp/dependency-check:latest \
  --scan /src/Gemfile.lock \
  --format ALL \
  --project "ProStaff API" \
  --out /report/owasp-${TIMESTAMP}

echo -e "${GREEN}✅ Dependency scan complete!${NC}"
echo "Bundler Audit: $REPORT_DIR/bundler-audit-${TIMESTAMP}.txt"
echo "OWASP Report: $REPORT_DIR/owasp-${TIMESTAMP}/"

if grep -q "Vulnerabilities found!" "$REPORT_DIR/bundler-audit-${TIMESTAMP}.txt" 2>/dev/null; then
  echo -e "\n${YELLOW}⚠️  Vulnerabilities detected! Review reports.${NC}"
  exit 1
else
  echo -e "\n${GREEN}✅ No known vulnerabilities found${NC}"
fi
