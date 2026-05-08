#!/bin/bash
# Body Field Fuzzing Test — Mass Assignment + Admin Field Injection
#
# Adapted from chorrocho pentest lab (09_body_field_fuzzing.sh).
#
# Tests that Rails API endpoints are protected against:
#   1. Mass assignment — injecting protected attributes (organization_id, role, admin)
#   2. Admin/privilege field injection — fields that should not be accepted
#   3. Type confusion — wrong types for validated fields
#   4. Cross-tenant ID injection — organization_id of another org
#
# Usage:
#   ./test-body-fuzzing.sh
#   API_URL=http://localhost:3333 ./test-body-fuzzing.sh

API_URL="${API_URL:-http://localhost:3333}"
REPORT_DIR="security_tests/reports/body-fuzzing"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)

echo "Body Field Fuzzing Test — Mass Assignment & Admin Injection"
echo "============================================================"
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
FINDINGS=()

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

skip_test() {
  local name="$1"
  local reason="$2"
  TOTAL=$((TOTAL + 1))
  echo -e "${YELLOW}[SKIP]${NC} $name — $reason"
}

# Check API is up
if ! curl -s "$API_URL/up" > /dev/null 2>&1; then
  echo -e "${YELLOW}[SKIP]${NC} API not running at $API_URL"
  echo "       Start with: docker compose up -d"
  exit 0
fi

REPORT_FILE="$REPORT_DIR/body-fuzzing-report-${TIMESTAMP}.json"

# ─────────────────────────────────────────────────────────
# Setup: get auth token for Org A
# ─────────────────────────────────────────────────────────
echo "Setting up test organizations..."
echo ""

