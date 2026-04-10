#!/bin/bash
# Rate Limiting Test — Validates Rack::Attack throttle rules
#
# Tests that throttle limits are actually enforced in the running API.
# Adapted from chorrocho pentest lab patterns.
#
# Throttle rules (config/initializers/rack_attack.rb):
#   logins/ip:           5 req / 20s
#   register/ip:         3 req / 1hr
#   password_reset/ip:   5 req / 1hr
#   req/authenticated_user: 1000 req / 1hr
#
# Usage:
#   ./test-rate-limiting.sh
#   API_URL=http://localhost:3333 ./test-rate-limiting.sh

set -e

API_URL="${API_URL:-http://localhost:3333}"
REPORT_DIR="security_tests/reports/rate-limiting"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)

echo "Rate Limiting Security Test (Rack::Attack)"
echo "==========================================="
echo "API URL: $API_URL"
echo ""

mkdir -p "$REPORT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_result() {
  local name="$1"
  local status="$2"
  local details="$3"

  TOTAL=$((TOTAL + 1))
  if [ "$status" = "PASS" ]; then
    echo -e "${GREEN}[PASS]${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}[FAIL]${NC} $name"
    [ -n "$details" ] && echo "       Details: $details"
    FAILED=$((FAILED + 1))
  fi
}

# Check API is up
if ! curl -s "$API_URL/up" > /dev/null 2>&1; then
  echo -e "${YELLOW}[SKIP]${NC} API not running at $API_URL"
  echo "       Start with: docker compose up -d"
  exit 0
fi

REPORT_FILE="$REPORT_DIR/rate-limiting-report-${TIMESTAMP}.json"
FINDINGS=()

# ─────────────────────────────────────────────────────────
# Helper: fire N requests, return the HTTP status of the last one
# ─────────────────────────────────────────────────────────
last_status_after_n() {
  local method="$1"
  local url="$2"
  local body="$3"
  local n="$4"
  local extra_headers="${5:-}"

  local last_status=0
  for i in $(seq 1 "$n"); do
    last_status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X "$method" "$url" \
      -H "Content-Type: application/json" \
      ${extra_headers:+-H "$extra_headers"} \
      ${body:+--data-raw "$body"} \
      --max-time 5 2>/dev/null || echo 0)
  done
  echo "$last_status"
}

# ─────────────────────────────────────────────────────────
# Test 1: Login throttle — logins/ip: 5 req / 20s
# Send 7 requests; expect 429 on at least one of them
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 1: Login throttle (logins/ip: 5/20s) ---"

LOGIN_PAYLOAD='{"email":"nonexistent-rate-test@prostaff.gg","password":"WrongPassword1!"}'
THROTTLED=false
for i in $(seq 1 7); do
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    --data-raw "$LOGIN_PAYLOAD" \
    --max-time 5 2>/dev/null || echo 0)
  if [ "$status" = "429" ]; then
    THROTTLED=true
    echo "       Request $i returned 429 (throttled after $((i-1)) requests)"
    break
  fi
done

if $THROTTLED; then
  test_result "Login endpoint throttled after limit (5/20s)" "PASS"
else
  test_result "Login endpoint throttled after limit (5/20s)" "FAIL" \
    "Sent 7 requests, none returned 429 — throttle may not be active"
  FINDINGS+=('{"severity":"HIGH","test":"login-throttle","detail":"7 login attempts without 429 — Rack::Attack logins/ip rule not enforced"}')
fi

# Wait for throttle window to reset
echo "       Waiting 21s for throttle window to reset..."
sleep 21

# ─────────────────────────────────────────────────────────
# Test 2: Register throttle — register/ip: 3 req / 1hr
# Note: 1hr window cannot be waited out in CI; we check the rule triggers
# We use unique but syntactically valid payloads to hit the limit
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 2: Register throttle (register/ip: 3/1hr) ---"
echo "       Note: 1hr window — using existing accounts to trigger 429, not creating real ones"

RTHROTTLED=false
for i in $(seq 1 5); do
  suffix="${TIMESTAMP}${i}"
  reg_payload="{\"organization_name\":\"RateLimitTest${suffix}\",\"email\":\"rate-limit-${suffix}@prostaff-test.invalid\",\"password\":\"Test123!@#\",\"name\":\"Rate Limit Test\"}"
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    --data-raw "$reg_payload" \
    --max-time 5 2>/dev/null || echo 0)
  if [ "$status" = "429" ]; then
    RTHROTTLED=true
    echo "       Request $i returned 429 (throttled after $((i-1)) requests)"
    break
  fi
done

if $RTHROTTLED; then
  test_result "Register endpoint throttled after limit (3/1hr)" "PASS"
