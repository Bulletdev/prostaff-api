# Deploy Files

Este diretório contém todos os arquivos necessários para deploy em produção e staging.

## Estrutura

```
deploy/
├── nginx/              # Configurações Nginx
│   ├── nginx.conf      # Config principal
│   └── conf.d/         # Server configs
│       └── prostaff.conf
├── postgres/           # Scripts PostgreSQL
│   └── init/           # Scripts de inicialização
├── scripts/            # Scripts de manutenção
│   ├── docker-entrypoint.sh
│   └── backup.sh
├── ssl/                # Certificados SSL (não commitar!)
├── staging/            # Configs específicas de staging
└── production/         # Configs específicas de production

## Arquivos Importantes

- `SECRETS_SETUP.md` - Guia de configuração de secrets
- `../DEPLOYMENT.md` - Guia completo de deployment
- `../.env.staging.example` - Exemplo de variáveis staging
- `../.env.production.example` - Exemplo de variáveis production
- `../docker-compose.production.yml` - Docker Compose para produção

## Quick Start

### 1. Preparar Servidor

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/prostaff-api.git
cd prostaff-api

# Copiar ambiente
cp .env.staging.example .env
nano .env  # Configurar
```

### 2. Configurar SSL

```bash
# Copiar certificados Let's Encrypt
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/fullchain.pem deploy/ssl/staging-fullchain.pem
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/privkey.pem deploy/ssl/staging-privkey.pem
```

### 3. Deploy

```bash
# Build e iniciar
docker-compose -f docker-compose.production.yml up -d

# Ver logs
docker-compose -f docker-compose.production.yml logs -f

# Verificar saúde
curl https://staging-api.prostaff.gg/up
```

## Manutenção

```bash
# Backup
docker-compose -f docker-compose.production.yml run --rm backup

# Logs
docker-compose -f docker-compose.production.yml logs -f api

# Restart
docker-compose -f docker-compose.production.yml restart

# Atualizar
git pull
docker-compose -f docker-compose.production.yml up -d --build
```

## Suporte

Ver documentação completa em [DEPLOYMENT.md](../DOCS/deployment/DEPLOYMENT.md)