# Create Org A (use python3 to avoid bash history-expansion with ! in password)
ORG_A_SUFFIX="${TIMESTAMP}a"
ORG_A_RESP=$(python3 -c "
import urllib.request, json
payload = {
  'organization_name': 'FuzzTestA${ORG_A_SUFFIX}',
  'email': 'fuzz-a-${ORG_A_SUFFIX}@prostaff-test.invalid',
  'password': 'Test123!@#',
  'name': 'Fuzz Test A'
}
req = urllib.request.Request(
  '${API_URL}/api/v1/auth/register',
  data=json.dumps(payload).encode(),
  headers={'Content-Type': 'application/json'},
  method='POST'
)
try:
  with urllib.request.urlopen(req, timeout=10) as r:
    print(r.read().decode())
except urllib.error.HTTPError as e:
  print(e.read().decode())
except Exception:
  print('{}')
" 2>/dev/null)

TOKEN_A=$(echo "$ORG_A_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('access_token',''))" 2>/dev/null || echo "")
ORG_A_ID=$(echo "$ORG_A_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('organization',{}).get('id',''))" 2>/dev/null || echo "")

if [ -z "$TOKEN_A" ]; then
  # Fallback: login with test user
  AUTH_RESP=$(python3 -c "
import urllib.request, json
payload = {'email': '${TEST_EMAIL:-test@prostaff.gg}', 'password': '${TEST_PASSWORD:-Test123!@#}'}
req = urllib.request.Request(
  '${API_URL}/api/v1/auth/login',
  data=json.dumps(payload).encode(),
  headers={'Content-Type': 'application/json'},
  method='POST'
)
try:
  with urllib.request.urlopen(req, timeout=10) as r:
    print(r.read().decode())
except urllib.error.HTTPError as e:
  print(e.read().decode())
except Exception:
  print('{}')
" 2>/dev/null)
  TOKEN_A=$(echo "$AUTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('access_token',''))" 2>/dev/null || echo "")
  ORG_A_ID=$(echo "$AUTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('organization',{}).get('id',''))" 2>/dev/null || echo "")
fi

if [ -z "$TOKEN_A" ]; then
  echo -e "${YELLOW}[WARN]${NC} Could not obtain auth token. Some tests will be skipped."
  echo "       Create test user: docker exec prostaff-api-api-1 bundle exec rails runner scripts/create_test_user.rb"
  echo ""
fi

# Create Org B for cross-tenant tests
# Use python3 to avoid bash history-expansion issues with special chars in password
ORG_B_SUFFIX="${TIMESTAMP}b"
ORG_B_RESP=$(python3 -c "
import urllib.request, json, sys
payload = {
  'organization_name': 'FuzzTestB${ORG_B_SUFFIX}',
  'email': 'fuzz-b-${ORG_B_SUFFIX}@prostaff-test.invalid',
  'password': 'Test123!@#',
  'name': 'Fuzz Test B'
}
req = urllib.request.Request(
  '${API_URL}/api/v1/auth/register',
  data=json.dumps(payload).encode(),
  headers={'Content-Type': 'application/json'},
  method='POST'
)
try:
  with urllib.request.urlopen(req, timeout=10) as r:
    print(r.read().decode())
except urllib.error.HTTPError as e:
  print(e.read().decode())
except Exception as e:
  print('{}')
" 2>/dev/null)

TOKEN_B=$(echo "$ORG_B_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
ORG_B_ID=$(echo "$ORG_B_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('organization',{}).get('id',''))" 2>/dev/null || echo "")

# If register throttled, get an existing org ID from the DB (different from Org A)
if [ -z "$ORG_B_ID" ] && command -v docker >/dev/null 2>&1; then
  ORG_B_ID=$(docker exec prostaff-api rails runner \
    "puts Organization.where.not(id: '${ORG_A_ID}').order(:created_at).first&.id.to_s" \
    2>/dev/null | tail -1 | tr -d '\r\n')
  [ -n "$ORG_B_ID" ] && echo "       Org B: using existing org $ORG_B_ID (register throttled)"
fi

echo "Org A token: ${TOKEN_A:+obtained} ${TOKEN_A:-MISSING}"
echo "Org B token: ${TOKEN_B:+obtained} ${TOKEN_B:-MISSING}"
echo "Org A ID: ${ORG_A_ID:-unknown}"
echo "Org B ID: ${ORG_B_ID:-unknown}"
echo ""

auth_header() {
  echo "Authorization: Bearer $1"
}

# ─────────────────────────────────────────────────────────
# Helper: POST with extra field, check if field appears in response
# ─────────────────────────────────────────────────────────
check_field_accepted() {
  local endpoint="$1"
  local base_payload="$2"
  local inject_field="$3"
  local inject_value="$4"
  local token="$5"

  # Inject the field into the payload
  local modified_payload
  modified_payload=$(echo "$base_payload" | sed "s/}$/,\"${inject_field}\":${inject_value}}/")

  local response
  response=$(curl -s -X POST "$API_URL$endpoint" \
    -H "Content-Type: application/json" \
    ${token:+-H "Authorization: Bearer $token"} \
    --data-raw "$modified_payload" \
    --max-time 10 2>/dev/null || echo "{}")

  # Check if the injected field name appears in the response body (sign of acceptance)
  if echo "$response" | grep -qi "\"$inject_field\""; then
    echo "$response"
    return 0  # field was accepted/reflected
  fi
  return 1  # field not reflected
}

# ─────────────────────────────────────────────────────────
# Test 1: Mass assignment — player creation with protected fields
# ─────────────────────────────────────────────────────────
echo "--- Test 1: Mass assignment on player creation ---"

if [ -z "$TOKEN_A" ]; then
  skip_test "Mass assignment on player creation" "no auth token"
else
  PLAYER_BASE='{"name":"FuzzPlayer","role":"mid","region":"br1","game_name":"FuzzPlayer","tag_line":"BR1","summoner_name":"FuzzPlayer"}'
  PLAYERS_ENDPOINT="/api/v1/players"

  MASS_ASSIGN_FAILED=0
  for field_pair in \
    "admin:true" \
    "organization_id:\"${ORG_B_ID:-c80e97d1-0bd4-4a9c-a0f4-e4422ee8ffd1}\"" \
    "is_admin:true" \
    "permissions:\"all\"" \
    "superuser:true"
  do
    field=$(echo "$field_pair" | cut -d: -f1)
    value=$(echo "$field_pair" | cut -d: -f2-)

    http_status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "$API_URL$PLAYERS_ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN_A" \
      --data-raw "$(echo "$PLAYER_BASE" | sed "s/}$/,\"${field}\":${value}}/")" \
      --max-time 10 2>/dev/null || echo 0)

    response=$(curl -s \
      -X POST "$API_URL$PLAYERS_ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN_A" \
      --data-raw "$(echo "$PLAYER_BASE" | sed "s/}$/,\"${field}\":${value}}/")" \
      --max-time 10 2>/dev/null || echo "{}")

    # Only flag as mass assignment if the request SUCCEEDED (2xx) AND the field appears
    # A validation error (422) containing the field name is expected correct behavior
    if [[ "$http_status" =~ ^2 ]] && echo "$response" | grep -qi "\"$field\""; then
      echo "       FAIL: field '$field' accepted in successful (HTTP $http_status) response"
      MASS_ASSIGN_FAILED=$((MASS_ASSIGN_FAILED + 1))
    elif [[ "$http_status" =~ ^2 ]]; then
      echo "       OK: field '$field' not reflected (HTTP $http_status)"
    else
      echo "       OK: field '$field' rejected (HTTP $http_status)"
    fi

    # Separately check for internal errors
    if echo "$response" | grep -qiE "exception|internal.server.error"; then
      echo "       WARN: internal error on field '$field'"
    fi
  done

  # Test role with a non-game-role value to confirm validation is active
  ROLE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL$PLAYERS_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    --data-raw '{"name":"RoleValTest","role":"administrator","region":"br1","game_name":"RoleValTest","tag_line":"BR1","summoner_name":"RoleValTest"}' \
    --max-time 10 2>/dev/null || echo 0)
  if [[ "$ROLE_STATUS" =~ ^2 ]]; then
    echo "       FAIL: role=administrator was accepted (HTTP $ROLE_STATUS) — role validation missing"
    MASS_ASSIGN_FAILED=$((MASS_ASSIGN_FAILED + 1))
  else
    echo "       OK: role=administrator rejected (HTTP $ROLE_STATUS) — role validation active"
  fi

  if [ "$MASS_ASSIGN_FAILED" -eq 0 ]; then
    test_result "Mass assignment fields rejected on player creation" "PASS"
  else
    test_result "Mass assignment fields rejected on player creation" "FAIL" \
      "$MASS_ASSIGN_FAILED protected field(s) may have been accepted"
    FINDINGS+=("{\"severity\":\"HIGH\",\"test\":\"mass-assignment-player\",\"detail\":\"${MASS_ASSIGN_FAILED} protected field(s) reflected in player creation response\"}")
  fi

  # Clean up test players
  # (players created with random names — no specific cleanup needed as they're test-scoped)
