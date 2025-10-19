#!/bin/bash

echo "================================================"
echo "🎫 ProStaff API - JWT Token Generator"
echo "================================================"
echo ""

TEST_EMAIL="${TEST_EMAIL:-test@prostaff.gg}"
TEST_PASSWORD="${TEST_PASSWORD:-Test123!@#}"

echo "📧 Gerando token para: $TEST_EMAIL"
echo ""

TOKEN=$(bundle exec rails runner "
user = User.find_by(email: '$TEST_EMAIL')

if user.nil?
  puts '⚠️  Usuário não encontrado. Criando...'

  org = Organization.first_or_create!(
    name: 'Test Organization',
    slug: 'test-org',
    region: 'BR',
    tier: 'tier_1_professional'
  )

  user = User.create!(
    email: '$TEST_EMAIL',
    password: '$TEST_PASSWORD',
    password_confirmation: '$TEST_PASSWORD',
    full_name: 'Test User',
    role: 'owner',
    organization: org
  )

  puts '✅ Usuário criado com sucesso!'
end

tokens = Authentication::Services::JwtService.generate_tokens(user)
puts tokens[:access_token]
" 2>&1)

JWT_TOKEN=$(echo "$TOKEN" | tail -1)

echo "================================================"
echo "✅ Token JWT gerado com sucesso!"
echo "================================================"
echo ""
echo "📋 Token (válido por ${JWT_EXPIRATION_HOURS:-24} horas):"
echo ""
echo "$JWT_TOKEN"
echo ""
echo "================================================"
echo "💡 Como usar:"
echo "================================================"
echo ""
echo "# Exportar para variável de ambiente:"
echo "export BEARER_TOKEN=\"$JWT_TOKEN\""
echo ""
echo "# Usar no curl:"
echo "curl -H \"Authorization: Bearer \$BEARER_TOKEN\" http://localhost:3333/api/v1/players"
echo ""
echo "# Copiar para clipboard (Linux):"
echo "echo \"$JWT_TOKEN\" | xclip -selection clipboard"
echo ""
echo "================================================"
