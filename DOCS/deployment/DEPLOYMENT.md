# ProStaff API - Production Deployment Guide

Guia completo para deploy da aplicação em ambientes de staging e produção.

##  Índice

- [Pré-requisitos](#pré-requisitos)
- [Configuração Inicial](#configuração-inicial)
- [Deploy em Staging](#deploy-em-staging)
- [Deploy em Production](#deploy-em-production)
- [Infraestrutura](#infraestrutura)
- [Monitoramento](#monitoramento)
- [Backup e Recovery](#backup-e-recovery)
- [Troubleshooting](#troubleshooting)

##  Pré-requisitos

### Servidor

- **Sistema Operacional**: Ubuntu 22.04 LTS ou superior
- **RAM**: Mínimo 4GB (Recomendado: 8GB+)
- **CPU**: 2+ cores
- **Disco**: 50GB+ SSD
- **Docker**: 24.0+
- **Docker Compose**: 2.20+

### Domínios

- **Production**: `api.prostaff.gg`
- **Staging**: `staging-api.prostaff.gg`

### Serviços Externos

- **Database**: PostgreSQL 15+ (ou RDS/Cloud SQL)
- **Cache**: Redis 7+ (ou ElastiCache/MemoryStore)
- **Storage**: AWS S3 ou compatível
- **Email**: SendGrid, Mailgun ou SMTP
- **Monitoring**: Sentry (opcional)

##  Configuração Inicial

### 1. Preparar Servidor

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instalar ferramentas essenciais
sudo apt install -y git curl wget nano ufw fail2ban

# Configurar firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 2. Configurar SSL/TLS (Let's Encrypt)

```bash
# Instalar Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obter certificados
sudo certbot certonly --standalone -d api.prostaff.gg
sudo certbot certonly --standalone -d staging-api.prostaff.gg

# Certificados estarão em:
# /etc/letsencrypt/live/api.prostaff.gg/fullchain.pem
# /etc/letsencrypt/live/api.prostaff.gg/privkey.pem
```

### 3. Clonar Repositório

```bash
# Criar diretório
sudo mkdir -p /var/www
cd /var/www

# Clonar projeto
sudo git clone https://github.com/seu-usuario/prostaff-api.git
cd prostaff-api

# Definir permissões
sudo chown -R $USER:$USER /var/www/prostaff-api
```

### 4. Configurar Variáveis de Ambiente

```bash
# Copiar exemplo de staging
cp .env.staging.example .env

# Editar arquivo
nano .env
```

**Importante**: Gere secrets fortes com:

```bash
# Gerar SECRET_KEY_BASE
bundle exec rails secret

# Ou use OpenSSL
openssl rand -hex 64
```

##  Deploy em Staging

### Configuração

```bash
# Usar configuração de staging
cp .env.staging.example .env
nano .env  # Ajustar valores

# Copiar certificados SSL
sudo mkdir -p deploy/ssl
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/fullchain.pem deploy/ssl/staging-fullchain.pem
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/privkey.pem deploy/ssl/staging-privkey.pem
```

### Build e Deploy

```bash
# Build da imagem
docker-compose -f docker-compose.production.yml build

# Iniciar serviços
docker-compose -f docker-compose.production.yml up -d

# Verificar logs
docker-compose -f docker-compose.production.yml logs -f api

# Executar migrations
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:migrate

# Verificar saúde
curl https://staging-api.prostaff.gg/up
```

### Seeds (Opcional)

```bash
# Popular dados de teste
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:seed
```

##  Deploy em Production

### Checklist Pré-Deploy

- [ ] Backup do banco de dados atual
- [ ] Testar em staging
- [ ] Revisar mudanças de schema (migrations)
- [ ] Verificar secrets e variáveis de ambiente
- [ ] Notificar equipe sobre deploy
- [ ] Preparar rollback plan

### Deploy

```bash
# 1. Backup
./deploy/scripts/backup.sh

# 2. Atualizar código
git pull origin master

# 3. Build nova versão
docker-compose -f docker-compose.production.yml build

# 4. Deploy com zero-downtime
docker-compose -f docker-compose.production.yml up -d --no-deps --build api

# 5. Executar migrations
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:migrate

# 6. Restart services
docker-compose -f docker-compose.production.yml restart

# 7. Verificar saúde
curl https://api.prostaff.gg/up
```

### Rollback (se necessário)

```bash
# Reverter para versão anterior
git checkout <commit-hash>
docker-compose -f docker-compose.production.yml up -d --force-recreate

# Reverter migrations
docker-compose -f docker-compose.production.yml exec api bundle exec rails db:rollback STEP=1
```

## 🏗️ Infraestrutura

### Arquitetura Recomendada

```
┌─────────────────────────────────────────────┐
│           Load Balancer / CDN               │
│         (CloudFlare / AWS ALB)              │
└─────────────────┬───────────────────────────┘
                  │
      ┌───────────┴───────────┐
      │                       │
┌─────▼─────┐         ┌───────▼──────┐
│  Staging  │         │  Production  │
│  Server   │         │   Servers    │
│           │         │  (2+ nodes)  │
└─────┬─────┘         └───────┬──────┘
      │                       │
┌─────▼────────────────────────▼──────┐
│         Managed Services             │
│  - RDS (PostgreSQL)                  │
│  - ElastiCache (Redis)               │
│  - S3 (Storage)                      │
│  - SES/SendGrid (Email)              │
└──────────────────────────────────────┘
```

### Opções de Hosting

#### 1. AWS (Recomendado para escala)

```bash
# Serviços necessários:
- EC2 (t3.medium ou superior)
- RDS PostgreSQL
- ElastiCache Redis
- S3
- ALB (Load Balancer)
- Route 53 (DNS)
- CloudWatch (Monitoring)
```

#### 2. DigitalOcean (Simples e econômico)

```bash
# Droplets + Managed Databases
- Droplet 4GB ($24/mês)
- Managed PostgreSQL ($15/mês)
- Managed Redis ($15/mês)
- Spaces (S3-compatible)
```

#### 3. Google Cloud Platform

```bash
# Compute Engine + Cloud SQL
- e2-medium instance
- Cloud SQL PostgreSQL
- Memorystore Redis
- Cloud Storage
```

## 📊 Monitoramento

### Logs

```bash
# Ver logs em tempo real
docker-compose -f docker-compose.production.yml logs -f

# Logs específicos
docker-compose -f docker-compose.production.yml logs -f api
docker-compose -f docker-compose.production.yml logs -f sidekiq
docker-compose -f docker-compose.production.yml logs -f nginx

# Logs do sistema
tail -f /var/log/syslog
```

### Métricas

Instalar Prometheus + Grafana (opcional):

```bash
# Em outro servidor ou mesmo servidor
docker run -d -p 9090:9090 prom/prometheus
docker run -d -p 3001:3000 grafana/grafana
```

### Alertas

Configurar Sentry para erros:

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = ENV['RAILS_ENV']
  config.traces_sample_rate = 0.1
end
```

## 💾 Backup e Recovery

### Backup Automático

```bash
# Adicionar ao crontab
crontab -e

# Backup diário às 2h
0 2 * * * cd /var/www/prostaff-api && docker-compose -f docker-compose.production.yml run --rm backup

# Limpeza semanal
0 3 * * 0 find /var/www/prostaff-api/backups -name "*.sql.gz" -mtime +30 -delete
```

### Restaurar Backup

```bash
# Listar backups
ls -lh backups/

# Restaurar
gunzip < backups/prostaff_production_YYYYMMDD_HHMMSS.sql.gz | \
docker-compose -f docker-compose.production.yml exec -T postgres psql -U prostaff_user -d prostaff_production
```

### Backup para S3

```bash
# Instalar AWS CLI
sudo apt install -y awscli

# Configurar
aws configure

# Upload manual
aws s3 cp backups/ s3://prostaff-backups/database/ --recursive

# Script automático (adicionar ao backup.sh)
aws s3 sync backups/ s3://prostaff-backups/database/
```

##  Manutenção

### Atualizar Dependências

```bash
# Atualizar gems
docker-compose -f docker-compose.production.yml exec api bundle update

# Rebuild
docker-compose -f docker-compose.production.yml build

# Deploy
docker-compose -f docker-compose.production.yml up -d
```

### Limpar Recursos

```bash
# Remover containers parados
docker container prune -f

# Remover imagens não utilizadas
docker image prune -a -f

# Remover volumes órfãos
docker volume prune -f

# Limpar tudo (CUIDADO!)
docker system prune -a --volumes -f
```

### Atualizar SSL

```bash
# Renovar certificados (automático com certbot)
sudo certbot renew

# Ou manualmente
sudo certbot renew --force-renewal

# Copiar novos certificados
sudo cp /etc/letsencrypt/live/api.prostaff.gg/fullchain.pem deploy/ssl/
sudo cp /etc/letsencrypt/live/api.prostaff.gg/privkey.pem deploy/ssl/

# Restart nginx
docker-compose -f docker-compose.production.yml restart nginx
```

##  Troubleshooting

### Application não inicia

```bash
# Verificar logs
docker-compose -f docker-compose.production.yml logs api

# Verificar variáveis de ambiente
docker-compose -f docker-compose.production.yml exec api env | grep RAILS

# Teste de console
docker-compose -f docker-compose.production.yml exec api bundle exec rails console
```

### Banco de dados inacessível

```bash
# Verificar status
docker-compose -f docker-compose.production.yml exec postgres pg_isready

# Conectar ao banco
docker-compose -f docker-compose.production.yml exec postgres psql -U prostaff_user -d prostaff_production

# Verificar conexões
docker-compose -f docker-compose.production.yml exec postgres psql -U prostaff_user -c "SELECT count(*) FROM pg_stat_activity;"
```

### Performance Issues

```bash
# Ver processos
docker-compose -f docker-compose.production.yml exec api ps aux

# Ver uso de recursos
docker stats

# Analisar queries lentas
docker-compose -f docker-compose.production.yml exec postgres psql -U prostaff_user -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

### SSL/HTTPS não funciona

```bash
# Verificar certificados
sudo certbot certificates

# Testar nginx config
docker-compose -f docker-compose.production.yml exec nginx nginx -t

# Ver logs nginx
docker-compose -f docker-compose.production.yml logs nginx
```

##  Recursos Adicionais

- [Documentação Rails Deployment](https://guides.rubyonrails.org/deploying.html)
- [Docker Production Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [PostgreSQL Tuning](https://pgtune.leopard.in.ua/)
- [Redis Configuration](https://redis.io/docs/manual/config/)

## 🆘 Suporte

Em caso de problemas críticos:

1. Verificar logs (`docker-compose logs`)
2. Consultar este guia
3. Abrir issue no GitHub
4. Contactar equipe de DevOps

---

**Última atualização**: $(date +"%Y-%m-%d")
