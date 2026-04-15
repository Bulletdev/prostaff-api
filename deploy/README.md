# Deploy Files

Este diretório contém scripts e configurações auxiliares para deploy.

## IMPORTANTE - Documentação Atual

A documentação oficial e atualizada de deploy está em:

**[DOCS/deployment/DEPLOYMENT.md](../DOCS/deployment/DEPLOYMENT.md)** - Guia completo de deploy via Coolify

Para configuração de secrets, veja:

**[DOCS/deployment/SECRETS_SETUP.md](../DOCS/deployment/SECRETS_SETUP.md)** - Configuração de secrets

## Estrutura Atual

```
deploy/
├── scripts/              # Scripts de manutenção
│   ├── backup.sh         # Backup de banco de dados
│   ├── deploy.sh         # Deploy manual (legacy)
│   ├── docker-entrypoint.sh  # Entrypoint do container
│   └── rollback.sh       # Rollback manual (legacy)
├── ssl/                  # Certificados SSL (não commitar!)
└── SECRETS_SETUP.md      # Guia de secrets (legacy)
```

## Stack Atual

```
Ruby 3.4.8
Rails 7.2
PostgreSQL 15+ (Supabase)
Redis 7.2 (via Coolify)
Sidekiq 7.0 (background jobs)
Meilisearch v1.11 (search)
Docker multi-stage
Coolify (deploy automation)
Traefik (reverse proxy via Coolify)
```

## Arquivos Importantes

- `../DOCS/deployment/DEPLOYMENT.md` - Guia completo de deployment
- `../DOCS/deployment/SECRETS_SETUP.md` - Configuração de secrets
- `../DOCS/deployment/QUICK_DEPLOY.md` - Quick start guide
- `../.env.production.example` - Exemplo de variáveis production
- `../.env.staging.example` - Exemplo de variáveis staging
- `../docker/docker-compose.production.yml` - Docker Compose para produção

## Quick Start

### 1. Deploy via Coolify (Recomendado)

O deploy em produção é feito via Coolify com GitHub Actions. Ver documentação completa:

```bash
# Ler documentação
cat ../DOCS/deployment/DEPLOYMENT.md
```

### 2. Deploy Manual (Legacy)

Para deploy manual sem Coolify:

```bash
# Clone o repositório
git clone https://github.com/bulletdev/prostaff-api.git
cd prostaff-api

# Copiar e configurar ambiente
cp .env.production.example .env
nano .env

# Build e iniciar com Docker Compose
docker-compose -f docker/docker-compose.production.yml up -d

# Ver logs
docker-compose -f docker/docker-compose.production.yml logs -f api

# Verificar saúde
curl https://api.prostaff.gg/up
```

## Scripts de Manutenção

### Backup

```bash
# Backup manual
docker-compose -f docker/docker-compose.production.yml exec api bash /app/deploy/scripts/backup.sh

# Backup automático (via cron)
# Ver scripts/backup_database.sh no diretório raiz
```

### Logs

```bash
# Logs da API
docker-compose -f docker/docker-compose.production.yml logs -f api

# Logs do Sidekiq
docker-compose -f docker/docker-compose.production.yml logs -f sidekiq

# Logs do Redis
docker-compose -f docker/docker-compose.production.yml logs -f redis
```

### Restart

```bash
# Restart de serviços específicos
docker-compose -f docker/docker-compose.production.yml restart api
docker-compose -f docker/docker-compose.production.yml restart sidekiq

# Restart completo
docker-compose -f docker/docker-compose.production.yml restart
```

### Atualizar

```bash
# Pull + rebuild + restart
git pull origin master
docker-compose -f docker/docker-compose.production.yml up -d --build

# Com zero downtime (via Coolify)
# Push para main -> GitHub Actions -> Coolify deploy automatico
```

## Health Checks

```bash
# API health
curl https://api.prostaff.gg/up

# Health completo (database + redis + meilisearch)
curl https://api.prostaff.gg/health/ready

# Status page
curl https://status.prostaff.gg
```

## Variáveis de Ambiente

Ver arquivo `.env.production.example` para lista completa.

Principais variáveis:

```bash
RAILS_ENV=production
DATABASE_URL=postgresql://...  # Supabase ou outro provider
REDIS_URL=redis://redis:6379/0
JWT_SECRET_KEY=...
RIOT_API_KEY=...
CORS_ORIGINS=https://prostaff.gg
```

## Troubleshooting

### Logs estruturados

A aplicação usa Lograge para logs estruturados em JSON:

```bash
# Ver logs em formato JSON
docker-compose -f docker/docker-compose.production.yml logs api | grep "method="

# Filtrar por erro
docker-compose -f docker/docker-compose.production.yml logs api | grep "status=500"

# Filtrar por endpoint
docker-compose -f docker/docker-compose.production.yml logs api | grep "path=/api/v1"
```

### Redis não conecta

```bash
# Verificar se Redis está rodando
docker-compose -f docker/docker-compose.production.yml ps redis

# Verificar conectividade
docker-compose -f docker/docker-compose.production.yml exec api bash -c "echo > /dev/tcp/redis/6379 && echo 'Redis OK'"

# Logs do Redis
docker-compose -f docker/docker-compose.production.yml logs redis
```

### Banco não conecta

```bash
# Testar conexão PostgreSQL
docker-compose -f docker/docker-compose.production.yml exec api bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').to_a"

# Ver status de migrations
docker-compose -f docker/docker-compose.production.yml exec api bundle exec rails db:migrate:status
```

## Suporte

Para documentação completa e troubleshooting detalhado:

- [DEPLOYMENT.md](../DOCS/deployment/DEPLOYMENT.md) - Guia completo
- [QUICK_DEPLOY.md](../DOCS/deployment/QUICK_DEPLOY.md) - Quick start
- [README.md](../README.md) - Documentação do projeto
- [CLAUDE.md](../.claude/CLAUDE.md) - Contexto técnico completo