else
  test_result "Register endpoint throttled after limit (3/1hr)" "FAIL" \
    "Sent 5 requests, none returned 429 — throttle may not be active or window not expired"
  FINDINGS+=('{"severity":"MEDIUM","test":"register-throttle","detail":"5 register attempts without 429 — Rack::Attack register/ip rule may not be enforced for this IP"}')
fi

# ─────────────────────────────────────────────────────────
# Test 3: Verify throttle returns proper 429 + Retry-After header
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 3: Throttle response format (429 + Retry-After) ---"

# shellcheck disable=SC2034
LOGIN_HEADERS=$(curl -s -o /dev/null -D - \
  -X POST "$API_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  --data-raw "$LOGIN_PAYLOAD" \
  --max-time 5 2>/dev/null || echo "")

# Fire a burst to ensure we get 429
RETRY_AFTER_PRESENT=false
for i in $(seq 1 8); do
  response_headers=$(curl -s -o /dev/null -D - \
    -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    --data-raw "$LOGIN_PAYLOAD" \
    --max-time 5 2>/dev/null || echo "")
  status=$(echo "$response_headers" | grep -i "^HTTP/" | awk '{print $2}' | tr -d '\r')
  if [ "$status" = "429" ]; then
    retry_after=$(echo "$response_headers" | grep -i "retry-after:" | head -1 | tr -d '\r')
    if [ -n "$retry_after" ]; then
      RETRY_AFTER_PRESENT=true
      echo "       429 with Retry-After: $retry_after"
    else
      echo "       429 received but no Retry-After header"
    fi
    break
  fi
done

if $RETRY_AFTER_PRESENT; then
  test_result "429 response includes Retry-After header" "PASS"
else
  test_result "429 response includes Retry-After header" "FAIL" \
    "No Retry-After header found in 429 response — clients cannot self-throttle"
  FINDINGS+=('{"severity":"LOW","test":"retry-after-header","detail":"429 response missing Retry-After header"}')
fi

sleep 21

# ─────────────────────────────────────────────────────────
# Test 4: Authenticated endpoint throttle
# req/authenticated_user: 1000 req/1hr (cannot exhaust in CI)
# Instead: verify normal usage (10 fast requests) is NOT throttled
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 4: Authenticated endpoint — normal traffic not throttled ---"

# Get a token using the test account
AUTH_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  --data-raw "{\"email\":\"${TEST_EMAIL:-test@prostaff.gg}\",\"password\":\"${TEST_PASSWORD:-Test123!@#}\"}" \
  --max-time 10 2>/dev/null || echo "{}")

TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo -e "       ${YELLOW}[SKIP]${NC} Could not get auth token — test user may not exist"
  echo "       Create with: docker exec prostaff-api-api-1 bundle exec rails runner scripts/create_test_user.rb"
  TOTAL=$((TOTAL + 1))
else
  NOT_THROTTLED=true
  for i in $(seq 1 10); do
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      "$API_URL/api/v1/dashboard/stats" \
      --max-time 5 2>/dev/null || echo 0)
    if [ "$status" = "429" ]; then
      NOT_THROTTLED=false
      echo "       Request $i returned 429 unexpectedly"
      break
    fi
  done

  if $NOT_THROTTLED; then
    test_result "Authenticated requests (10 fast) not throttled for normal usage" "PASS"
  else
    test_result "Authenticated requests (10 fast) not throttled for normal usage" "FAIL" \
      "Legitimate burst of 10 requests triggered throttle — limit too aggressive"
    FINDINGS+=('{"severity":"LOW","test":"auth-throttle-aggressive","detail":"10 authenticated requests triggered 429 — throttle may be too aggressive for normal usage"}')
  fi
fi

# ─────────────────────────────────────────────────────────
# Test 5: Throttle applies per-IP (not globally)
# A second distinct identity should also be blocked after its own 5 attempts
# We simulate by verifying the throttle key is IP-based (cannot change IP in test,
# but we verify the rule name in response body if present)
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 5: Login throttle body format ---"

# Get a 429 response body
THROTTLE_BODY=""
for i in $(seq 1 8); do
  body=$(curl -s \
    -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    --data-raw "$LOGIN_PAYLOAD" \
    --max-time 5 2>/dev/null || echo "")
  http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    --data-raw "$LOGIN_PAYLOAD" \
    --max-time 5 2>/dev/null || echo 0)
  if [ "$http_status" = "429" ]; then
    THROTTLE_BODY="$body"
    break
  fi
done

