#!/bin/bash
# Timing Oracle Test — User Enumeration via Response Timing
#
# Adapted from chorrocho pentest lab (08_timing_cpf_oracle.sh).
#
# Detects whether the API leaks user existence through response time differences:
#   - Login with valid email vs unknown email
#   - Register with existing email vs new email
#
# A secure API should return identical timing for both cases.
# A detectable delta (> THRESHOLD_MS) indicates a timing oracle that allows
# user enumeration without authentication.
#
# Usage:
#   ./test-timing-oracle.sh
#   API_URL=http://localhost:3333 ./test-timing-oracle.sh

API_URL="${API_URL:-http://localhost:3333}"
REPORT_DIR="security_tests/reports/timing-oracle"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)

# Threshold in milliseconds — delta above this is flagged
# Rails bcrypt typically adds ~50-100ms; allow up to 200ms before flagging
THRESHOLD_MS="${TIMING_THRESHOLD_MS:-200}"
SAMPLES="${TIMING_SAMPLES:-10}"

echo "Timing Oracle Test — User Enumeration"
echo "======================================="
echo "API URL:    $API_URL"
echo "Threshold:  ${THRESHOLD_MS}ms"
echo "Samples:    $SAMPLES"
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

REPORT_FILE="$REPORT_DIR/timing-oracle-report-${TIMESTAMP}.json"
FINDINGS=()

# ─────────────────────────────────────────────────────────
# Helper: measure response time in ms for a request
# Returns integer ms
# ─────────────────────────────────────────────────────────
measure_ms() {
  local method="$1"
  local url="$2"
  local body="$3"

  local time_s
  time_s=$(curl -s -o /dev/null -w "%{time_total}" \
    -X "$method" "$url" \
    -H "Content-Type: application/json" \
    ${body:+--data-raw "$body"} \
    --max-time 10 2>/dev/null || echo "0")

  # Convert to integer ms (awk has locale issues; use python3 which is always available)
  python3 -c "print(int(float('${time_s:-0}') * 1000))" 2>/dev/null || echo "0"
}

# ─────────────────────────────────────────────────────────
# Collect N samples, compute mean
# ─────────────────────────────────────────────────────────
mean_ms() {
  local method="$1"
  local url="$2"
  local body="$3"
  local n="$4"

  local sum=0
  local _
  for _ in $(seq 1 "$n"); do
    local t
    t=$(measure_ms "$method" "$url" "$body")
    sum=$((sum + t))
    sleep 0.1
  done
  echo $((sum / n))
}

# ─────────────────────────────────────────────────────────
# Test 1: Login — existing email vs nonexistent email
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 1: Login timing — existing email vs unknown email ---"
echo "    Collecting ${SAMPLES} samples each (warm-up: 2 discarded)..."

KNOWN_EMAIL="${TEST_EMAIL:-test@prostaff.gg}"
UNKNOWN_EMAIL="totally-unknown-${TIMESTAMP}@no-such-domain-xyz.invalid"
# Use a clearly wrong password that won't be confused with history expansion
WRONG_PASS="WrongPasswordXYZ999"

LOGIN_URL="$API_URL/api/v1/auth/login"

# Warm-up (discarded)
measure_ms POST "$LOGIN_URL" "{\"email\":\"$KNOWN_EMAIL\",\"password\":\"$WRONG_PASS\"}" > /dev/null
measure_ms POST "$LOGIN_URL" "{\"email\":\"$UNKNOWN_EMAIL\",\"password\":\"$WRONG_PASS\"}" > /dev/null
sleep 0.5

# Collect samples
echo "    [known email with wrong password] ..."
T_KNOWN=$(mean_ms POST "$LOGIN_URL" "{\"email\":\"$KNOWN_EMAIL\",\"password\":\"$WRONG_PASS\"}" "$SAMPLES")

# Wait for throttle window reset between bursts
echo "    Waiting 21s for throttle reset..."
sleep 21

echo "    [unknown email with wrong password] ..."
T_UNKNOWN=$(mean_ms POST "$LOGIN_URL" "{\"email\":\"$UNKNOWN_EMAIL\",\"password\":\"$WRONG_PASS\"}" "$SAMPLES")

sleep 21

DELTA=$(( T_KNOWN > T_UNKNOWN ? T_KNOWN - T_UNKNOWN : T_UNKNOWN - T_KNOWN ))
echo "    Known email mean:   ${T_KNOWN}ms"
echo "    Unknown email mean: ${T_UNKNOWN}ms"
echo "    Delta:              ${DELTA}ms  (threshold: ${THRESHOLD_MS}ms)"

if [ "$DELTA" -le "$THRESHOLD_MS" ]; then
  test_result "Login timing: no detectable user enumeration oracle (delta ${DELTA}ms)" "PASS"
else
  test_result "Login timing: user enumeration oracle detected (delta ${DELTA}ms > ${THRESHOLD_MS}ms)" "FAIL" \
    "Response time differs by ${DELTA}ms between known and unknown emails — attacker can enumerate valid accounts"
  FINDINGS+=("{\"severity\":\"MEDIUM\",\"test\":\"login-timing-oracle\",\"detail\":\"Login response time delta ${DELTA}ms > threshold ${THRESHOLD_MS}ms — user enumeration possible via timing\"}")
fi

# ─────────────────────────────────────────────────────────
# Test 2: Register — existing email vs new email
# If user already exists, Rails may skip bcrypt and return early,
# producing a shorter response time and revealing that the email is taken.
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 2: Register timing — existing email vs brand-new email ---"
echo "    Collecting ${SAMPLES} samples each..."

REGISTER_URL="$API_URL/api/v1/auth/register"
NEW_EMAIL_1="timing-oracle-new-${TIMESTAMP}a@prostaff-test.invalid"
# shellcheck disable=SC2034
NEW_EMAIL_2="timing-oracle-new-${TIMESTAMP}b@prostaff-test.invalid"

