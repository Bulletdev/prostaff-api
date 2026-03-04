#!/bin/bash
# Multi-Tenancy Isolation Security Test
# Tests for data leakage between organizations

set -e

API_URL="${API_URL:-http://localhost:3333}"
REPORT_DIR="security_tests/reports/multi-tenancy"

echo "Multi-Tenancy Isolation Security Test"
echo "======================================"
echo "API URL: $API_URL"
echo ""

mkdir -p "$REPORT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

# Test 1: Create two organizations
echo ""
echo "Setting up test organizations..."

# Create Org 1
ORG1_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "org1-'$(date +%s)'@test.com",
      "password": "Test123!@#",
      "name": "Org1 User"
    },
    "organization": {
      "name": "Test Org 1",
      "slug": "test-org-1-'$(date +%s)'"
    }
  }')

ORG1_TOKEN=$(echo "$ORG1_RESPONSE" | jq -r '.data.access_token')
ORG1_USER_ID=$(echo "$ORG1_RESPONSE" | jq -r '.data.user.id')
ORG1_ORG_ID=$(echo "$ORG1_RESPONSE" | jq -r '.data.organization.id')

# Create Org 2
ORG2_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "org2-'$(date +%s)'@test.com",
      "password": "Test123!@#",
      "name": "Org2 User"
    },
    "organization": {
      "name": "Test Org 2",
      "slug": "test-org-2-'$(date +%s)'"
    }
  }')

ORG2_TOKEN=$(echo "$ORG2_RESPONSE" | jq -r '.data.access_token')
ORG2_USER_ID=$(echo "$ORG2_RESPONSE" | jq -r '.data.user.id')
ORG2_ORG_ID=$(echo "$ORG2_RESPONSE" | jq -r '.data.organization.id')

if [ "$ORG1_TOKEN" = "null" ] || [ "$ORG2_TOKEN" = "null" ]; then
  echo "FATAL: Failed to create test organizations"
  echo "Org1 Response: $ORG1_RESPONSE"
  echo "Org2 Response: $ORG2_RESPONSE"
  exit 1
fi

echo "Org 1: $ORG1_ORG_ID (token: ${ORG1_TOKEN:0:20}...)"
echo "Org 2: $ORG2_ORG_ID (token: ${ORG2_TOKEN:0:20}...)"
echo ""

# Test 2: Create players in each org
echo "Creating test players..."

PLAYER1_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/players" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ORG1_TOKEN" \
  -d '{
    "player": {
      "summoner_name": "Org1Player",
      "real_name": "Player One",
      "role": "mid"
    }
  }')

PLAYER1_ID=$(echo "$PLAYER1_RESPONSE" | jq -r '.data.player.id')

PLAYER2_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/players" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ORG2_TOKEN" \
  -d '{
    "player": {
      "summoner_name": "Org2Player",
      "real_name": "Player Two",
      "role": "top"
    }
  }')

PLAYER2_ID=$(echo "$PLAYER2_RESPONSE" | jq -r '.data.player.id')

echo "Player 1 (Org1): $PLAYER1_ID"
echo "Player 2 (Org2): $PLAYER2_ID"
echo ""
echo "Running isolation tests..."
echo ""

# TEST 1: Org1 should NOT see Org2 players in list
echo "[TEST 1] Player list isolation"
ORG1_PLAYERS=$(curl -s -X GET "$API_URL/api/v1/players" \
  -H "Authorization: Bearer $ORG1_TOKEN" | jq -r '.data.players')

LEAKED=$(echo "$ORG1_PLAYERS" | jq -r --arg id "$PLAYER2_ID" 'map(select(.id == $id)) | length')

if [ "$LEAKED" = "0" ]; then
  test_result "Org1 cannot list Org2 players" "PASS" ""
else
  test_result "Org1 cannot list Org2 players" "FAIL" "Found $LEAKED players from Org2 in Org1 list"
fi

# TEST 2: Org1 should NOT access Org2 player by ID
echo "[TEST 2] Direct player access isolation"
ORG1_ACCESS_ORG2=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/api/v1/players/$PLAYER2_ID" \
  -H "Authorization: Bearer $ORG1_TOKEN")

HTTP_CODE=$(echo "$ORG1_ACCESS_ORG2" | tail -n1)
RESPONSE_BODY=$(echo "$ORG1_ACCESS_ORG2" | head -n-1)

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Org1 cannot access Org2 player by ID" "PASS" ""
else
  test_result "Org1 cannot access Org2 player by ID" "FAIL" "Got HTTP $HTTP_CODE instead of 404/403"
fi

