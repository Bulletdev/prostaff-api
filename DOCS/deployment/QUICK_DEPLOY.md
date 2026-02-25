# ProStaff API - Quick Deploy

Referencia rapida de comandos para deploy e operacoes do dia a dia.

---

## Deploy via CI/CD (recomendado)

### Staging

```bash
# Push para develop dispara deploy automatico
git checkout develop
git push origin develop

# Trigger manual
gh workflow run deploy-staging.yml
```

### Producao

```bash
# Criar tag semver dispara pipeline de producao
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# Trigger manual com versao especifica
gh workflow run deploy-production.yml -f version=v1.2.0
```

Apos push da tag, o pipeline aguarda **aprovacao manual** no GitHub Actions antes de fazer o deploy em producao.

---

## Deploy manual (servidor)

```bash
cd /var/www/prostaff-api

# Atualizar codigo e subir servicos
git pull origin master
docker compose -f docker-compose.production.yml up -d --build

# Migrations
docker compose -f docker-compose.production.yml exec api bundle exec rails db:migrate

# Health check
curl https://api.prostaff.gg/up
```

---

## Comandos Docker essenciais

```bash
# Status dos containers
docker compose -f docker-compose.production.yml ps

# Logs em tempo real
docker compose -f docker-compose.production.yml logs -f
docker compose -f docker-compose.production.yml logs -f api
docker compose -f docker-compose.production.yml logs -f sidekiq

# Reiniciar servico
docker compose -f docker-compose.production.yml restart api

# Console Rails
docker compose -f docker-compose.production.yml exec api bundle exec rails console

# Uso de recursos
docker stats
```

---

## Health checks

```bash
# API
curl https://api.prostaff.gg/up             # -> ok
curl https://api.prostaff.gg/health         # -> JSON

# Redis
docker compose -f docker-compose.production.yml exec redis redis-cli -a $REDIS_PASSWORD ping

# Meilisearch (rede interna)
docker compose -f docker-compose.production.yml exec api curl http://meilisearch:7700/health
```

---

## Rollback

```bash
# Via script
./deploy/scripts/rollback.sh production

# Manual
git checkout <commit-hash-anterior>
docker compose -f docker-compose.production.yml up -d --force-recreate

# Reverter migrations
docker compose -f docker-compose.production.yml exec api bundle exec rails db:rollback STEP=1
```

---

## Backup e restore

```bash
# Criar backup
./scripts/backup_database.sh

# Listar backups
ls -lh backups/

# Restaurar
gunzip < backups/backup_YYYYMMDD_HHMMSS.sql.gz | psql $DATABASE_URL
```

---

## Limpeza Docker

```bash
# Imagens antigas (manter 72h)
docker image prune -af --filter "until=72h"

# Containers parados
docker container prune -f
```

---

## Desenvolvimento local

```bash
# Subir ambiente (Redis + API + Sidekiq)
docker compose up -d

# Com PostgreSQL local
docker compose --profile local-db up -d

# Porta da API: http://localhost:3333
# Sidekiq UI: http://localhost:3333/sidekiq
# Swagger:    http://localhost:3333/api-docs
```

---

## URLs de producao

| Servico      | URL                              |
|--------------|----------------------------------|
| API          | https://api.prostaff.gg          |
| Swagger      | https://api.prostaff.gg/api-docs |
| Status       | https://status.prostaff.gg       |
| Docs         | https://docs.prostaff.gg         |

---

## Referencias

- [DEPLOYMENT.md](DEPLOYMENT.md) - Guia completo
- [SECRETS_SETUP.md](SECRETS_SETUP.md) - Configuracao de secrets