REG_EXISTING_PAYLOAD="{\"organization_name\":\"TimingTest\",\"email\":\"$KNOWN_EMAIL\",\"password\":\"$WRONG_PASS\",\"name\":\"Timing Test\"}"
REG_NEW_PAYLOAD="{\"organization_name\":\"TimingTest\",\"email\":\"$NEW_EMAIL_1\",\"password\":\"$WRONG_PASS\",\"name\":\"Timing Test\"}"

# Warm-up
measure_ms POST "$REGISTER_URL" "$REG_EXISTING_PAYLOAD" > /dev/null
measure_ms POST "$REGISTER_URL" "$REG_NEW_PAYLOAD" > /dev/null
sleep 0.5

echo "    [existing email] ..."
T_REG_EXISTING=$(mean_ms POST "$REGISTER_URL" "$REG_EXISTING_PAYLOAD" "$SAMPLES")

echo "    [new/unknown email] ..."
T_REG_NEW=$(mean_ms POST "$REGISTER_URL" "$REG_NEW_PAYLOAD" "$SAMPLES")

DELTA_REG=$(( T_REG_EXISTING > T_REG_NEW ? T_REG_EXISTING - T_REG_NEW : T_REG_NEW - T_REG_EXISTING ))
echo "    Existing email mean: ${T_REG_EXISTING}ms"
echo "    New email mean:      ${T_REG_NEW}ms"
echo "    Delta:               ${DELTA_REG}ms  (threshold: ${THRESHOLD_MS}ms)"

if [ "$DELTA_REG" -le "$THRESHOLD_MS" ]; then
  test_result "Register timing: no detectable user enumeration oracle (delta ${DELTA_REG}ms)" "PASS"
else
  test_result "Register timing: user enumeration oracle detected (delta ${DELTA_REG}ms > ${THRESHOLD_MS}ms)" "FAIL" \
    "Response time differs by ${DELTA_REG}ms between existing and new email — attacker can enumerate registered accounts"
  FINDINGS+=("{\"severity\":\"LOW\",\"test\":\"register-timing-oracle\",\"detail\":\"Register response time delta ${DELTA_REG}ms > threshold ${THRESHOLD_MS}ms — email existence leak via timing\"}")
fi

# ─────────────────────────────────────────────────────────
# Test 3: Error message enumeration (non-timing)
# Check that login failure messages don't differ between
# "wrong password" and "email not found"
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 3: Login error message — no user enumeration via body ---"

RESP_KNOWN=$(curl -s -X POST "$LOGIN_URL" \
  -H "Content-Type: application/json" \
  --data-raw "{\"email\":\"${KNOWN_EMAIL}\",\"password\":\"${WRONG_PASS}\"}" \
  --max-time 10 2>/dev/null || echo "{}")

sleep 21

RESP_UNKNOWN=$(curl -s -X POST "$LOGIN_URL" \
  -H "Content-Type: application/json" \
  --data-raw "{\"email\":\"${UNKNOWN_EMAIL}\",\"password\":\"${WRONG_PASS}\"}" \
  --max-time 10 2>/dev/null || echo "{}")

echo "    Known email response:   ${RESP_KNOWN:0:100}"
echo "    Unknown email response: ${RESP_UNKNOWN:0:100}"

# Check for distinct error messages that reveal user existence
KNOWN_REVEALS=$(echo "$RESP_KNOWN" | grep -ioE "invalid.password|wrong.password|incorrect.password" | head -1)
UNKNOWN_REVEALS=$(echo "$RESP_UNKNOWN" | grep -ioE "user.not.found|no.account|email.not|not.registered" | head -1)

if [ -n "$KNOWN_REVEALS" ] || [ -n "$UNKNOWN_REVEALS" ]; then
  test_result "Login error messages do not enumerate users" "FAIL" \
    "Distinct error messages: known='$KNOWN_REVEALS' unknown='$UNKNOWN_REVEALS' — different messages for different failure modes"
  FINDINGS+=("{\"severity\":\"LOW\",\"test\":\"login-error-enumeration\",\"detail\":\"Login returns different error messages for wrong-password vs unknown-email scenarios\"}")
else
  test_result "Login error messages do not enumerate users" "PASS"
fi

sleep 21

# ─────────────────────────────────────────────────────────
# Write report
# ─────────────────────────────────────────────────────────
FINDINGS_JSON="[$(IFS=,; echo "${FINDINGS[*]}")]"

cat > "$REPORT_FILE" <<EOF
{
  "test_suite": "timing-oracle",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "api_url": "$API_URL",
  "threshold_ms": $THRESHOLD_MS,
  "samples_per_endpoint": $SAMPLES,
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED
  },
  "timing_results": {
    "login_known_email_ms":    $T_KNOWN,
    "login_unknown_email_ms":  $T_UNKNOWN,
    "login_delta_ms":          $DELTA,
    "register_existing_email_ms": $T_REG_EXISTING,
    "register_new_email_ms":      $T_REG_NEW,
    "register_delta_ms":          $DELTA_REG
  },
  "findings": $FINDINGS_JSON
}
EOF

echo ""
echo "============================================="
echo "Results: $PASSED passed, $FAILED failed / $TOTAL total"
echo "Report:  $REPORT_FILE"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}[OK] All timing oracle tests passed${NC}"
  exit 0
else
  echo -e "${RED}[FAIL] $FAILED timing oracle test(s) failed${NC}"
  echo ""
  echo "Note: timing deltas may vary with system load."
  echo "Re-run with a lower threshold to confirm: TIMING_THRESHOLD_MS=100 $0"
  exit 1
fi