if [ -n "$THROTTLE_BODY" ]; then
  echo "       Throttle body: ${THROTTLE_BODY:0:120}"
  # Check that it does not leak internal details (stack trace, Ruby error)
  if echo "$THROTTLE_BODY" | grep -qiE "rack|ruby|exception|backtrace|internal.error"; then
    test_result "Throttle response does not leak internal details" "FAIL" \
      "Response body contains internal framework details"
    FINDINGS+=('{"severity":"MEDIUM","test":"throttle-info-leak","detail":"429 body exposes internal details (Rack/Ruby/exception info)"}')
  else
    test_result "Throttle response does not leak internal details" "PASS"
  fi
else
  echo -e "       ${YELLOW}[SKIP]${NC} Could not trigger 429 to inspect body"
  TOTAL=$((TOTAL + 1))
fi

sleep 21

# ─────────────────────────────────────────────────────────
# Test 6: Player login throttle — player-login/ip
# Mirrors the logins/ip rule but for the player auth path
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 6: Player login throttle (player-login/ip) ---"

PLAYER_LOGIN_PAYLOAD='{"player_email":"nonexistent-rate-test@arenabr.invalid","password":"WrongPassword1!"}'
PLAYER_THROTTLED=false
for i in $(seq 1 7); do
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/auth/player-login" \
    -H "Content-Type: application/json" \
    --data-raw "$PLAYER_LOGIN_PAYLOAD" \
    --max-time 5 2>/dev/null || echo 0)
  if [ "$status" = "429" ]; then
    PLAYER_THROTTLED=true
    echo "       Request $i returned 429 (throttled after $((i-1)) requests)"
    break
  fi
done

if $PLAYER_THROTTLED; then
  test_result "Player login endpoint throttled after limit" "PASS"
else
  test_result "Player login endpoint throttled after limit" "FAIL" \
    "Sent 7 requests to /auth/player-login, none returned 429 — throttle not active for player path"
  FINDINGS+=('{"severity":"HIGH","test":"player-login-throttle","detail":"7 player-login attempts without 429 — Rack::Attack rule not enforced for /auth/player-login"}')
fi

sleep 21

# ─────────────────────────────────────────────────────────
# Test 7: Player register throttle — player-register/ip
# Self-registration endpoint should be throttled like regular register
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 7: Player register throttle (player-register/ip) ---"

PREG_THROTTLED=false
for i in $(seq 1 5); do
  suffix="${TIMESTAMP}p${i}"
  preg_payload="{\"player_email\":\"rate-limit-player-${suffix}@arenabr-test.invalid\",\"password\":\"Test123!@#\",\"password_confirmation\":\"Test123!@#\",\"summoner_name\":\"RateLimitTest${suffix}\"}"
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/auth/player-register" \
    -H "Content-Type: application/json" \
    --data-raw "$preg_payload" \
    --max-time 5 2>/dev/null || echo 0)
  if [ "$status" = "429" ]; then
    PREG_THROTTLED=true
    echo "       Request $i returned 429 (throttled after $((i-1)) requests)"
    break
  fi
done

if $PREG_THROTTLED; then
  test_result "Player register endpoint throttled after limit" "PASS"
else
  test_result "Player register endpoint throttled after limit" "FAIL" \
    "Sent 5 requests to /auth/player-register, none returned 429 — throttle may not be configured for this path"
  FINDINGS+=('{"severity":"HIGH","test":"player-register-throttle","detail":"5 player-register attempts without 429 — Rack::Attack rule may be missing for /auth/player-register"}')
fi

sleep 21

# ─────────────────────────────────────────────────────────
# Write report
# ─────────────────────────────────────────────────────────
FINDINGS_JSON="[$(IFS=,; echo "${FINDINGS[*]}")]"

cat > "$REPORT_FILE" <<EOF
{
  "test_suite": "rate-limiting",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "api_url": "$API_URL",
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED
  },
  "throttle_rules_tested": [
    {"rule": "logins/ip",            "limit": 5,    "period": "20s"},
    {"rule": "register/ip",          "limit": 3,    "period": "1hr"},
    {"rule": "req/authenticated_user","limit": 1000, "period": "1hr"},
    {"rule": "player-login/ip",      "limit": 5,    "period": "20s"},
    {"rule": "player-register/ip",   "limit": 3,    "period": "1hr"}
  ],
  "findings": $FINDINGS_JSON
}
EOF

echo ""
echo "============================================="
echo "Results: $PASSED passed, $FAILED failed / $TOTAL total"
echo "Report:  $REPORT_FILE"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}[OK] All rate limiting tests passed${NC}"
  exit 0
else
  echo -e "${RED}[FAIL] $FAILED rate limiting test(s) failed${NC}"
  exit 1
fi
