# GitHub Secrets Configuration Guide

Este guia detalha todos os secrets necessários para configurar o CI/CD do ProStaff API.

##  Índice

- [Secrets Obrigatórios](#secrets-obrigatórios)
- [Secrets Opcionais](#secrets-opcionais)
- [Como Adicionar Secrets](#como-adicionar-secrets)
- [Ambientes no GitHub](#ambientes-no-github)
- [Geração de Valores](#geração-de-valores)

## 🔐 Secrets Obrigatórios

### Staging Environment

Configure estes secrets para o ambiente `staging`:

#### SSH Access
```
STAGING_SSH_KEY
  - Descrição: Chave SSH privada para acessar o servidor staging
  - Como obter: ssh-keygen -t ed25519 -C "github-actions-staging"
  - Formato: Conteúdo completo do arquivo id_ed25519 (incluindo BEGIN/END)

STAGING_HOST
  - Descrição: Endereço do servidor staging
  - Exemplo: staging.prostaff.gg ou 123.456.789.10

STAGING_USER
  - Descrição: Usuário SSH no servidor staging
  - Exemplo: deploy ou ubuntu
```

### Production Environment

Configure estes secrets para o ambiente `production`:

#### SSH Access
```
PRODUCTION_SSH_KEY
  - Descrição: Chave SSH privada para acessar o servidor production
  - Como obter: ssh-keygen -t ed25519 -C "github-actions-production"
  - Formato: Conteúdo completo do arquivo id_ed25519

PRODUCTION_HOST
  - Descrição: Endereço do servidor production
  - Exemplo: api.prostaff.gg ou 123.456.789.100

PRODUCTION_USER
  - Descrição: Usuário SSH no servidor production
  - Exemplo: deploy ou ubuntu
```

##  Secrets Opcionais

### Notificações

```
SLACK_WEBHOOK
  - Descrição: Webhook URL do Slack para notificações de deploy
  - Como obter: https://api.slack.com/messaging/webhooks
  - Formato: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX

EMAIL_USERNAME
  - Descrição: Email para envio de notificações
  - Exemplo: ci-cd@prostaff.gg

EMAIL_PASSWORD
  - Descrição: Senha ou app password do email
  - Nota: Use App Password para Gmail
```

### Container Registry (Opcional)

Se usar registry privado diferente do GitHub Container Registry:

```
DOCKER_USERNAME
  - Descrição: Usuário do Docker Hub ou registry privado

DOCKER_PASSWORD
  - Descrição: Token/senha do registry
```

##  Como Adicionar Secrets

### 1. Via Interface Web do GitHub

1. Acesse seu repositório no GitHub
2. Vá para **Settings** → **Secrets and variables** → **Actions**
3. Clique em **New repository secret**
4. Adicione o nome e valor do secret
5. Clique em **Add secret**

### 2. Via GitHub CLI

```bash
# Instalar GitHub CLI
brew install gh  # macOS
# ou
sudo apt install gh  # Linux

# Autenticar
gh auth login

# Adicionar secrets
gh secret set STAGING_SSH_KEY < ~/.ssh/staging_id_ed25519
gh secret set STAGING_HOST -b "staging.prostaff.gg"
gh secret set STAGING_USER -b "deploy"
```

### 3. Adicionar Secret de Arquivo

```bash
# Para chaves SSH
gh secret set STAGING_SSH_KEY < path/to/private_key
gh secret set PRODUCTION_SSH_KEY < path/to/production_key
```

##  Ambientes no GitHub

Configure dois ambientes no repositório:

### Staging Environment

1. Vá para **Settings** → **Environments**
2. Clique em **New environment**
3. Nome: `staging`
4. Configurações:
   - ✅ Required reviewers: Não necessário
   - ✅ Wait timer: 0 minutos
   - ✅ Deployment branches: `develop` apenas
5. Adicione secrets específicos do ambiente

### Production Environment

1. Vá para **Settings** → **Environments**
2. Clique em **New environment**
3. Nome: `production`
4. Configurações:
   - ✅ Required reviewers: Adicione pelo menos 1 revisor
   - ⏱️ Wait timer: 5 minutos (opcional)
   - ✅ Deployment branches: `master` ou tags `v*.*.*`
5. Adicione secrets específicos do ambiente

### Production Approval Environment

1. Nome: `production-approval`
2. Configurações:
   - ✅ Required reviewers: Adicione revisores
   - ⏱️ Wait timer: 0 minutos
   - ✅ Permite aprovação manual antes do deploy

## 🔑 Geração de Valores

### SSH Keys

```bash
# Gerar chave para staging
ssh-keygen -t ed25519 -C "github-actions-staging" -f staging_deploy_key

# Gerar chave para production
ssh-keygen -t ed25519 -C "github-actions-production" -f production_deploy_key

# Copiar chave pública para servidor
ssh-copy-id -i staging_deploy_key.pub user@staging-server
ssh-copy-id -i production_deploy_key.pub user@production-server

# Adicionar chave privada como secret
gh secret set STAGING_SSH_KEY < staging_deploy_key
gh secret set PRODUCTION_SSH_KEY < production_deploy_key

# IMPORTANTE: Deletar as chaves locais após adicionar aos secrets
rm staging_deploy_key staging_deploy_key.pub
rm production_deploy_key production_deploy_key.pub
```

### Rails Secrets

```bash
# Gerar SECRET_KEY_BASE
bundle exec rails secret

# Ou usar OpenSSL
openssl rand -hex 64
```

### Database Passwords

```bash
# Gerar senha forte
openssl rand -base64 32

# Ou usar pwgen
pwgen -s 32 1
```

## ✅ Checklist de Configuração

### Antes do Primeiro Deploy

- [ ] SSH keys geradas e adicionadas aos servidores
- [ ] Secrets do GitHub configurados
- [ ] Ambientes criados (staging, production, production-approval)
- [ ] Reviewers configurados para production
- [ ] Servidores preparados (Docker instalado, diretórios criados)
- [ ] DNS configurado (staging-api.prostaff.gg, api.prostaff.gg)
- [ ] Certificados SSL obtidos
- [ ] Arquivos .env configurados nos servidores

### Staging

```bash
# No servidor staging
cd /var/www/prostaff-api
cp .env.staging.example .env
nano .env  # Configurar valores

# Copiar certificados SSL
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/fullchain.pem deploy/ssl/staging-fullchain.pem
sudo cp /etc/letsencrypt/live/staging-api.prostaff.gg/privkey.pem deploy/ssl/staging-privkey.pem
```

### Production

```bash
# No servidor production
cd /var/www/prostaff-api
cp .env.production.example .env
nano .env  # Configurar valores com secrets fortes

# Copiar certificados SSL
sudo cp /etc/letsencrypt/live/api.prostaff.gg/fullchain.pem deploy/ssl/fullchain.pem
sudo cp /etc/letsencrypt/live/api.prostaff.gg/privkey.pem deploy/ssl/privkey.pem
```

## 🔍 Verificação

### Testar SSH Access

```bash
# Testar conexão staging
ssh -i staging_deploy_key deploy@staging.prostaff.gg "echo 'Connection OK'"

# Testar conexão production
ssh -i production_deploy_key deploy@api.prostaff.gg "echo 'Connection OK'"
```

### Verificar Secrets no GitHub

```bash
# Listar secrets configurados
gh secret list

# Verificar environment secrets
gh api repos/:owner/:repo/environments/staging/secrets
gh api repos/:owner/:repo/environments/production/secrets
```

## 🆘 Troubleshooting

### Erro de SSH

```bash
# Verificar permissões da chave
chmod 600 ~/.ssh/deploy_key

# Testar conexão com verbose
ssh -vvv -i deploy_key user@host
```

### Secret não encontrado

1. Verifique se o nome está correto (case-sensitive)
2. Confirme que o secret está no ambiente correto
3. Recarregue a página de secrets no GitHub

### Deploy falha com "Permission denied"

1. Verifique se a chave pública está no `~/.ssh/authorized_keys` do servidor
2. Verifique permissões do diretório `/var/www/prostaff-api`
3. Confirme que o usuário tem permissões Docker

## 📚 Recursos

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub CLI](https://cli.github.com/manual/)

---

**Última atualização**: 2025-10-10
