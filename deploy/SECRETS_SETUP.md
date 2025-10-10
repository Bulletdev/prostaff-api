# Configuração de Secrets e Variáveis

Guia para configurar todos os secrets necessários para deploy em produção.

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
- `RAILS_ENV` - Ambiente (staging/production)
- `SECRET_KEY_BASE` - Secret para sessions
- `JWT_SECRET_KEY` - Secret para JWT tokens

### Database
- `DATABASE_URL` - URL completa de conexão PostgreSQL
- `POSTGRES_USER` - Usuário do banco
- `POSTGRES_PASSWORD` - Senha forte do banco
- `POSTGRES_DB` - Nome do banco

### Redis
- `REDIS_URL` - URL de conexão Redis
- `REDIS_PASSWORD` - Senha do Redis

### External APIs
- `RIOT_API_KEY` - API key da Riot Games

### Email
- `SMTP_ADDRESS` - Servidor SMTP
- `SMTP_USERNAME` - Usuário SMTP
- `SMTP_PASSWORD` - Senha SMTP

### Storage (AWS S3)
- `AWS_ACCESS_KEY_ID` - Access key da AWS
- `AWS_SECRET_ACCESS_KEY` - Secret key da AWS
- `AWS_REGION` - Região (ex: us-east-1)
- `AWS_S3_BUCKET` - Nome do bucket

### Monitoring (Opcional)
- `SENTRY_DSN` - DSN do Sentry para error tracking

## Verificar Configuração

```bash
# Testar conexão SSH
ssh deploy@api.prostaff.gg

# Verificar variáveis de ambiente no servidor
docker-compose -f docker-compose.production.yml exec api env | sort

# Testar conexão com banco
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:migrate:status

# Testar Redis
docker-compose -f docker-compose.production.yml exec redis redis-cli ping
```

## Rotação de Secrets

Recomendação: Rotacionar secrets a cada 90 dias.

```bash
# 1. Gerar novos secrets
NEW_SECRET=$(openssl rand -hex 64)

# 2. Atualizar .env no servidor
nano .env  # Adicionar novo secret

# 3. Restart gradual dos serviços
docker-compose -f docker-compose.production.yml restart api

# 4. Validar funcionamento

# 5. Remover secret antigo do .env
```