fi

# ─────────────────────────────────────────────────────────
# Test 2: Cross-tenant organization_id injection on register
# Try to register a user forcing them into org B's organization_id
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 2: Cross-tenant organization_id injection on register ---"

if [ -z "$ORG_B_ID" ]; then
  skip_test "Cross-tenant org injection on register" "Org B ID unknown"
else
  INJECT_RESP=$(curl -s -X POST "$API_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    --data-raw "{\"organization_name\":\"InjectedOrg\",\"email\":\"inject-${TIMESTAMP}@prostaff-test.invalid\",\"password\":\"Test123!@#\",\"name\":\"Inject Test\",\"organization_id\":${ORG_B_ID}}" \
    --max-time 10 2>/dev/null || echo "{}")

  INJECT_ORG=$(echo "$INJECT_RESP" | grep -o '"organization_id":[0-9]*' | cut -d: -f2)

  if [ -n "$INJECT_ORG" ] && [ "$INJECT_ORG" = "$ORG_B_ID" ]; then
    test_result "Register rejects organization_id injection" "FAIL" \
      "Registered user was placed into org B ($ORG_B_ID) — mass assignment allowed cross-tenant injection"
    FINDINGS+=("{\"severity\":\"CRITICAL\",\"test\":\"cross-tenant-org-injection\",\"detail\":\"Register accepted organization_id injection — new user placed in org B ($ORG_B_ID) instead of a new org\"}")
  else
    test_result "Register rejects organization_id injection" "PASS"
  fi
fi

# ─────────────────────────────────────────────────────────
# Test 3: Role escalation — inject role=admin on player update
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 3: Role escalation via player update ---"

if [ -z "$TOKEN_A" ]; then
  skip_test "Role escalation on player update" "no auth token"
else
  # Create a player to update
  CREATE_RESP=$(curl -s -X POST "$API_URL/api/v1/players" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    --data-raw '{"name":"RoleEscTest","role":"mid","region":"br1","game_name":"RoleEscTest","tag_line":"BR1","summoner_name":"RoleEscTest"}' \
    --max-time 10 2>/dev/null || echo "{}")

  PLAYER_ID=$(echo "$CREATE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('player',{}).get('id',''))" 2>/dev/null || echo "")

  if [ -z "$PLAYER_ID" ]; then
    skip_test "Role escalation on player update" "could not create test player"
  else
    # Try to set admin fields on update
    ESCALATION_FOUND=0
    for field_pair in "admin:true" "role:\"admin\"" "is_admin:true"; do
      field=$(echo "$field_pair" | cut -d: -f1)
      value=$(echo "$field_pair" | cut -d: -f2-)

      resp=$(curl -s -X PATCH "$API_URL/api/v1/players/$PLAYER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN_A" \
        --data-raw "{\"$field\":$value}" \
        --max-time 10 2>/dev/null || echo "{}")

      if echo "$resp" | grep -qi "\"$field\".*true\|\"$field\".*admin"; then
        ESCALATION_FOUND=$((ESCALATION_FOUND + 1))
        echo "       WARN: field '$field' may have been accepted in player update"
      fi
    done

    if [ "$ESCALATION_FOUND" -eq 0 ]; then
      test_result "Player update rejects privilege escalation fields" "PASS"
    else
      test_result "Player update rejects privilege escalation fields" "FAIL" \
        "$ESCALATION_FOUND escalation field(s) may have been accepted"
      FINDINGS+=("{\"severity\":\"HIGH\",\"test\":\"role-escalation-player-update\",\"detail\":\"$ESCALATION_FOUND privilege field(s) accepted in player PATCH endpoint\"}")
    fi

    # Clean up
    curl -s -X DELETE "$API_URL/api/v1/players/$PLAYER_ID" \
      -H "Authorization: Bearer $TOKEN_A" --max-time 5 > /dev/null 2>&1 || true
  fi
fi

# ─────────────────────────────────────────────────────────
# Test 4: Type confusion on login
# Sending wrong types should not cause 500 errors
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 4: Type confusion — wrong types do not cause 500 ---"

TYPE_CONFUSION_CASES=(
  '{"email":null,"password":"Test123!@#"}'
  '{"email":[],"password":"Test123!@#"}'
  '{"email":{},"password":"Test123!@#"}'
  '{"email":"test@prostaff.gg","password":null}'
  '{"email":"test@prostaff.gg","password":123}'
  '{"email":true,"password":false}'
)

TYPE_CONFUSION_FAILED=0
for payload in "${TYPE_CONFUSION_CASES[@]}"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    --data-raw "$payload" \
    --max-time 10 2>/dev/null || echo 0)

  if [ "$status" = "500" ]; then
    TYPE_CONFUSION_FAILED=$((TYPE_CONFUSION_FAILED + 1))
    echo "       FAIL: payload '$payload' returned 500"
  fi
