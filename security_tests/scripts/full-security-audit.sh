#!/bin/bash
# Complete Security Audit

set -e

# Find project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_URL=${1:-"http://localhost:3333"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="$PROJECT_ROOT/security_tests/reports/audit-${TIMESTAMP}"

mkdir -p "$REPORT_DIR"

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ProStaff API Security Audit             ║${NC}"
echo -e "${BLUE}║   $(date)                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo "Target: $TARGET_URL"
echo "Reports: $REPORT_DIR"
echo ""

# Check if API is running
echo -e "${YELLOW}Checking if API is accessible...${NC}"
if ! curl -sf "$TARGET_URL/up" > /dev/null; then
  echo -e "${RED}❌ API is not accessible at $TARGET_URL${NC}"
  echo "Please start the API first:"
  echo "  bundle exec rails server"
  exit 1
fi
echo -e "${GREEN}✅ API is running${NC}\n"

# 1. Static Code Analysis - Brakeman
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[1/6] Running Brakeman (Rails Security Scanner)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/brakeman-scan.sh"
cp "$PROJECT_ROOT/security_tests/reports/brakeman/brakeman-"*.{html,json} "$REPORT_DIR/" 2>/dev/null || true
echo ""

# 2. Dependency Vulnerabilities
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[2/6] Checking Dependencies for Vulnerabilities${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/dependency-scan.sh" || true
cp "$PROJECT_ROOT/security_tests/reports/dependency-check/"* "$REPORT_DIR/" 2>/dev/null || true
echo ""

# 3. Secret Detection
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[3/6] Scanning for Exposed Secrets${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check for common secret patterns
echo "Checking for exposed secrets in code..."
SECRETS_FOUND=false

# API keys
if grep -r -E "api_key.*=.*['\"][a-zA-Z0-9]{20,}['\"]" app/ config/ --exclude-dir=node_modules 2>/dev/null; then
  echo -e "${RED}⚠️  Potential API keys found in code${NC}"
  SECRETS_FOUND=true
fi

# JWT secrets
if grep -r -E "jwt.*secret.*=.*['\"][a-zA-Z0-9]{20,}['\"]" app/ config/ --exclude-dir=node_modules 2>/dev/null; then
  echo -e "${RED}⚠️  Potential JWT secrets found in code${NC}"
  SECRETS_FOUND=true
fi

# Check .env file is gitignored
if [ -f ".env" ] && ! grep -q "^\.env$" .gitignore; then
  echo -e "${RED}⚠️  .env file exists but not in .gitignore${NC}"
  SECRETS_FOUND=true
fi

if [ "$SECRETS_FOUND" = false ]; then
  echo -e "${GREEN}✅ No exposed secrets found${NC}"
fi
echo ""

# 4. ZAP Baseline Scan
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[4/6] OWASP ZAP Baseline Scan${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/zap-baseline-scan.sh" "$TARGET_URL" || true
cp "$PROJECT_ROOT/security_tests/reports/zap/baseline-scan-"*.{html,json} "$REPORT_DIR/" 2>/dev/null || true
echo ""

# 5. ZAP API Scan
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[5/6] OWASP ZAP API Scan${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/zap-api-scan.sh" "$TARGET_URL" "${TARGET_URL}/api-docs/v1/swagger.json" || true
cp "$PROJECT_ROOT/security_tests/reports/zap/api-scan-"*.{html,json} "$REPORT_DIR/" 2>/dev/null || true
echo ""

# 6. Security Headers Check
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[6/6] Checking Security Headers${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

HEADERS_REPORT="$REPORT_DIR/security-headers.txt"
echo "Security Headers Analysis" > "$HEADERS_REPORT"
echo "=========================" >> "$HEADERS_REPORT"
echo "Target: $TARGET_URL" >> "$HEADERS_REPORT"
echo "Date: $(date)" >> "$HEADERS_REPORT"
echo "" >> "$HEADERS_REPORT"

RESPONSE=$(curl -sI "$TARGET_URL/up")

check_header() {
  local header=$1
  local expected=$2

  if echo "$RESPONSE" | grep -qi "^$header:"; then
    echo -e "${GREEN}✅ $header present${NC}"
    echo "[PASS] $header present" >> "$HEADERS_REPORT"
  else
    echo -e "${YELLOW}⚠️  $header missing${NC}"
    echo "[WARN] $header missing - Expected: $expected" >> "$HEADERS_REPORT"
  fi
}

check_header "X-Frame-Options" "DENY or SAMEORIGIN"
check_header "X-Content-Type-Options" "nosniff"
check_header "X-XSS-Protection" "1; mode=block"
check_header "Strict-Transport-Security" "max-age=31536000"
check_header "Content-Security-Policy" "default-src 'self'"
check_header "Referrer-Policy" "no-referrer or strict-origin-when-cross-origin"

echo ""

# Generate summary report
SUMMARY_REPORT="$REPORT_DIR/SECURITY_AUDIT_SUMMARY.md"

cat > "$SUMMARY_REPORT" << EOF
# ProStaff API Security Audit Summary

**Date:** $(date)
**Target:** $TARGET_URL
**Audit ID:** $TIMESTAMP

## Scans Performed

1. ✅ Brakeman (Rails Security Scanner)
2. ✅ Dependency Vulnerability Check
3. ✅ Secret Detection
4. ✅ OWASP ZAP Baseline Scan
5. ✅ OWASP ZAP API Scan
6. ✅ Security Headers Check

## Quick Findings

### Critical Issues
$(grep -i "critical\|high" "$REPORT_DIR"/*.json 2>/dev/null | wc -l) potential critical/high severity issues found

### Recommendations

Review the following reports for details:
- \`brakeman-*.html\` - Rails code security issues
- \`baseline-scan-*.html\` - Web application vulnerabilities
- \`api-scan-*.html\` - API-specific security issues
- \`bundler-audit-*.txt\` - Dependency vulnerabilities
- \`security-headers.txt\` - Missing security headers

## Next Steps

1. Review all generated reports
2. Prioritize fixes by severity
3. Update vulnerable dependencies
4. Add missing security headers
5. Re-run audit after fixes

---
*Generated by ProStaff Security Testing Suite*
EOF

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Security Audit Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "All reports saved to: $REPORT_DIR"
echo "Summary: $SUMMARY_REPORT"
echo ""
echo "View HTML reports:"
echo "  • Brakeman: open $REPORT_DIR/brakeman-*.html"
echo "  • ZAP Baseline: open $REPORT_DIR/baseline-scan-*.html"
echo "  • ZAP API: open $REPORT_DIR/api-scan-*.html"
