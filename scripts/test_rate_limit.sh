#!/bin/bash

# ProStaff API - Rate Limit Test Script
# Tests Traefik rate limiting (30 req/s with burst of 50)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
API_URL="${API_URL:-https://prostaff.gg/up}"
RATE_LIMIT=30
BURST=50
TEST_REQUESTS=100

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  ProStaff API - Rate Limit Test${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Target URL: ${GREEN}$API_URL${NC}"
echo -e "Expected Rate Limit: ${GREEN}${RATE_LIMIT} req/s${NC}"
echo -e "Burst Limit: ${GREEN}${BURST}${NC}"
echo -e "Test Requests: ${GREEN}${TEST_REQUESTS}${NC}"
echo ""

# Test 1: Normal requests (should all succeed)
echo -e "${YELLOW}Test 1: Normal Load (10 requests over 2 seconds)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

success=0
for i in {1..10}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL")
    if [ "$response" = "200" ]; then
        echo -e "Request $i: ${GREEN}✓${NC} 200 OK"
        ((success++))
    else
        echo -e "Request $i: ${RED}✗${NC} $response"
    fi
    sleep 0.2
done

echo ""
echo -e "Result: ${GREEN}$success/10${NC} requests succeeded"
echo ""

# Test 2: Burst test (should hit rate limit)
echo -e "${YELLOW}Test 2: Burst Test (100 rapid requests)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

success=0
rate_limited=0

echo "Sending $TEST_REQUESTS requests as fast as possible..."
start_time=$(date +%s)

for i in $(seq 1 $TEST_REQUESTS); do
    response=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL" 2>/dev/null)
    if [ "$response" = "200" ]; then
        ((success++))
    elif [ "$response" = "429" ]; then
        ((rate_limited++))
    fi

    # Show progress every 10 requests
    if [ $((i % 10)) -eq 0 ]; then
        echo -n "."
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo ""
echo -e "Results:"
echo -e "  ${GREEN}✓${NC} Successful (200): ${GREEN}$success${NC}"
echo -e "  ${RED}✗${NC} Rate Limited (429): ${YELLOW}$rate_limited${NC}"
echo -e "  Duration: ${duration}s"
echo -e "  Actual Rate: $((TEST_REQUESTS / duration)) req/s"
echo ""

# Verify rate limiting is working
if [ $rate_limited -gt 0 ]; then
    echo -e "${GREEN}✓ Rate limiting is ACTIVE${NC}"
    echo -e "  ${rate_limited} requests were blocked (expected after burst limit)"
else
    echo -e "${RED}✗ WARNING: No requests were rate limited!${NC}"
    echo -e "  Rate limiting may not be configured correctly"
fi

echo ""

# Test 3: Recovery test
echo -e "${YELLOW}Test 3: Recovery Test (after 2 second cooldown)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Waiting 2 seconds for rate limit to reset..."
sleep 2

success=0
for i in {1..5}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL")
    if [ "$response" = "200" ]; then
        echo -e "Request $i: ${GREEN}✓${NC} 200 OK"
        ((success++))
    else
        echo -e "Request $i: ${RED}✗${NC} $response"
    fi
    sleep 0.1
done

echo ""
if [ $success -eq 5 ]; then
    echo -e "${GREEN}✓ Rate limit properly reset after cooldown${NC}"
else
    echo -e "${YELLOW}⚠ Some requests still being rate limited${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
