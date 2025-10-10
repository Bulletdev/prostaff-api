# ProStaff API - Quick Deploy Guide

Guia rápido para deploy em staging e produção.

##  Quick Start

### Pré-requisitos

- Docker & Docker Compose instalados
- Acesso SSH ao servidor
- Git configurado
- Variáveis de ambiente configuradas

### Deploy em 3 Passos

#### Preparar Ambiente

```bash
# Clonar repositório
git clone https://github.com/seu-usuario/prostaff-api.git
cd prostaff-api

# Configurar variáveis de ambiente
cp .env.staging.example .env
nano .env  # Ajustar valores
```

#### Build & Deploy

```bash
# Build da imagem
docker-compose -f docker-compose.production.yml build

# Iniciar serviços
docker-compose -f docker-compose.production.yml up -d

# Executar migrations
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:migrate
```

#### Verificar

```bash
# Health check
curl https://staging-api.prostaff.gg/up

# Ver logs
docker-compose -f docker-compose.production.yml logs -f api
```

## Comandos Úteis

### Deploy Scripts

```bash
# Deploy automático
./deploy/scripts/deploy.sh staging
./deploy/scripts/deploy.sh production

# Rollback
./deploy/scripts/rollback.sh staging
```

### Docker Operations

```bash
# Ver status
docker-compose -f docker-compose.production.yml ps

# Ver logs
docker-compose -f docker-compose.production.yml logs -f

# Restart serviço
docker-compose -f docker-compose.production.yml restart api

# Console Rails
docker-compose -f docker-compose.production.yml exec api bundle exec rails console

# Migrations
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:migrate
```

### Backup & Restore

```bash
# Criar backup
docker-compose -f docker-compose.production.yml run --rm backup

# Listar backups
ls -lh backups/

# Restaurar backup
gunzip < backups/prostaff_YYYYMMDD_HHMMSS.sql.gz | \
docker-compose -f docker-compose.production.yml exec -T postgres \
psql -U prostaff_user -d prostaff_production
```

### Maintenance

```bash
# Atualizar código
git pull origin master
docker-compose -f docker-compose.production.yml up -d --build

# Limpar recursos
docker system prune -af

# Renovar SSL
sudo certbot renew
sudo cp /etc/letsencrypt/live/api.prostaff.gg/* deploy/ssl/
docker-compose -f docker-compose.production.yml restart nginx
```

##  CI/CD via GitHub Actions

### Staging Deploy

```bash
# Push para develop
git checkout develop
git push origin develop

# Ou trigger manual
gh workflow run deploy-staging.yml
```

### Production Deploy

```bash
# Criar tag de versão
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Ou trigger manual
gh workflow run deploy-production.yml -f version=v1.0.0
```

## 🔐 Configurar Secrets GitHub

```bash
# Via GitHub CLI
gh secret set STAGING_SSH_KEY < ~/.ssh/staging_key
gh secret set STAGING_HOST -b "staging.prostaff.gg"
gh secret set STAGING_USER -b "deploy"

gh secret set PRODUCTION_SSH_KEY < ~/.ssh/production_key
gh secret set PRODUCTION_HOST -b "api.prostaff.gg"
gh secret set PRODUCTION_USER -b "deploy"
```

Ver guia completo: [.github/SECRETS_SETUP.md](SECRETS_SETUP.md)

##  Health Checks

```bash
# API Health
curl https://api.prostaff.gg/up

# Database
docker-compose -f docker-compose.production.yml exec postgres pg_isready

# Redis
docker-compose -f docker-compose.production.yml exec redis redis-cli ping

# Sidekiq
docker-compose -f docker-compose.production.yml logs sidekiq | tail -20
```

## 🆘 Troubleshooting

### Application não inicia

```bash
# Ver logs detalhados
docker-compose -f docker-compose.production.yml logs api

# Verificar variáveis
docker-compose -f docker-compose.production.yml exec api env | grep RAILS

# Console Rails
docker-compose -f docker-compose.production.yml exec api bundle exec rails console
```

### Database issues

```bash
# Verificar conexão
docker-compose -f docker-compose.production.yml exec postgres \
psql -U prostaff_user -d prostaff_production -c "SELECT 1;"

# Ver conexões ativas
docker-compose -f docker-compose.production.yml exec postgres \
psql -U prostaff_user -c "SELECT count(*) FROM pg_stat_activity;"

# Reset migrations
docker-compose -f docker-compose.production.yml exec api \
bundle exec rails db:migrate:status
```

### Performance issues

```bash
# Ver uso de recursos
docker stats

# Ver processos
docker-compose -f docker-compose.production.yml exec api ps aux

# Restart serviços
docker-compose -f docker-compose.production.yml restart
```

## 📚 Documentação Completa

- [DEPLOYMENT.md](DEPLOYMENT.md) - Guia completo de deployment
- [deploy/README.md](../../deploy/README.md) - Estrutura de arquivos
- [.github/SECRETS_SETUP.md](SECRETS_SETUP.md) - Configuração de secrets

## 🌐 URLs

- **Staging**: https://staging-api.prostaff.gg
- **Production**: https://api.prostaff.gg
- **Swagger (Staging)**: https://staging-api.prostaff.gg/api-docs

## ✅ Deploy Checklist

### Pré-Deploy

- [ ] Código revisado e testado
- [ ] Testes passando
- [ ] Migrations testadas
- [ ] Backup criado
- [ ] Equipe notificada

### Deploy

- [ ] Pull código
- [ ] Build imagens
- [ ] Stop old containers
- [ ] Start new containers
- [ ] Run migrations
- [ ] Health check

### Pós-Deploy

- [ ] Verificar logs
- [ ] Testar endpoints principais
- [ ] Monitorar métricas
- [ ] Confirmar com equipe

## 🔄 Workflow Summary

```
┌─────────────────────────────────────────────────┐
│                 STAGING                          │
│                                                  │
│  develop → CI/CD → Build → Deploy → Verify     │
│                                                  │
│  Manual: ./deploy/scripts/deploy.sh staging    │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│               PRODUCTION                         │
│                                                  │
│  tag → CI/CD → Test → Build → Approval →       │
│  Deploy → Verify → Notify                       │
│                                                  │
│  Manual: ./deploy/scripts/deploy.sh production │
└─────────────────────────────────────────────────┘
```

---

**Need help?** Check [DEPLOYMENT.md]([DEPLOYMENT.md](DEPLOYMENT.md). or open an issue on GitHub.