done

if [ "$TYPE_CONFUSION_FAILED" -eq 0 ]; then
  test_result "Type confusion payloads handled gracefully (no 500s)" "PASS"
else
  test_result "Type confusion payloads handled gracefully (no 500s)" "FAIL" \
    "$TYPE_CONFUSION_FAILED payloads caused 500 Internal Server Error"
  FINDINGS+=("{\"severity\":\"MEDIUM\",\"test\":\"type-confusion-login\",\"detail\":\"${TYPE_CONFUSION_FAILED} malformed type payloads triggered 500 on login endpoint\"}")
fi

# ─────────────────────────────────────────────────────────
# Test 5: Oversized fields do not cause 500
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 5: Oversized field values handled gracefully ---"

if [ -z "$TOKEN_A" ]; then
  skip_test "Oversized fields on player create" "no auth token"
else
  LONG_STRING=$(python3 -c "print('A' * 10000)" 2>/dev/null || head -c 10000 /dev/urandom | tr -dc 'A-Za-z' | head -c 10000)

  OVERSIZE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/players" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    --data-raw "{\"name\":\"$LONG_STRING\",\"role\":\"mid\",\"region\":\"br1\",\"game_name\":\"test\",\"tag_line\":\"BR1\",\"summoner_name\":\"OversizeTest\"}" \
    --max-time 15 2>/dev/null || echo 0)

  if [ "$OVERSIZE_STATUS" = "500" ]; then
    test_result "Oversized name field handled gracefully (no 500)" "FAIL" \
      "10k character name returned HTTP 500"
    FINDINGS+=("{\"severity\":\"LOW\",\"test\":\"oversized-field\",\"detail\":\"10,000 character player name caused 500 Internal Server Error\"}")
  else
    test_result "Oversized name field handled gracefully (no 500) — HTTP $OVERSIZE_STATUS" "PASS"
  fi
