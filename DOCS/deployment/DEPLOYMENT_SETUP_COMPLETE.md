#  ProStaff API - Setup de Produção Completo!

Este projeto está agora completamente configurado para deploy em staging e produção.

## ✅ O Que Foi Configurado

### 1. Docker & Infraestrutura

**Arquivos Criados:**
- ✅ `Dockerfile.production` - Dockerfile otimizado multi-stage
- ✅ `docker-compose.production.yml` - Compose para produção (com replicas)
- ✅ `docker-compose.staging.yml` - Compose específico para staging
- ✅ `config/puma.rb` - Configuração Puma otimizada para produção

**Serviços Incluídos:**
- Nginx (reverse proxy com SSL)
- PostgreSQL 15 (com health checks)
- Redis 7 (cache e sessions)
- Rails API (com replicas em produção)
- Sidekiq (background jobs)
- Backup automático

### 2. CI/CD Workflows

**GitHub Actions criados:**

`.github/workflows/deploy-staging.yml`
- ✅ Testes automatizados (RSpec, RuboCop, Brakeman)
- ✅ Build de imagem Docker
- ✅ Deploy automático no push para `develop`
- ✅ Health checks pós-deploy
- ✅ Rollback automático em caso de falha

`.github/workflows/deploy-production.yml`
- ✅ Testes completos + security scanning
- ✅ Validação de versão (tags semver)
- ✅ Aprovação manual obrigatória
- ✅ Deploy com zero-downtime
- ✅ Backup automático antes do deploy
- ✅ Rollback em caso de falha
- ✅ Criação de GitHub Release

### 3. Scripts de Deployment

**Scripts criados em `deploy/scripts/`:**

- ✅ `docker-entrypoint.sh` - Entrypoint com migrations e health checks
- ✅ `backup.sh` - Backup automático do PostgreSQL com upload S3
- ✅ `deploy.sh` - Script manual de deploy com confirmações
- ✅ `rollback.sh` - Script de rollback com restauração de backup

Todos os scripts têm:
- Tratamento de erros
- Output colorido e informativo
- Confirmações de segurança
- Health checks automáticos

### 4. Nginx Configuration

**Configurações em `deploy/nginx/`:**

- ✅ `nginx.conf` - Configuração principal otimizada
- ✅ `conf.d/prostaff.conf` - Virtual hosts para staging e production
- ✅ SSL/TLS com certificados Let's Encrypt
- ✅ Rate limiting
- ✅ Gzip compression
- ✅ Security headers
- ✅ WebSocket support

### 5. Variáveis de Ambiente

**Templates criados:**
- ✅ `.env.staging.example` - Todas as variáveis para staging
- ✅ `.env.production.example` - Todas as variáveis para produção

**Incluem:**
- Database credentials
- Redis password
- JWT secrets
- External APIs (Riot, AWS, SendGrid)
- Monitoring (Sentry)
- Feature flags

### 6. Documentação

**Guias criados:**

- ✅ `DEPLOYMENT.md` - Guia completo e detalhado (470 linhas)
- ✅ `QUICK_DEPLOY.md` - Guia rápido com comandos essenciais
- ✅ `.github/SECRETS_SETUP.md` - Setup de secrets do GitHub
- ✅ `deploy/README.md` - Estrutura de arquivos de deploy
- ✅ `deploy/SECRETS_SETUP.md` - Guia de configuração de secrets

##  Como Usar

### Deploy Automático (Recomendado)

**Staging:**
```bash
git checkout develop
git push origin develop
# GitHub Actions fará o deploy automaticamente
```

**Production:**
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
# Requer aprovação manual no GitHub
```

### Deploy Manual

**Staging:**
```bash
./deploy/scripts/deploy.sh staging
```

**Production:**
```bash
./deploy/scripts/deploy.sh production
```

## 📋 Próximos Passos

### 1. Configurar Servidores

```bash
# Instalar Docker e Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Clonar repositório
sudo mkdir -p /var/www
cd /var/www
git clone <seu-repo> prostaff-api
cd prostaff-api

# Configurar ambiente
cp .env.staging.example .env
nano .env  # Ajustar valores
```

### 2. Configurar SSL

```bash
# Obter certificados Let's Encrypt
sudo certbot certonly --standalone -d staging-api.prostaff.gg
sudo certbot certonly --standalone -d api.prostaff.gg

# Copiar certificados
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/fullchain.pem deploy/ssl/staging-fullchain.pem
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/privkey.pem deploy/ssl/staging-privkey.pem
```

### 3. Configurar GitHub Secrets

Ver guia completo em: `.github/SECRETS_SETUP.md`

**Secrets necessários:**
```bash
# Via GitHub CLI
gh secret set STAGING_SSH_KEY < ~/.ssh/staging_key
gh secret set STAGING_HOST -b "staging.prostaff.gg"
gh secret set STAGING_USER -b "deploy"

