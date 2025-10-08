#!/bin/bash
# OWASP ZAP Security Testing Setup

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔐 Setting up OWASP ZAP Security Lab${NC}"

mkdir -p security_tests/zap/{scripts,reports,policies}
mkdir -p security_tests/reports/{zap,brakeman,semgrep,nuclei,trivy,dependency-check}

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${YELLOW}📦 Pulling security tool images...${NC}"
docker-compose -f security_tests/docker-compose.security.yml pull

echo -e "${GREEN}✅ Security lab setup complete!${NC}"
echo ""
echo "Available tools:"
echo "  • OWASP ZAP          - Web application security scanner"
echo "  • Brakeman           - Rails security analysis"
echo "  • Semgrep            - Static code analysis"
echo "  • Trivy              - Container vulnerability scanning"
echo "  • Dependency Check   - Library vulnerability scanning"
echo "  • Nuclei             - Fast vulnerability scanner"
echo ""
echo "Start the lab:"
echo "  docker-compose -f security_tests/docker-compose.security.yml up -d"
