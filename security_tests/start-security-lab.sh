#!/bin/bash
# Start Complete Security Testing Lab

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN} Starting ProStaff Security Testing Lab${NC}"
echo "=========================================="
echo ""

cd /home/bullet/PROJETOS/prostaff-api

echo -e "${YELLOW} Starting security tools containers...${NC}"
docker compose -f security_tests/docker-compose.security.yml -p security_tests up -d
echo -e "${GREEN}✓ Security tools started${NC}"
echo ""

echo -e "${YELLOW} Starting ProStaff API application...${NC}"
docker-compose up -d api postgres redis
echo -e "${GREEN}✓ Application started${NC}"
echo ""

echo -e "${YELLOW}⏳ Waiting for API to be ready...${NC}"
for i in {1..30}; do
    if docker exec prostaff-api curl -sf http://localhost:3000/up > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API is healthy${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED} API health check timeout. You may need to check logs.${NC}"
    fi
    sleep 2
done
echo ""

echo -e "${GREEN} Security Lab is ready!${NC}"
echo ""
echo " Available Services:"
echo "  • ProStaff API:    http://localhost:3333"
echo "  • ZAP Web UI:      http://localhost:8087/zap"
echo "  • ZAP API:         http://localhost:8097"
echo "  • PostgreSQL:      localhost:5432"
echo "  • Redis:           localhost:6379"
echo ""
echo "🔍 Running Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep prostaff
echo ""
echo " Next Steps:"
echo "  1. Run security scans:"
echo "     ./security_tests/run-security-scans.sh"
echo ""
echo "  2. View individual reports in:"
echo "     security_tests/reports/"
echo ""
echo "  3. Stop everything:"
echo "     ./security_tests/stop-security-lab.sh"
