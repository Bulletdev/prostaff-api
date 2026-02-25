#!/bin/bash
# Security Testing Automation Script
# Usage: ./run-security-scans.sh [environment]
# Example: ./run-security-scans.sh staging

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Determine environment
ENVIRONMENT=${1:-local}

echo -e "${GREEN} ProStaff API Security Scanner${NC}"
echo "================================"
echo "Environment: ${ENVIRONMENT}"
echo ""

# Set container names and API URL based on environment
if [[ "$ENVIRONMENT" == "staging" ]]; then
    API_CONTAINER="prostaff-api-staging"
    SEMGREP_CONTAINER="prostaff-semgrep-staging"
    TRIVY_CONTAINER="prostaff-trivy-staging"
    NUCLEI_CONTAINER="prostaff-nuclei-staging"
    ZAP_CONTAINER="prostaff-zap-staging"
    BRAKEMAN_CONTAINER="prostaff-brakeman-staging"
    API_URL="http://api-staging:3000"
else
    API_CONTAINER="prostaff-api"
    SEMGREP_CONTAINER="prostaff-semgrep"
    TRIVY_CONTAINER="prostaff-trivy"
    NUCLEI_CONTAINER="prostaff-nuclei"
    ZAP_CONTAINER="prostaff-zap"
    BRAKEMAN_CONTAINER="prostaff-brakeman"
    API_URL="http://prostaff-api:3000"
fi

echo -e "${YELLOW} Checking if API is accessible...${NC}"
if ! docker ps | grep -q "$API_CONTAINER"; then
    echo -e "${RED} ${API_CONTAINER} container is not running${NC}"
    if [[ "$ENVIRONMENT" == "staging" ]]; then
        echo "Start it with: ./scripts/deploy-staging.sh"
    else
        echo "Start it with: docker-compose up -d api"
    fi
    exit 1
fi

echo -e "${GREEN} ${API_CONTAINER} container is running${NC}"
echo ""

mkdir -p reports/{semgrep,trivy,nuclei,zap}

echo -e "${YELLOW} Running Security Scans...${NC}"
echo ""

# 1. Semgrep - Static Analysis
echo -e "${YELLOW}[1/5] Running Semgrep (Static Code Analysis)...${NC}"
if docker ps | grep -q "$SEMGREP_CONTAINER"; then
    docker exec "$SEMGREP_CONTAINER" semgrep \
        --config=auto \
        --json \
        --output=/reports/semgrep-report.json \
        /src 2>/dev/null || echo "Semgrep scan completed with findings"
    echo -e "${GREEN} Semgrep scan complete${NC}"
else
    echo -e "${YELLOW} Semgrep container not running, skipping${NC}"
fi
echo ""

# 2. Brakeman - Rails Security Scanner
echo -e "${YELLOW}[2/5] Running Brakeman (Rails Security)...${NC}"
if docker ps | grep -q "$BRAKEMAN_CONTAINER"; then
    # Restart to run scan (it runs once on startup)
    docker restart "$BRAKEMAN_CONTAINER" >/dev/null 2>&1
    sleep 5
    docker logs "$BRAKEMAN_CONTAINER" | tail -20
    echo -e "${GREEN} Brakeman scan complete${NC}"
else
    echo -e "${YELLOW} Brakeman container not running, skipping${NC}"
fi
echo ""

# 3. Trivy - Vulnerability Scanner
echo -e "${YELLOW}[3/5] Running Trivy (Dependency Vulnerabilities)...${NC}"
if docker ps | grep -q "$TRIVY_CONTAINER"; then
    docker exec "$TRIVY_CONTAINER" trivy fs \
        --format json \
        --output /reports/trivy-report.json \
        /app 2>/dev/null || echo "Trivy scan completed with findings"
    echo -e "${GREEN} Trivy scan complete${NC}"
else
    echo -e "${YELLOW} Trivy container not running, skipping${NC}"
fi
echo ""

# 4. Nuclei - Web Vulnerability Scanner
echo -e "${YELLOW}[4/5] Running Nuclei (Web Vulnerabilities)...${NC}"
if docker ps | grep -q "$NUCLEI_CONTAINER"; then
    docker exec "$NUCLEI_CONTAINER" nuclei \
        -u ${API_URL} \
        -json \
        -o /reports/nuclei-report.json \
        -silent 2>/dev/null || echo "Nuclei scan completed"
    echo -e "${GREEN} Nuclei scan complete${NC}"
else
    echo -e "${YELLOW} Nuclei container not running, skipping${NC}"
fi
echo ""

# 5. OWASP ZAP - Dynamic Application Security Testing
echo -e "${YELLOW}[5/5] Running ZAP Baseline Scan...${NC}"
echo "Note: ZAP scan may take several minutes"
if docker ps | grep -q "$ZAP_CONTAINER"; then
    docker exec "$ZAP_CONTAINER" zap-baseline.py \
        -t ${API_URL} \
        -J /zap/reports/zap-report.json \
        -r /zap/reports/zap-report.html \
        2>/dev/null || echo "ZAP scan completed"
    echo -e "${GREEN} ZAP scan complete${NC}"
else
    echo -e "${YELLOW} ZAP container not running, skipping${NC}"
fi
echo ""

echo -e "${GREEN} All security scans completed!${NC}"
echo ""
echo " Reports available in:"
echo "  - Brakeman:         security_tests/reports/brakeman/brakeman-report.html"
echo "  - Dependency Check: security_tests/reports/dependency-check/dependency-check-report.html"
echo "  - Semgrep:          security_tests/reports/semgrep/semgrep-report.json"
echo "  - Trivy:            security_tests/reports/trivy/trivy-report.json"
echo "  - Nuclei:           security_tests/reports/nuclei/nuclei-report.json"
echo "  - ZAP:              security_tests/zap/reports/zap-report.html"
echo ""
echo " View ZAP Web UI at: http://localhost:8087/zap"
