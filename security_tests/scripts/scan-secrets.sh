#!/bin/bash
# Secrets Scanning
# Detects exposed secrets, API keys, tokens in code and git history

set -e

REPORT_DIR="security_tests/reports/secrets"
mkdir -p "$REPORT_DIR"

echo "Secrets Scanning"
echo "======================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running in CI
IS_CI=${CI:-false}

# 1. TruffleHog - Git history secrets
echo "[1/3] Scanning git history with TruffleHog..."
if command -v trufflehog &> /dev/null; then
  trufflehog git file://. --json --only-verified > "$REPORT_DIR/trufflehog-report.json" 2>&1 || true

  VERIFIED_SECRETS=$(jq 'select(.Verified == true)' "$REPORT_DIR/trufflehog-report.json" 2>/dev/null | jq -s 'length')

  if [ "$VERIFIED_SECRETS" -gt 0 ]; then
    echo -e "${RED}CRITICAL: Found $VERIFIED_SECRETS verified secrets in git history!${NC}"
    jq -r 'select(.Verified == true) | "  - \(.DetectorName): \(.SourceMetadata.Data.Git.file):\(.SourceMetadata.Data.Git.line)"' \
      "$REPORT_DIR/trufflehog-report.json" 2>/dev/null || true
  else
    echo -e "${GREEN}No verified secrets found in git history${NC}"
  fi
else
  echo -e "${YELLOW}TruffleHog not installed - skipping${NC}"
  echo "Install: brew install trufflehog (macOS) or docker pull trufflesecurity/trufflehog"
fi

echo ""

# 2. Gitleaks - Alternative secrets scanner
echo "[2/3] Scanning with Gitleaks..."
if command -v gitleaks &> /dev/null; then
  gitleaks detect --source . --report-path "$REPORT_DIR/gitleaks-report.json" --no-git || true

  if [ -f "$REPORT_DIR/gitleaks-report.json" ]; then
    LEAKS_COUNT=$(jq 'length' "$REPORT_DIR/gitleaks-report.json" 2>/dev/null || echo "0")

    if [ "$LEAKS_COUNT" -gt 0 ]; then
      echo -e "${RED}CRITICAL: Found $LEAKS_COUNT potential secrets!${NC}"
      jq -r '.[] | "  - \(.RuleID): \(.File):\(.StartLine)"' "$REPORT_DIR/gitleaks-report.json" 2>/dev/null || true
    else
      echo -e "${GREEN}No secrets found${NC}"
    fi
  else
    echo -e "${GREEN}No secrets found${NC}"
  fi
else
  echo -e "${YELLOW}Gitleaks not installed - skipping${NC}"
  echo "Install: brew install gitleaks (macOS) or docker pull zricethezav/gitleaks"
fi

echo ""

# 3. Pattern-based search (fallback)
echo "[3/3] Pattern-based secret search..."

PATTERNS=(
  "password\s*=\s*['\"](?!.*Test123)([^'\"]+)['\"]"
  "api[_-]?key\s*=\s*['\"]([^'\"]+)['\"]"
  "secret[_-]?key\s*=\s*['\"]([^'\"]+)['\"]"
  "access[_-]?token\s*=\s*['\"]([^'\"]+)['\"]"
  "private[_-]?key\s*=\s*['\"]([^'\"]+)['\"]"
  "aws[_-]?access[_-]?key[_-]?id\s*=\s*['\"]([^'\"]+)['\"]"
  "AKIA[0-9A-Z]{16}"
  "sk_live_[0-9a-zA-Z]{24}"
  "gh[ps]_[0-9a-zA-Z]{36}"
)

SUSPICIOUS_FILES=()

for pattern in "${PATTERNS[@]}"; do
  MATCHES=$(grep -rEn "$pattern" app/ config/ lib/ 2>/dev/null | grep -v "brakeman:ignore" | grep -v "# nosemgrep" || true)

  if [ -n "$MATCHES" ]; then
    echo -e "${YELLOW}Found potential secrets matching: $pattern${NC}"
    echo "$MATCHES" | while read -r line; do
      echo "  $line"
      FILE=$(echo "$line" | cut -d: -f1)
      SUSPICIOUS_FILES+=("$FILE")
    done
  fi
done

if [ ${#SUSPICIOUS_FILES[@]} -eq 0 ]; then
  echo -e "${GREEN}No suspicious patterns found${NC}"
fi

echo ""

# 4. Check for common secrets files
echo "Checking for exposed secrets files..."
EXPOSED_FILES=()

SECRET_FILES=(
  ".env"
  ".env.local"
  ".env.production"
  "config/master.key"
  "config/credentials.yml.enc"
  "config/database.yml"
  "id_rsa"
  "id_dsa"
  "*.pem"
  "*.p12"
  "*.key"
)

for file in "${SECRET_FILES[@]}"; do
  if git ls-files --error-unmatch "$file" 2>/dev/null; then
    EXPOSED_FILES+=("$file")
    echo -e "${RED}CRITICAL: $file is tracked in git!${NC}"
  fi
done

if [ ${#EXPOSED_FILES[@]} -eq 0 ]; then
  echo -e "${GREEN}No sensitive files in git${NC}"
fi

echo ""

# Generate summary report
cat > "$REPORT_DIR/secrets-summary.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scans": {
    "trufflehog": {
      "ran": $([ -f "$REPORT_DIR/trufflehog-report.json" ] && echo "true" || echo "false"),
      "verified_secrets": ${VERIFIED_SECRETS:-0}
    },
    "gitleaks": {
      "ran": $([ -f "$REPORT_DIR/gitleaks-report.json" ] && echo "true" || echo "false"),
      "potential_leaks": ${LEAKS_COUNT:-0}
    },
    "pattern_search": {
      "ran": true,
      "suspicious_files_count": ${#SUSPICIOUS_FILES[@]}
    },
    "exposed_files": {
      "count": ${#EXPOSED_FILES[@]},
      "files": $(printf '%s\n' "${EXPOSED_FILES[@]}" | jq -R . | jq -s .)
    }
  },
  "status": "$([ ${VERIFIED_SECRETS:-0} -gt 0 ] || [ ${LEAKS_COUNT:-0} -gt 0 ] || [ ${#EXPOSED_FILES[@]} -gt 0 ] && echo "FAILED" || echo "PASSED")"
}
EOF

echo "======================================"
echo "SUMMARY"
echo "======================================"
cat "$REPORT_DIR/secrets-summary.json" | jq .
echo ""
echo "Reports saved to: $REPORT_DIR/"

# Exit with error if secrets found
if [ "${VERIFIED_SECRETS:-0}" -gt 0 ] || [ "${LEAKS_COUNT:-0}" -gt 0 ] || [ ${#EXPOSED_FILES[@]} -gt 0 ]; then
  echo ""
  echo -e "${RED}SECURITY RISK: Secrets detected!${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}SUCCESS: No secrets detected${NC}"
  exit 0
fi
