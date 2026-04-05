#!/bin/bash
# SSRF Protection Security Test
# Tests for Server-Side Request Forgery vulnerabilities

set -e

API_URL="${API_URL:-http://localhost:3333}"
REPORT_DIR="security_tests/reports/ssrf"

echo "SSRF Protection Security Test"
echo "======================================"
echo "API URL: $API_URL"
echo ""

mkdir -p "$REPORT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_result() {
  TEST_NAME=$1
  STATUS=$2
  DETAILS=$3

  TOTAL=$((TOTAL + 1))

  if [ "$STATUS" = "PASS" ]; then
    echo -e "${GREEN}[PASS]${NC} $TEST_NAME"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}[FAIL]${NC} $TEST_NAME"
    echo "       Details: $DETAILS"
    FAILED=$((FAILED + 1))
  fi
}

# Authenticate — try login with fixed test user first, register only if needed
FIXED_EMAIL="${TEST_EMAIL:-sectest@prostaff-security.invalid}"
FIXED_PASSWORD="${TEST_PASSWORD:-Test123!@#}"

echo "Setting up test user..."
AUTH_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$FIXED_EMAIL\",\"password\":\"$FIXED_PASSWORD\"}")

TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.access_token // empty')

if [ -z "$TOKEN" ]; then
  # User does not exist yet — register once
  AUTH_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"email\": \"$FIXED_EMAIL\",
        \"password\": \"$FIXED_PASSWORD\",
        \"full_name\": \"SSRF Test User\"
      },
      \"organization\": {
        \"name\": \"SSRF Test Org\",
        \"region\": \"BR\"
      }
    }")
  TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.access_token // empty')
fi

if [ -z "$TOKEN" ]; then
  echo "FATAL: Failed to authenticate"
  echo "Response: $AUTH_RESPONSE"
  exit 1
fi

echo "Token obtained: ${TOKEN:0:20}..."
echo ""
echo "Running SSRF protection tests..."
echo ""

# TEST 1: Block localhost access
echo "[TEST 1] Block localhost access"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=http://localhost:6379" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks localhost access" "PASS" ""
else
  test_result "Blocks localhost access" "FAIL" "HTTP $HTTP_CODE - should be 400/403"
fi

# TEST 2: Block 127.0.0.1
echo "[TEST 2] Block 127.0.0.1"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=http://127.0.0.1:6379" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks 127.0.0.1" "PASS" ""
else
  test_result "Blocks 127.0.0.1" "FAIL" "HTTP $HTTP_CODE"
fi

# TEST 3: Block private IP (10.x.x.x)
echo "[TEST 3] Block private IP 10.0.0.1"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=http://10.0.0.1" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks 10.0.0.1 (private IP)" "PASS" ""
else
  test_result "Blocks 10.0.0.1" "FAIL" "HTTP $HTTP_CODE"
fi

# TEST 4: Block private IP (192.168.x.x)
echo "[TEST 4] Block private IP 192.168.1.1"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=http://192.168.1.1" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks 192.168.1.1 (private IP)" "PASS" ""
else
  test_result "Blocks 192.168.1.1" "FAIL" "HTTP $HTTP_CODE"
fi

# TEST 5: Block AWS metadata endpoint
echo "[TEST 5] Block AWS metadata endpoint"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=http://169.254.169.254/latest/meta-data/" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks AWS metadata (169.254.169.254)" "PASS" ""
else
  test_result "Blocks AWS metadata" "FAIL" "HTTP $HTTP_CODE"
fi

# TEST 6: Block unauthorized domain
echo "[TEST 6] Block unauthorized domain"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=https://evil.com/malware.png" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks unauthorized domain (evil.com)" "PASS" ""
else
  test_result "Blocks unauthorized domain" "FAIL" "HTTP $HTTP_CODE"
fi

# TEST 7: Block subdomain bypass attempt
echo "[TEST 7] Block subdomain bypass"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=https://upload.wikimedia.org.attacker.com/test.png" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks subdomain bypass (.org.attacker.com)" "PASS" ""
else
  test_result "Blocks subdomain bypass" "FAIL" "HTTP $HTTP_CODE"
fi

# TEST 8: Block HTTP (only HTTPS allowed)
echo "[TEST 8] Block HTTP (enforce HTTPS)"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=http://upload.wikimedia.org/test.png" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Blocks HTTP (only HTTPS allowed)" "PASS" ""
else
  test_result "Blocks HTTP" "FAIL" "HTTP $HTTP_CODE - should enforce HTTPS"
fi

# TEST 9: Allow valid HTTPS domain
echo "[TEST 9] Allow valid HTTPS domain"
RESULT=$(curl -s -w "\n%{http_code}" "$API_URL/api/v1/images/proxy?url=https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/React-icon.svg/120px-React-icon.svg.png" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESULT" | tail -n1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "502" ]; then
  # 502 is OK (external service down), importante é não ser 400/403
  test_result "Allows valid HTTPS domain (wikimedia)" "PASS" ""
else
  test_result "Allows valid HTTPS domain" "FAIL" "HTTP $HTTP_CODE - should allow valid domain"
fi

# Summary
echo ""
echo "======================================"
echo "SUMMARY"
echo "======================================"
echo -e "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

# Generate JSON report
cat > "$REPORT_DIR/ssrf-report.json" <<EOF
{
  "test_suite": "SSRF Protection",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_tests": $TOTAL,
  "passed": $PASSED,
  "failed": $FAILED,
  "pass_rate": $(echo "scale=2; $PASSED * 100 / $TOTAL" | bc),
  "endpoint_tested": "/api/v1/images/proxy"
}
EOF

echo ""
echo "Report saved to: $REPORT_DIR/ssrf-report.json"

if [ $FAILED -gt 0 ]; then
  echo ""
  echo -e "${RED}SECURITY RISK: SSRF protection tests FAILED${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}SUCCESS: All SSRF protection tests passed${NC}"
  exit 0
fi
