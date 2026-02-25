# GitHub Secrets - Guia de Configuracao

Guia de todos os secrets necessarios para o CI/CD do ProStaff API via GitHub Actions.

---

## Secrets obrigatorios

### Staging

Configure no ambiente `staging` do GitHub:

```
STAGING_SSH_KEY
  Descricao: Chave SSH privada para acesso ao servidor de staging
  Gerar:     ssh-keygen -t ed25519 -C "github-actions-staging" -f staging_deploy_key
  Formato:   Conteudo completo do arquivo privado (incluindo BEGIN/END)

STAGING_HOST
  Descricao: Endereco do servidor de staging
  Exemplo:   staging.prostaff.gg

STAGING_USER
  Descricao: Usuario SSH no servidor de staging
  Exemplo:   deploy
```

### Producao

Configure no ambiente `production` do GitHub:

```
PRODUCTION_SSH_KEY
  Descricao: Chave SSH privada para acesso ao servidor de producao
  Gerar:     ssh-keygen -t ed25519 -C "github-actions-production" -f production_deploy_key
  Formato:   Conteudo completo do arquivo privado

PRODUCTION_HOST
  Descricao: Endereco do servidor de producao
  Exemplo:   api.prostaff.gg

PRODUCTION_USER
  Descricao: Usuario SSH no servidor de producao
  Exemplo:   deploy
```

---

## Secrets opcionais

### Notificacoes

```
SLACK_WEBHOOK_URL
  Descricao: Webhook do Slack para notificacoes de deploy
  Formato:   https://hooks.slack.com/services/T.../B.../XXX
```

### Container Registry

O pipeline usa o GitHub Container Registry (GHCR) por padrao com o `GITHUB_TOKEN` automatico. Se usar outro registry:

```
DOCKER_USERNAME
  Descricao: Usuario do registry privado

DOCKER_PASSWORD
  Descricao: Token/senha do registry
```

### Testes

```
TEST_EMAIL
  Descricao: Email de uma conta de teste para smoke tests
  Exemplo:   test@prostaff.gg

TEST_PASSWORD
  Descricao: Senha da conta de teste
```

---

## Variaveis de ambiente de producao

Estas variaveis sao configuradas diretamente no Coolify (nao como secrets do GitHub Actions):

```bash
RAILS_ENV=production
RAILS_MASTER_KEY=<conteudo_de_config/master.key>
SECRET_KEY_BASE=<openssl rand -hex 64>
RAILS_LOG_TO_STDOUT=true
PORT=3000

DATABASE_URL=postgresql://user:pass@host:5432/dbname

REDIS_URL=redis://default:<REDIS_PASSWORD>@redis:6379/0
REDIS_PASSWORD=<openssl rand -base64 32>

JWT_SECRET_KEY=<openssl rand -hex 64>

HASHID_SALT=<openssl rand -hex 32>
HASHID_MIN_LENGTH=8

RIOT_API_KEY=<chave_riot_games>

MEILISEARCH_URL=http://meilisearch:7700
MEILI_MASTER_KEY=<openssl rand -hex 32>

CORS_ORIGINS=https://prostaff.gg,https://www.prostaff.gg,https://api.prostaff.gg,https://status.prostaff.gg,https://docs.prostaff.gg

FRONTEND_URL=https://prostaff.gg
APP_HOST=api.prostaff.gg

# Opcional
ELASTICSEARCH_URL=http://elastic:9200
```

---

## Como adicionar secrets

### Via interface web do GitHub

1. Acesse o repositorio no GitHub
2. Va para **Settings** -> **Secrets and variables** -> **Actions**
3. Clique em **New repository secret**
4. Adicione nome e valor
5. Clique em **Add secret**

### Via GitHub CLI

```bash
# Autenticar
gh auth login

# Adicionar secrets de staging
gh secret set STAGING_SSH_KEY < staging_deploy_key
gh secret set STAGING_HOST -b "staging.prostaff.gg"
gh secret set STAGING_USER -b "deploy"

# Adicionar secrets de producao
gh secret set PRODUCTION_SSH_KEY < production_deploy_key
gh secret set PRODUCTION_HOST -b "api.prostaff.gg"
gh secret set PRODUCTION_USER -b "deploy"

# Listar secrets configurados
gh secret list
```

---

## Configurar environments no GitHub

### Criar ambientes

1. Va para **Settings** -> **Environments**
2. Crie os seguintes ambientes:

**staging**
- Required reviewers: nao necessario
- Deployment branches: `develop`

**production-approval**
- Required reviewers: adicionar pelo menos 1 revisor
- Descricao: Checkpoint de aprovacao manual antes do deploy

**production**
- Required reviewers: opcional
- Deployment branches: `master` ou tags `v*.*.*`

### Configurar SSH nos servidores

```bash
# Gerar par de chaves
ssh-keygen -t ed25519 -C "github-actions-staging" -f staging_deploy_key
ssh-keygen -t ed25519 -C "github-actions-production" -f production_deploy_key

# Copiar chaves publicas para os servidores
ssh-copy-id -i staging_deploy_key.pub deploy@staging-server
ssh-copy-id -i production_deploy_key.pub deploy@production-server

# Adicionar chaves privadas ao GitHub
gh secret set STAGING_SSH_KEY < staging_deploy_key
gh secret set PRODUCTION_SSH_KEY < production_deploy_key

# Remover arquivos locais apos configurar
rm staging_deploy_key staging_deploy_key.pub
rm production_deploy_key production_deploy_key.pub
```

---

## Verificar configuracao

```bash
# Listar todos os secrets
gh secret list

# Testar acesso SSH ao staging
ssh -i staging_deploy_key deploy@staging.prostaff.gg "echo OK"

# Testar acesso SSH a producao
ssh -i production_deploy_key deploy@api.prostaff.gg "echo OK"

# Ver environments configurados
gh api repos/:owner/:repo/environments | jq '.environments[].name'
```

---

## Checklist

- [ ] SSH keys geradas para staging e producao
- [ ] Chaves publicas copiadas para os servidores
- [ ] Secrets STAGING_* configurados no GitHub
- [ ] Secrets PRODUCTION_* configurados no GitHub
- [ ] Environments criados: staging, production-approval, production
- [ ] Revisores configurados em production-approval
- [ ] Variaveis de producao configuradas no Coolify
- [ ] Primeiro deploy testado com sucesso

---

## Referencias

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub CLI](https://cli.github.com/manual/)
