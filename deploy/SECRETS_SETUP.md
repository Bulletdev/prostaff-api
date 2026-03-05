# Configuração de Secrets e Variáveis

Guia para configurar secrets necessários para deploy em produção.

## IMPORTANTE - Documentação Atualizada

Este arquivo contém informações legadas. A documentação oficial está em:

**[DOCS/deployment/SECRETS_SETUP.md](../DOCS/deployment/SECRETS_SETUP.md)** - Guia completo de secrets

## GitHub Secrets

Configure estes secrets no GitHub (Settings → Secrets and variables → Actions):

### Staging Environment

```
STAGING_HOST=staging-api.prostaff.gg
STAGING_USER=deploy
STAGING_SSH_KEY=<SSH private key content>
STAGING_ENV=<Conteúdo completo do .env>
```

### Production Environment

```
PRODUCTION_HOST=api.prostaff.gg
PRODUCTION_USER=deploy
PRODUCTION_SSH_KEY=<SSH private key content>
PRODUCTION_ENV=<Conteúdo completo do .env>
```

### Geral

```
DOCKER_USERNAME=<seu_usuario_dockerhub>
DOCKER_PASSWORD=<seu_token_dockerhub>
```

## Gerar Secrets Fortes

```bash
# SECRET_KEY_BASE, JWT_SECRET_KEY, etc.
bundle exec rails secret

# Ou usando OpenSSL
openssl rand -hex 64

# Senha de banco de dados (32 caracteres)
openssl rand -base64 32
```

## Configurar SSH para Deploy

```bash
# No seu computador local
ssh-keygen -t ed25519 -C "deploy@prostaff-api"

# Copiar chave pública para o servidor
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@api.prostaff.gg

# Adicionar chave privada ao GitHub Secrets
cat ~/.ssh/id_ed25519  # Copiar conteúdo completo
```

## Variáveis de Ambiente Obrigatórias

### Application

```bash
RAILS_ENV=production
RAILS_MASTER_KEY=<master_key_do_credentials.yml.enc>
SECRET_KEY_BASE=<64_hex_chars>
JWT_SECRET_KEY=<64_hex_chars>
RAILS_LOG_TO_STDOUT=true
PORT=3000
```

### Database (Supabase ou outro provider)

```bash
DATABASE_URL=postgresql://user:pass@host:port/dbname
```

### Redis

```bash
REDIS_URL=redis://redis:6379/0
REDIS_PASSWORD=<senha_forte>
```

### External APIs

```bash
RIOT_API_KEY=<riot_games_api_key>
PANDASCORE_API_KEY=<pandascore_api_key>
OPENAI_API_KEY=<openai_api_key>
```

### Search

```bash
MEILISEARCH_HOST=http://meilisearch:7700
MEILISEARCH_API_KEY=<meilisearch_master_key>
```

### CORS

```bash
CORS_ORIGINS=https://prostaff.gg,https://app.prostaff.gg
```

### Email (Opcional)

```bash
SMTP_ADDRESS=smtp.example.com
SMTP_USERNAME=user@example.com
SMTP_PASSWORD=<senha_smtp>
SMTP_PORT=587
SMTP_DOMAIN=example.com
```

### Storage - AWS S3 (Opcional)

```bash
AWS_ACCESS_KEY_ID=<access_key>
AWS_SECRET_ACCESS_KEY=<secret_key>
AWS_REGION=us-east-1
AWS_S3_BUCKET=prostaff-uploads
```

### Monitoring (Opcional)

```bash
SENTRY_DSN=<sentry_dsn_url>
```

## Verificar Configuração

### Testar conexão SSH

```bash
ssh deploy@api.prostaff.gg
```

### Verificar variáveis no container

```bash
docker-compose -f docker/docker-compose.production.yml exec api env | sort
```

### Testar conexão com banco

```bash
docker-compose -f docker/docker-compose.production.yml exec api bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').to_a"
```

### Testar Redis

```bash
docker-compose -f docker/docker-compose.production.yml exec api bundle exec rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping"
```

### Testar Meilisearch

```bash
curl http://meilisearch:7700/health
```

## Rotação de Secrets

Recomendação: Rotacionar secrets críticos a cada 90 dias.

### Rotacionar JWT_SECRET_KEY

```bash
# 1. Gerar novo secret
NEW_JWT_SECRET=$(openssl rand -hex 64)

# 2. Adicionar ao .env no servidor
echo "JWT_SECRET_KEY_NEW=$NEW_JWT_SECRET" >> .env

# 3. Atualizar aplicação para aceitar ambos (OLD + NEW)
# Ver app/modules/authentication/services/jwt_service.rb

# 4. Deploy da mudança
git push origin master

# 5. Após validação, remover secret antigo
# Editar .env e remover JWT_SECRET_KEY antigo
# Renomear JWT_SECRET_KEY_NEW para JWT_SECRET_KEY

# 6. Restart dos serviços
docker-compose -f docker/docker-compose.production.yml restart api sidekiq
```

### Rotacionar DATABASE_PASSWORD

```bash
# 1. No provider (Supabase/Neon/RDS): alterar senha
# 2. Atualizar DATABASE_URL no .env
# 3. Restart dos serviços
docker-compose -f docker/docker-compose.production.yml restart api sidekiq
# 4. Validar funcionamento
curl https://api.prostaff.gg/up
```

### Rotacionar REDIS_PASSWORD

```bash
# 1. Atualizar senha no Redis
docker-compose -f docker/docker-compose.production.yml exec redis redis-cli CONFIG SET requirepass <nova_senha>

# 2. Atualizar REDIS_URL no .env
nano .env

# 3. Restart dos serviços
docker-compose -f docker/docker-compose.production.yml restart api sidekiq

# 4. Validar
docker-compose -f docker/docker-compose.production.yml exec api bundle exec rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping"
```

## Backup de Secrets

NUNCA commitar secrets no repositório. Use um gerenciador de senhas seguro:

- 1Password
- Bitwarden
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault

## Troubleshooting

### Erro: "JWT token invalid"

```bash
# Verificar se JWT_SECRET_KEY está configurado
docker-compose -f docker/docker-compose.production.yml exec api env | grep JWT_SECRET_KEY

# Verificar se o secret não contém espaços ou quebras de linha
```

### Erro: "Database connection failed"

```bash
# Verificar DATABASE_URL
docker-compose -f docker/docker-compose.production.yml exec api env | grep DATABASE_URL

# Testar conexão manual
docker-compose -f docker/docker-compose.production.yml exec api bundle exec rails dbconsole
```

### Erro: "Redis connection refused"

```bash
# Verificar se Redis está rodando
docker-compose -f docker/docker-compose.production.yml ps redis

# Verificar REDIS_URL
docker-compose -f docker/docker-compose.production.yml exec api env | grep REDIS_URL

# Testar conexão
docker-compose -f docker/docker-compose.production.yml exec redis redis-cli ping
```

## Suporte

Para documentação completa:

- [DOCS/deployment/SECRETS_SETUP.md](../DOCS/deployment/SECRETS_SETUP.md) - Guia completo atualizado
- [DOCS/deployment/DEPLOYMENT.md](../DOCS/deployment/DEPLOYMENT.md) - Deploy guide
- [.env.production.example](../.env.production.example) - Template de variáveis
