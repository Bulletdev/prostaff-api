#!/bin/bash
# Start Security Testing Lab for Local Environment
# This script starts security testing tools in the background

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE} ProStaff API - Local Security Lab Setup${NC}"
echo "=========================================="
echo ""

# Check if API is running
if ! docker ps | grep -q "prostaff-api"; then
    echo -e "${RED} ProStaff API is not running${NC}"
    echo "Start it with: docker compose -f docker/docker-compose.yml up -d"
    exit 1
fi

echo -e "${GREEN} ProStaff API is running${NC}"
echo ""

# Create reports directories
echo -e "${YELLOW} Creating reports directories...${NC}"
mkdir -p reports/{brakeman,semgrep,trivy,nuclei}
mkdir -p zap/reports
echo ""

# Pull images in parallel (faster than docker-compose)
echo -e "${YELLOW} Pulling security tool images (this may take a few minutes)...${NC}"
docker pull zaproxy/zap-stable:latest &
docker pull presidentbeef/brakeman:latest &
docker pull returntocorp/semgrep:latest &
docker pull aquasec/trivy:latest &
docker pull projectdiscovery/nuclei:latest &

# Wait for all pulls to complete
wait

echo -e "${GREEN} All images pulled${NC}"
echo ""

# Start containers using docker-compose
echo -e "${YELLOW} Starting security testing containers...${NC}"
docker compose -f docker-compose.security.yml up -d

echo ""
echo -e "${YELLOW} Waiting for containers to be ready...${NC}"
sleep 5

echo ""
echo -e "${GREEN} Security Lab is ready!${NC}"
echo ""

echo -e "${BLUE} Running Containers:${NC}"
docker ps --filter "name=prostaff-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(zap|brakeman|semgrep|trivy|nuclei)"

echo ""
echo -e "${BLUE} Next Steps:${NC}"
echo "  1. Run security scans: ./security_tests/run-security-scans.sh local"
echo "  2. View ZAP UI: http://localhost:8087"
echo "  3. Run smoke test: ./load_tests/run-tests.sh smoke local"
echo ""
echo -e "${YELLOW} Tip: Use './scripts/run-staging-tests.sh status' to check all services${NC}"
