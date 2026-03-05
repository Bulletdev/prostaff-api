# ProStaff API - Guia de Deploy

Guia de referencia para deploy da aplicacao em producao via Coolify.

## Indice

- [Infraestrutura](#infraestrutura)
- [Pre-requisitos](#pre-requisitos)
- [Configuracao de Ambiente](#configuracao-de-ambiente)
- [CI/CD - GitHub Actions](#cicd---github-actions)
- [Deploy Manual](#deploy-manual)
- [Servicos e Portas](#servicos-e-portas)
- [Health Checks](#health-checks)
- [Backup e Restauracao](#backup-e-restauracao)
- [Manutencao](#manutencao)
- [Troubleshooting](#troubleshooting)

---

## Infraestrutura

A aplicacao roda via **Coolify** (self-hosted PaaS) com **Traefik** como reverse proxy. O SSL e gerenciado automaticamente pelo Coolify via Let's Encrypt.

### Stack

| Componente    | Tecnologia               | Versao     |
|---------------|--------------------------|------------|
| Runtime       | Ruby                     | 3.4.5      |
| Framework     | Rails                    | 7.2        |
| Servidor web  | Puma                     | ~> 6.0     |
| Banco de dados| PostgreSQL               | 15+        |
| Cache/Jobs    | Redis                    | 7.2        |
| Busca         | Meilisearch              | v1.11      |
| Background    | Sidekiq + sidekiq-scheduler | ~> 7.0  |
| Container     | Docker (multi-stage)     | -          |
| Proxy         | Traefik (via Coolify)    | -          |
| Deploy        | Coolify + GitHub Actions | -          |

### Dominios

| Servico        | Dominio                  |
|----------------|--------------------------|
| API            | `api.prostaff.gg`        |
| Status page    | `status.prostaff.gg`     |
| Documentacao   | `docs.prostaff.gg`       |

### Servicos Docker (producao)

O `docker/docker-compose.production.yml` sobe os seguintes servicos na rede `coolify`:

- `redis` - Redis 7.2 com autenticacao por senha
- `meilisearch` - Meilisearch v1.11 (busca full-text)
- `api` - Rails API via Puma, exposta na porta 3000
- `sidekiq` - Worker de background jobs
- `status` - Status page estatica (status.prostaff.gg)
- `docs` - Documentacao estatica (docs.prostaff.gg)

O banco de dados PostgreSQL e externo (DATABASE_URL apontando para Supabase ou outro provider).

---

## Pre-requisitos

### Servidor

- Coolify instalado e configurado
- Docker e Docker Compose disponiveis
- Rede Docker `coolify` criada
- Acesso SSH para operacoes manuais (se necessario)

### Repositorio

- Acesso ao repositorio GitHub
- GitHub Secrets configurados (ver [SECRETS_SETUP.md](SECRETS_SETUP.md))
- GitHub Environments configurados: `staging`, `production-approval`, `production`

### Servicos externos

- **PostgreSQL** - Provider gerenciado (Supabase, Neon, RDS, etc.)
- **Redis** - Container Docker na rede `coolify`
- **Riot API** - Chave de API da Riot Games
- **Elasticsearch** - Instancia acessivel via URL (opcional para analytics avancado)

---

## Configuracao de Ambiente

### Variaveis obrigatorias

Estas variaveis devem estar presentes no ambiente de producao:

```bash
# Rails
RAILS_ENV=production
RAILS_MASTER_KEY=<master_key_do_credentials.yml.enc>
SECRET_KEY_BASE=<64_hex_chars>
RAILS_LOG_TO_STDOUT=true
PORT=3000

# Banco de dados
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Redis
REDIS_URL=redis://default:<REDIS_PASSWORD>@redis:6379/0
REDIS_PASSWORD=<senha_forte>

# JWT
JWT_SECRET_KEY=<chave_jwt>

# HashID (ofuscacao de IDs)
HASHID_SALT=<salt_aleatorio>
HASHID_MIN_LENGTH=8

# Riot API
RIOT_API_KEY=<chave_riot_games>

# Meilisearch
MEILISEARCH_URL=http://meilisearch:7700
MEILI_MASTER_KEY=<chave_meilisearch>

# CORS
CORS_ORIGINS=https://prostaff.gg,https://www.prostaff.gg,https://api.prostaff.gg,https://status.prostaff.gg,https://docs.prostaff.gg

# Frontend
FRONTEND_URL=https://prostaff.gg
APP_HOST=api.prostaff.gg

# Elasticsearch (opcional)
ELASTICSEARCH_URL=http://elastic:9200
```

### Gerando secrets

```bash
# RAILS_MASTER_KEY - obtido de config/master.key (nunca commitar)
cat config/master.key

# SECRET_KEY_BASE
bundle exec rails secret
# ou
openssl rand -hex 64

# JWT_SECRET_KEY
openssl rand -hex 64

# HASHID_SALT
openssl rand -hex 32

# REDIS_PASSWORD
openssl rand -base64 32

# MEILI_MASTER_KEY
openssl rand -hex 32
```

---

## CI/CD - GitHub Actions

O pipeline automatizado e definido em `.github/workflows/`.

### Workflows disponiveis

| Workflow                  | Arquivo                       | Gatilho                              |
|---------------------------|-------------------------------|--------------------------------------|
| Deploy Staging            | `deploy-staging.yml`          | Push em `develop`                    |
| Deploy Production         | `deploy-production.yml`       | Tag `v*.*.*` ou trigger manual       |
| Security Scan             | `security-scan.yml`           | Push em `master`/`develop`, PRs, semanal |
| Load Test                 | `load-test.yml`               | Manual, schedule noturno             |
| Nightly Security Audit    | `nightly-security.yml`        | Toda noite, 1h UTC                   |

### Deploy em staging

```bash
# Push para develop dispara deploy automatico
git checkout develop
git push origin develop

# Ou disparo manual via GitHub CLI
gh workflow run deploy-staging.yml
```

O pipeline de staging executa:
1. Testes RSpec
2. RuboCop
3. Brakeman
4. Build da imagem Docker
5. Deploy no servidor de staging
6. Health check pos-deploy

### Deploy em producao

```bash
# Criar tag semantica dispara deploy de producao
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# Ou disparo manual
gh workflow run deploy-production.yml -f version=v1.2.0
```

O pipeline de producao executa:
1. Validacao do formato da tag (semver obrigatorio)
2. Suite completa de testes (RSpec, RuboCop, Brakeman)
3. Scan de segurança (Trivy)
4. Build da imagem Docker (publicada no GHCR: `ghcr.io/<org>/prostaff-api`)
5. **Aprovacao manual obrigatoria** (ambiente `production-approval`)
6. Backup do banco antes do deploy
7. Rolling update zero-downtime
8. Migrations
9. Health checks
10. Rollback automatico em caso de falha
11. Criacao de GitHub Release

### Fluxo de branches

```
feature/* -> develop -> staging (auto-deploy)
                   |
                review/QA
                   |
              master + tag -> production (aprovacao manual)
```

---

## Deploy Manual

Para situacoes que exigem intervencao direta no servidor.

### Via scripts

```bash
# Deploy em staging
./deploy/scripts/deploy.sh staging

# Deploy em producao
./deploy/scripts/deploy.sh production

# Rollback
./deploy/scripts/rollback.sh staging
./deploy/scripts/rollback.sh production
```

### Via Docker Compose direto

```bash
# No servidor, dentro do diretorio do projeto
cd /var/www/prostaff-api

# Atualizar codigo
git pull origin master

# Build e subir servicos
docker compose -f docker/docker-compose.production.yml up -d --build

# Executar migrations
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails db:migrate

# Verificar logs
docker compose -f docker/docker-compose.production.yml logs -f api

# Health check
curl https://api.prostaff.gg/up
```

### Rollback manual

```bash
# Reverter para commit anterior
git checkout <commit-hash>
docker compose -f docker/docker-compose.production.yml up -d --force-recreate

# Reverter ultima migration
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails db:rollback STEP=1
```

---

## Servicos e Portas

### Desenvolvimento local

```bash
# Subir apenas Redis + API + Sidekiq (sem PostgreSQL local)
docker compose up -d

# Subir com PostgreSQL local (desenvolvimento offline)
docker compose --profile local-db up -d
```

A API roda localmente na porta `3333` (configuravel via `API_PORT` no `.env`).
Redis roda na porta `6380` (configuravel via `REDIS_PORT`).

### Producao (rede `coolify`)

Os servicos nao expõem portas diretamente. O Traefik roteia o trafego externo via labels Docker:

- `api.prostaff.gg` -> container `api` (porta 3000)
- `status.prostaff.gg` -> container `status` (porta 80)
- `docs.prostaff.gg` -> container `docs` (porta 80)

O Meilisearch (porta 7700) e o Redis (porta 6379) sao acessiveis apenas internamente na rede `coolify`.

---

## Health Checks

### Endpoints

| Endpoint           | Descricao                             | Uso                          |
|--------------------|---------------------------------------|------------------------------|
| `GET /up`          | Retorna 200 "ok" (sem DB)            | Traefik, Docker healthcheck  |
| `GET /health`      | JSON `{"status":"ok","service":"..."}` | Monitoramento simples        |
| `GET /health/detailed` | Health com verificacao do banco  | Diagnostico                  |
| `GET /status`      | Status page API                       | status.prostaff.gg           |

```bash
# Verificar saude da API
curl https://api.prostaff.gg/up
# -> ok

curl https://api.prostaff.gg/health
# -> {"status":"ok","service":"ProStaff API"}

# Verificar Redis
docker compose -f docker/docker-compose.production.yml exec redis redis-cli -a $REDIS_PASSWORD ping
# -> PONG

# Verificar Meilisearch
curl http://meilisearch:7700/health  # dentro da rede coolify
```

### Docker healthcheck (configurado no Dockerfile.production)

```
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3
  CMD curl -f http://localhost:3000/up || exit 1
```

---

## Backup e Restauracao

### Backup do banco

```bash
# Backup manual via script
./scripts/backup_database.sh

# Backup via Docker Compose
docker compose -f docker/docker-compose.production.yml run --rm backup

# Backup direto com pg_dump (substituir variaveis)
pg_dump $DATABASE_URL | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

O pipeline de producao cria backup automatico antes de cada deploy.

### Restaurar backup

```bash
# Listar backups disponiveis
ls -lh backups/

# Restaurar
gunzip < backups/backup_YYYYMMDD_HHMMSS.sql.gz | psql $DATABASE_URL
```

### Retencao

Backups sao mantidos por 30 dias por padrao. Limpeza manual:

```bash
find backups/ -name "*.sql.gz" -mtime +30 -delete
```

---

## Manutencao

### Atualizar gems

```bash
# Dentro do container
docker compose -f docker/docker-compose.production.yml exec api bundle update

# Rebuild apos atualizacao
docker compose -f docker/docker-compose.production.yml up -d --build api
```

### Limpar recursos Docker

```bash
# Remover containers parados
docker container prune -f

# Remover imagens nao utilizadas (manter ultimas 72h)
docker image prune -af --filter "until=72h"

# Remover volumes orfaos (CUIDADO: nao executar em producao sem verificar)
docker volume prune -f
```

### Console Rails

```bash
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails console
```

### Ver logs

```bash
# Todos os servicos
docker compose -f docker/docker-compose.production.yml logs -f

# Servico especifico
docker compose -f docker/docker-compose.production.yml logs -f api
docker compose -f docker/docker-compose.production.yml logs -f sidekiq
docker compose -f docker/docker-compose.production.yml logs -f meilisearch
```

### Reiniciar servicos

```bash
# Reiniciar tudo
docker compose -f docker/docker-compose.production.yml restart

# Reiniciar servico especifico
docker compose -f docker/docker-compose.production.yml restart api
docker compose -f docker/docker-compose.production.yml restart sidekiq
```

---

## Troubleshooting

### API nao sobe

```bash
# Ver logs detalhados
docker compose -f docker/docker-compose.production.yml logs api

# Verificar variaveis de ambiente
docker compose -f docker/docker-compose.production.yml exec api env | grep RAILS

# Testar conexao com banco
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails db:migrate:status
```

### Redis nao conecta

```bash
# Verificar status do container
docker compose -f docker/docker-compose.production.yml ps redis

# Testar ping
docker compose -f docker/docker-compose.production.yml exec redis redis-cli -a $REDIS_PASSWORD ping

# Ver logs
docker compose -f docker/docker-compose.production.yml logs redis
```

Para problemas especificos de Redis no Coolify, consultar [COOLIFY_REDIS_FIX.md](../../COOLIFY_REDIS_FIX.md).

### Meilisearch nao indexa

```bash
# Verificar saude do Meilisearch
docker compose -f docker/docker-compose.production.yml exec api curl http://meilisearch:7700/health

# Ver logs
docker compose -f docker/docker-compose.production.yml logs meilisearch

# Reiniciar indexacao (via Rails console)
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails console
# > Meilisearch::IndexingJob.perform_now
```

### Migrations falharam

```bash
# Ver status das migrations
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails db:migrate:status

# Executar migrations pendentes
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails db:migrate

# Reverter ultima migration
docker compose -f docker/docker-compose.production.yml exec api bundle exec rails db:rollback STEP=1
```

### Performance lenta

```bash
# Ver uso de recursos dos containers
docker stats

# Ver processos dentro do container
docker compose -f docker/docker-compose.production.yml exec api ps aux

# Queries lentas no banco (dentro do console Rails)
# ActiveRecord::Base.connection.execute("SELECT query, total_exec_time FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;")
```

---

## Recursos

- [Coolify Docs](https://coolify.io/docs)
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Meilisearch Docs](https://www.meilisearch.com/docs)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deploying.html)
- [Sidekiq Best Practices](https://github.com/sidekiq/sidekiq/wiki/Best-Practices)