gh secret set PRODUCTION_SSH_KEY < ~/.ssh/production_key
gh secret set PRODUCTION_HOST -b "api.prostaff.gg"
gh secret set PRODUCTION_USER -b "deploy"
```

### 4. Configurar Ambientes GitHub

1. Vá para **Settings** → **Environments**
2. Crie 3 ambientes:
   - `staging` - Deploy automático
   - `production-approval` - Requer aprovação
   - `production` - Deploy final

### 5. Primeiro Deploy

```bash
# No servidor staging
cd /var/www/prostaff-api
docker-compose -f docker-compose.staging.yml up -d

# Verificar
curl https://staging-api.prostaff.gg/up
```

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────┐
│              GitHub Actions                 │
│  (Tests → Build → Deploy → Verify)         │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│         Nginx (Reverse Proxy)               │
│         Port 80/443 - SSL/TLS               │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│      Rails API (Puma - 2-4 workers)        │
│         Port 3000 - Health checks           │
└─────┬───────────────────────────────────────┘
      │
      ├────────────► PostgreSQL 15 (Primary DB)
      ├────────────► Redis 7 (Cache/Sessions)
      └────────────► Sidekiq (Background Jobs)
```

##  Features

### Zero-Downtime Deploys
- ✅ Rolling updates com health checks
- ✅ Rollback automático em falhas
- ✅ Phased restarts do Puma

### Segurança
- ✅ SSL/TLS obrigatório
- ✅ Security headers (XSS, CORS, etc)
- ✅ Rate limiting
- ✅ Secrets via environment variables
- ✅ Scans de segurança (Brakeman, Trivy)

### Monitoramento
- ✅ Health check endpoints
- ✅ Logs estruturados
- ✅ Sentry integration
- ✅ Docker health checks
- ✅ Puma control app

### Backup & Recovery
- ✅ Backup automático diário
- ✅ Upload para S3
- ✅ Retenção configurável
- ✅ Scripts de restore

### Performance
- ✅ Nginx caching & compression
- ✅ Puma workers otimizados
- ✅ Redis para cache
- ✅ Connection pooling
- ✅ Static file serving

##  Configurações Recomendadas

### Recursos Mínimos

**Staging:**
- CPU: 2 cores
- RAM: 4GB
- Disco: 50GB SSD

**Production:**
- CPU: 4+ cores
- RAM: 8GB+
- Disco: 100GB+ SSD

### Providers Recomendados

1. **DigitalOcean** - Simples e econômico
   - Droplet 4GB: $24/mês
   - Managed PostgreSQL: $15/mês
   - Managed Redis: $15/mês

2. **AWS** - Escalável
   - EC2 t3.medium
   - RDS PostgreSQL
   - ElastiCache Redis

3. **Google Cloud** - Enterprise
   - Compute Engine
   - Cloud SQL
   - Memorystore

## 📚 Documentação Completa

Consulte estes guias para mais informações:

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Guia completo (LEIA PRIMEIRO!)
- **[QUICK_DEPLOY.md](QUICK_DEPLOY.md)** - Comandos rápidos
- **[SECRETS_SETUP.md](SECRETS_SETUP.md)** - Setup de secrets
- **[README.md](../../README.md)** - Estrutura de arquivos

## ✅ Checklist Final

Antes do primeiro deploy em produção:

- [ ] Servidores provisionados (staging e production)
- [ ] Docker e Docker Compose instalados
- [ ] DNS configurado (staging-api.prostaff.gg, api.prostaff.gg)
- [ ] Certificados SSL obtidos e copiados
- [ ] Variáveis de ambiente configuradas (.env)
- [ ] GitHub Secrets configurados
- [ ] GitHub Environments criados
- [ ] SSH keys configuradas
- [ ] Reviewers adicionados para production
- [ ] Staging testado e funcionando
- [ ] Backup testado
- [ ] Rollback testado
- [ ] Equipe treinada nos processos

##  Workflow de Desenvolvimento

```
feature → develop → staging (auto-deploy)
                 ↓
              review
                 ↓
         master + tag → production (manual approval)
```

## 🆘 Suporte

**Em caso de problemas:**

1. Consulte [DEPLOYMENT.md](DEPLOYMENT.md) - Seção Troubleshooting
2. Verifique logs: `docker-compose logs -f`
3. Execute health checks
4. Se necessário, faça rollback: '[rollback.sh](../../deploy/scripts/rollback.sh)'
**Recursos úteis:**
- GitHub Issues: Para reportar bugs
- Slack: Canal #devops (se configurado)
- Email: devops@prostaff.gg

##  Conclusão

Seu projeto está PRONTO para produção!

Todos os componentes foram configurados seguindo as melhores práticas:
- ✅ CI/CD automatizado
- ✅ Deploy com zero-downtime
- ✅ Segurança implementada
- ✅ Monitoramento configurado
- ✅ Backup automático
- ✅ Documentação completa

**Boa sorte com o deploy!** 

---

**Data de configuração**: 2025-10-09
**Versão**: 1.0.0
