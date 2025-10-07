#!/bin/bash

echo "================================================"
echo "🔐 ProStaff API - Secret Generator"
echo "================================================"
echo ""
echo "Cole esses valores no seu arquivo .env:"
echo ""

echo "# Rails Secret Key Base"
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
echo ""

echo "# JWT Secret Key"
echo "JWT_SECRET_KEY=$(openssl rand -hex 64)"
echo ""

echo "================================================"
echo "✅ Secrets gerados com sucesso!"
echo "================================================"
