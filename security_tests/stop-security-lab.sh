#!/bin/bash
# Stop Security Testing Lab

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🛑 Stopping ProStaff Security Lab...${NC}"

cd /home/bullet/PROJETOS/prostaff-api

docker compose -f security_tests/docker-compose.security.yml -p security_tests down

# Stop application (optional - uncomment if needed...)
# docker-compose down

echo -e "${GREEN}✅ Security lab stopped${NC}"
