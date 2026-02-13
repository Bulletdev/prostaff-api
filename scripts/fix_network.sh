#!/bin/bash

# ProStaff API - Network Troubleshooting Script
# Fixes 503 errors caused by Traefik not reaching the API container

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ProStaff API - Network Diagnostics${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Find Traefik network
echo -e "${YELLOW}Step 1: Detecting Traefik network...${NC}"
TRAEFIK_NETWORKS=$(docker network ls --filter "name=coolify" --format "{{.Name}}" 2>/dev/null)

if [ -z "$TRAEFIK_NETWORKS" ]; then
    echo -e "${YELLOW}⚠  'coolify' network not found, searching for alternatives...${NC}"
    TRAEFIK_NETWORKS=$(docker network ls --filter "name=traefik" --format "{{.Name}}" 2>/dev/null)
fi

if [ -z "$TRAEFIK_NETWORKS" ]; then
    echo -e "${RED}✗ No Traefik network found!${NC}"
    echo ""
    echo "Available networks:"
    docker network ls
    echo ""
    echo -e "${YELLOW}Please create the Traefik network manually:${NC}"
    echo "  docker network create coolify"
    exit 1
fi

echo -e "${GREEN}✓ Found Traefik network(s):${NC}"
echo "$TRAEFIK_NETWORKS" | while read network; do
    echo -e "  - ${GREEN}$network${NC}"
done

TRAEFIK_NETWORK=$(echo "$TRAEFIK_NETWORKS" | head -n1)
echo ""
echo -e "Using: ${GREEN}$TRAEFIK_NETWORK${NC}"

# Step 2: Check if API container exists
echo ""
echo -e "${YELLOW}Step 2: Checking API container status...${NC}"
if docker ps -a --filter "name=prostaff-api" --format "{{.Names}}" | grep -q "prostaff-api"; then
    STATUS=$(docker inspect prostaff-api --format '{{.State.Status}}')
    echo -e "${GREEN}✓ Container found: $STATUS${NC}"

    if [ "$STATUS" != "running" ]; then
        echo -e "${YELLOW}⚠  Container is not running. Starting...${NC}"
        docker start prostaff-api || echo -e "${RED}✗ Failed to start${NC}"
    fi
else
    echo -e "${YELLOW}⚠  Container not found. Deploy first with:${NC}"
    echo "  docker-compose -f docker-compose.production.yml up -d"
fi

# Step 3: Update docker-compose.yml network name
echo ""
echo -e "${YELLOW}Step 3: Updating docker-compose.yml...${NC}"

cd /home/bullet/PROJETOS/prostaff-api

# Backup first
if [ ! -f docker-compose.production.yml.backup ]; then
    cp docker-compose.production.yml docker-compose.production.yml.backup
    echo -e "${GREEN}✓ Backup created${NC}"
fi

# Update network name
sed -i "s/name: coolify/name: $TRAEFIK_NETWORK/" docker-compose.production.yml
echo -e "${GREEN}✓ Updated network name to: $TRAEFIK_NETWORK${NC}"

# Step 4: Reconnect container to Traefik network
echo ""
echo -e "${YELLOW}Step 4: Connecting container to Traefik network...${NC}"

if docker ps --filter "name=prostaff-api" --format "{{.Names}}" | grep -q "prostaff-api"; then
    # Check if already connected
    if docker network inspect "$TRAEFIK_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q "prostaff-api"; then
        echo -e "${GREEN}✓ Already connected to $TRAEFIK_NETWORK${NC}"
    else
        echo -e "${YELLOW}Connecting...${NC}"
        docker network connect "$TRAEFIK_NETWORK" prostaff-api 2>/dev/null && \
            echo -e "${GREEN}✓ Connected successfully${NC}" || \
            echo -e "${YELLOW}⚠  Already connected or connection failed${NC}"
    fi
fi

# Step 5: Check CORS configuration
echo ""
echo -e "${YELLOW}Step 5: Verifying CORS configuration...${NC}"

if [ -f config/initializers/cors.rb ]; then
    if grep -q "origins.*\*" config/initializers/cors.rb; then
        echo -e "${GREEN}✓ CORS allows all origins${NC}"
    elif grep -q "prostaff.gg" config/initializers/cors.rb; then
        echo -e "${GREEN}✓ CORS configured for prostaff.gg${NC}"
    else
        echo -e "${RED}✗ CORS may need configuration${NC}"
        echo "Check: config/initializers/cors.rb"
    fi
else
    echo -e "${YELLOW}⚠  CORS file not found${NC}"
fi

# Step 6: Test connectivity
echo ""
echo -e "${YELLOW}Step 6: Testing container connectivity...${NC}"

if docker ps --filter "name=prostaff-api" --format "{{.Names}}" | grep -q "prostaff-api"; then
    IP=$(docker inspect prostaff-api --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
    echo -e "Container IP: ${GREEN}$IP${NC}"

    # Test internal connectivity
    if docker exec prostaff-api curl -sf http://localhost:3000/up > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API responds on internal port 3000${NC}"
    else
        echo -e "${RED}✗ API not responding internally${NC}"
        echo "Check logs with: docker logs prostaff-api"
    fi
fi

# Step 7: Show next steps
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Restart the stack:"
echo "   ${YELLOW}docker-compose -f docker-compose.production.yml down${NC}"
echo "   ${YELLOW}docker-compose -f docker-compose.production.yml up -d${NC}"
echo ""
echo "2. Check logs:"
echo "   ${YELLOW}docker logs -f prostaff-api${NC}"
echo ""
echo "3. Test the endpoint:"
echo "   ${YELLOW}curl -I https://api.prostaff.gg/up${NC}"
echo ""
echo "4. Test CORS:"
echo "   ${YELLOW}curl -H \"Origin: https://prostaff.gg\" -I https://api.prostaff.gg/up${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