fi

# ─────────────────────────────────────────────────────────
# Test 6: Extra/unknown fields do not trigger server errors or leak info
# ─────────────────────────────────────────────────────────
echo ""
echo "--- Test 6: Extra/unknown fields silently ignored ---"

if [ -z "$TOKEN_A" ]; then
  skip_test "Extra fields on player create" "no auth token"
else
  EXTRA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API_URL/api/v1/players" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    --data-raw '{"name":"ExtraFieldTest","role":"mid","region":"br1","game_name":"ExtraTest","tag_line":"BR1","__debug":true,"internal_flag":"bypass","webhook":"https://evil.example.com","callback_url":"https://attacker.example.com"}' \
    --max-time 10 2>/dev/null || echo 0)

  EXTRA_BODY=$(curl -s \
    -X POST "$API_URL/api/v1/players" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    --data-raw '{"name":"ExtraFieldTest2","role":"mid","region":"br1","game_name":"ExtraTest2","tag_line":"BR1","__debug":true,"webhook":"https://evil.example.com"}' \
    --max-time 10 2>/dev/null || echo "{}")

  if [ "$EXTRA_STATUS" = "500" ]; then
    test_result "Extra/unknown fields cause no server error" "FAIL" \
      "Extra fields triggered HTTP 500"
    FINDINGS+=("{\"severity\":\"LOW\",\"test\":\"extra-fields\",\"detail\":\"Unknown fields in player creation body caused 500\"}")
  elif echo "$EXTRA_BODY" | grep -qiE "__debug|webhook|callback_url"; then
    test_result "Extra/unknown fields silently ignored (not reflected)" "FAIL" \
      "Injected fields were reflected back in response body"
    FINDINGS+=("{\"severity\":\"MEDIUM\",\"test\":\"extra-fields-reflected\",\"detail\":\"Unknown fields (__debug, webhook) were reflected in response — may indicate acceptance\"}")
  else
    test_result "Extra/unknown fields silently ignored" "PASS"
  fi
fi

# ─────────────────────────────────────────────────────────
# Write report
# ─────────────────────────────────────────────────────────
FINDINGS_JSON="[$(IFS=,; echo "${FINDINGS[*]}")]"

cat > "$REPORT_FILE" <<EOF
{
  "test_suite": "body-fuzzing",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "api_url": "$API_URL",
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED
  },
  "tests_covered": [
    "mass-assignment-player-create",
    "cross-tenant-org-injection",
    "role-escalation-player-update",
    "type-confusion-login",
    "oversized-fields",
    "extra-unknown-fields"
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
  echo -e "${GREEN}[OK] All body fuzzing tests passed${NC}"
  exit 0
else
  echo -e "${RED}[FAIL] $FAILED body fuzzing test(s) failed${NC}"
  exit 1
fi