# TEST 3: Org2 should NOT see Org1 players
echo "[TEST 3] Reverse isolation check"
ORG2_PLAYERS=$(curl -s -X GET "$API_URL/api/v1/players" \
  -H "Authorization: Bearer $ORG2_TOKEN" | jq -r '.data.players')

LEAKED=$(echo "$ORG2_PLAYERS" | jq -r --arg id "$PLAYER1_ID" 'map(select(.id == $id)) | length')

if [ "$LEAKED" = "0" ]; then
  test_result "Org2 cannot list Org1 players" "PASS" ""
else
  test_result "Org2 cannot list Org1 players" "FAIL" "Found $LEAKED players from Org1 in Org2 list"
fi

# TEST 4: Dashboard stats should be isolated
echo "[TEST 4] Dashboard stats isolation"
ORG1_STATS=$(curl -s -X GET "$API_URL/api/v1/dashboard/stats" \
  -H "Authorization: Bearer $ORG1_TOKEN" | jq -r '.data')

ORG2_STATS=$(curl -s -X GET "$API_URL/api/v1/dashboard/stats" \
  -H "Authorization: Bearer $ORG2_TOKEN" | jq -r '.data')

ORG1_PLAYER_COUNT=$(echo "$ORG1_STATS" | jq -r '.total_players')
ORG2_PLAYER_COUNT=$(echo "$ORG2_STATS" | jq -r '.total_players')

# Each org should have exactly 1 player (the one we created)
if [ "$ORG1_PLAYER_COUNT" -le "1" ] && [ "$ORG2_PLAYER_COUNT" -le "1" ]; then
  test_result "Dashboard stats isolated per organization" "PASS" ""
else
  test_result "Dashboard stats isolated per organization" "FAIL" "Org1: $ORG1_PLAYER_COUNT players, Org2: $ORG2_PLAYER_COUNT players (expected 1 each)"
fi

# TEST 5: Search should not cross organizations
echo "[TEST 5] Search isolation"
ORG1_SEARCH=$(curl -s -X GET "$API_URL/api/v1/players?search=Org2Player" \
  -H "Authorization: Bearer $ORG1_TOKEN" | jq -r '.data.players | length')

if [ "$ORG1_SEARCH" = "0" ]; then
  test_result "Search does not leak across organizations" "PASS" ""
else
  test_result "Search does not leak across organizations" "FAIL" "Found $ORG1_SEARCH results for Org2 player in Org1 search"
fi

# TEST 6: Update should not work across orgs
echo "[TEST 6] Update isolation"
CROSS_ORG_UPDATE=$(curl -s -w "\n%{http_code}" -X PATCH "$API_URL/api/v1/players/$PLAYER2_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ORG1_TOKEN" \
  -d '{"player": {"real_name": "Hacked"}}')

HTTP_CODE=$(echo "$CROSS_ORG_UPDATE" | tail -n1)

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Org1 cannot update Org2 player" "PASS" ""
else
  test_result "Org1 cannot update Org2 player" "FAIL" "Got HTTP $HTTP_CODE instead of 404/403"
fi

# TEST 7: Delete should not work across orgs
echo "[TEST 7] Delete isolation"
CROSS_ORG_DELETE=$(curl -s -w "\n%{http_code}" -X DELETE "$API_URL/api/v1/players/$PLAYER2_ID" \
  -H "Authorization: Bearer $ORG1_TOKEN")

HTTP_CODE=$(echo "$CROSS_ORG_DELETE" | tail -n1)

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "403" ]; then
  test_result "Org1 cannot delete Org2 player" "PASS" ""
else
  test_result "Org1 cannot delete Org2 player" "FAIL" "Got HTTP $HTTP_CODE instead of 404/403"
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
cat > "$REPORT_DIR/multi-tenancy-report.json" <<EOF
{
  "test_suite": "Multi-Tenancy Isolation",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_tests": $TOTAL,
  "passed": $PASSED,
  "failed": $FAILED,
  "pass_rate": $(echo "scale=2; $PASSED * 100 / $TOTAL" | bc),
  "test_organizations": {
    "org1": {
      "id": "$ORG1_ORG_ID",
      "player_id": "$PLAYER1_ID"
    },
    "org2": {
      "id": "$ORG2_ORG_ID",
      "player_id": "$PLAYER2_ID"
    }
  }
}
EOF

echo ""
echo "Report saved to: $REPORT_DIR/multi-tenancy-report.json"

# Exit with failure if any test failed
if [ $FAILED -gt 0 ]; then
  echo ""
  echo -e "${RED}SECURITY RISK: Multi-tenancy isolation tests FAILED${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}SUCCESS: All multi-tenancy isolation tests passed${NC}"
  exit 0
fi
