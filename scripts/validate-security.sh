#!/bin/bash

# Script para validar segurança antes de fazer commit
# Roda Semgrep localmente e mostra apenas erros críticos

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "================================================"
echo " Security Validation Script"
echo "================================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar se docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando!${NC}"
    echo "Por favor, inicie o Docker e tente novamente."
    exit 1
fi

echo -e "${BLUE}🔍 Rodando Semgrep...${NC}"
echo ""

# Rodar Semgrep
docker run --rm \
    -v "$PROJECT_ROOT:/src" \
    returntocorp/semgrep \
    semgrep scan \
        --config=auto \
        --json \
        --exclude='scripts/*.rb' \
        --exclude='scripts/*.sh' \
        --exclude='load_tests/**' \
        --exclude='security_tests/**' \
        -o /src/semgrep-report-temp.json 2>&1 | grep -v "Scanning\|Language\|Rules\|Files\|Origin" || true

echo ""
echo "================================================"
echo "📊 Analisando resultados..."
echo "================================================"
echo ""

# Analisar resultados
if [ -f "$PROJECT_ROOT/semgrep-report-temp.json" ]; then
    RESULT=$(python3 << 'EOF'
import json
import sys

try:
    with open('semgrep-report-temp.json', 'r') as f:
        data = json.load(f)

    results = data.get('results', [])
    errors = [r for r in results if r['extra']['severity'] == 'ERROR']
    warnings = [r for r in results if r['extra']['severity'] == 'WARNING']
    infos = [r for r in results if r['extra']['severity'] == 'INFO']

    print(f"ERRORS={len(errors)}")
    print(f"WARNINGS={len(warnings)}")
    print(f"INFOS={len(infos)}")

    if errors:
        print("\n=== ERRORS ===")
        for i, e in enumerate(errors, 1):
            print(f"\n{i}. {e['path']}:{e['start']['line']}")
            print(f"   Rule: {e['check_id']}")
            print(f"   Message: {e['extra']['message'][:150]}...")

    sys.exit(0 if len(errors) == 0 else 1)

except Exception as ex:
    print(f"ERROR: Falha ao analisar resultados: {ex}")
    sys.exit(2)
EOF
)
    EXIT_CODE=$?

    ERRORS=$(echo "$RESULT" | grep "^ERRORS=" | cut -d'=' -f2)
    WARNINGS=$(echo "$RESULT" | grep "^WARNINGS=" | cut -d'=' -f2)
    INFOS=$(echo "$RESULT" | grep "^INFOS=" | cut -d'=' -f2)

    echo -e "${BLUE} Resumo:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$ERRORS" -gt 0 ]; then
        echo -e "${RED}❌ Erros (CRITICAL):  $ERRORS${NC}"
    else
        echo -e "${GREEN}✅ Erros (CRITICAL):  $ERRORS${NC}"
    fi

    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warnings:          $WARNINGS${NC}"
    else
        echo -e "${GREEN}✅ Warnings:          $WARNINGS${NC}"
    fi

    echo -e "${BLUE}ℹ️  Info:             $INFOS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "$RESULT" | grep -A 100 "=== ERRORS ===" || true

    rm -f "$PROJECT_ROOT/semgrep-report-temp.json"

    echo ""
    echo "================================================"
    if [ "$EXIT_CODE" -eq 0 ]; then
        echo -e "${GREEN}✅ PASSOU - Sem erros críticos encontrados!${NC}"
        echo -e "${GREEN}   Você pode fazer o commit com segurança.${NC}"
    else
        echo -e "${RED}❌ FALHOU - Erros críticos encontrados!${NC}"
        echo -e "${RED}   Por favor, corrija os erros antes de commitar.${NC}"
    fi
    echo "================================================"
    echo ""

    exit $EXIT_CODE
else
    echo -e "${RED}❌ Falha ao gerar relatório do Semgrep${NC}"
    exit 1
fi
