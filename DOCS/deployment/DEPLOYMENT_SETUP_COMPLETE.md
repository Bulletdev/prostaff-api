# ProStaff API - Referencia de Infraestrutura

Referencia consolidada da infraestrutura de deploy configurada para o projeto.

---

## Arquitetura atual

```
GitHub Actions (CI/CD)
   |
   | push tag v*.*.*
   v
GHCR (GitHub Container Registry)
   |
   v
Coolify (PaaS self-hosted)
   |
   v
Traefik (reverse proxy + SSL automatico)
   |
   +---> api.prostaff.gg     -> container api (Puma :3000)
   +---> status.prostaff.gg  -> container status (nginx :80)
   +---> docs.prostaff.gg    -> container docs (nginx :80)

Rede interna (coolify):
   api <-> redis         (cache, sessions, rate limiting)
   api <-> meilisearch   (busca full-text)
   api <-> sidekiq       (background jobs via Redis)
   api <-> PostgreSQL    (banco externo via DATABASE_URL)
```

---

## Componentes configurados

### Docker

- `Dockerfile.production` - Build multi-stage (`ruby:3.4.5-slim`)
  - Stage `build`: instala dependencias, compila bootsnap
  - Stage final: copia gems e app, cria usuario `rails` (uid 1000), healthcheck no `/up`
- `docker-compose.production.yml` - Servicos de producao na rede `coolify`
- `docker-compose.yml` - Ambiente de desenvolvimento (PostgreSQL opcional via `--profile local-db`)

### GitHub Actions

| Arquivo                            | Funcao                                           |
|------------------------------------|--------------------------------------------------|
| `.github/workflows/deploy-staging.yml`    | Deploy automatico no push para `develop`  |
| `.github/workflows/deploy-production.yml` | Deploy via tag semver + aprovacao manual  |
| `.github/workflows/security-scan.yml`    | Brakeman, Bundle Audit, Semgrep, TruffleHog |
| `.github/workflows/load-test.yml`         | Testes de carga com k6                    |
| `.github/workflows/nightly-security.yml`  | Audit completo noturno (1h UTC)           |

### Scripts disponiveis

| Script                              | Funcao                                      |
|-------------------------------------|---------------------------------------------|
| `deploy/scripts/deploy.sh`          | Deploy manual (staging ou production)       |
| `deploy/scripts/rollback.sh`        | Rollback manual                             |
| `deploy/scripts/docker-entrypoint.sh` | Entrypoint do container (migrations, etc) |
| `scripts/backup_database.sh`        | Backup do banco de dados                    |
| `scripts/check_redis_connectivity.sh` | Diagnostico de conectividade Redis        |
| `scripts/check_ssl.sh`              | Verificacao de certificados SSL             |
| `scripts/validate-security.sh`      | Validacao rapida de seguranca               |

### Configuracao do Traefik

O roteamento e configurado via labels Docker no `docker-compose.production.yml`. Nao ha arquivo de configuracao Nginx separado - o Traefik gerencia:

- Roteamento HTTP -> HTTPS (redirect automatico)
- Certificados SSL/TLS via Let's Encrypt
- Headers CORS para a API
- Load balancing

### Configuracao do Puma

`config/puma.rb` configurado para producao com:
- Workers baseados no numero de CPUs disponivel
- Threads configuradas para o ambiente de producao
- Control app para phased restarts

---

## Variaveis de ambiente necessarias

Todas as variaveis sao injetadas via `environment:` no `docker-compose.production.yml` ou via Coolify.
Nenhum arquivo `.env` e carregado em producao.

Ver lista completa em [DEPLOYMENT.md](DEPLOYMENT.md#variaveis-obrigatorias).

---

## Checklist para primeiro deploy

- [ ] Coolify instalado no servidor
- [ ] Rede Docker `coolify` criada
- [ ] DNS configurado (`api.prostaff.gg`, `status.prostaff.gg`, `docs.prostaff.gg`)
- [ ] PostgreSQL externo provisionado (Supabase, Neon, etc.)
- [ ] GitHub Secrets configurados (ver [SECRETS_SETUP.md](SECRETS_SETUP.md))
- [ ] GitHub Environments criados: `staging`, `production-approval`, `production`
- [ ] Revisores adicionados ao ambiente `production-approval`
- [ ] Variaveis de ambiente configuradas no Coolify
- [ ] Primeiro deploy manual executado e validado
- [ ] Health checks passando em todos os servicos

---

## Checklist pre-deploy (cada release)

- [ ] Testes passando localmente (`bundle exec rspec`)
- [ ] RuboCop sem erros (`bundle exec rubocop`)
- [ ] Brakeman sem issues criticos (`brakeman --rails7`)
- [ ] Migrations revisadas e testadas
- [ ] Backup do banco criado
- [ ] Tag semver criada (`git tag -a v1.x.0`)
- [ ] Aprovacao no GitHub Actions concedida

---

## Workflow de desenvolvimento

```
feature/* -> develop
                |
                | push -> GitHub Actions testa + deploy staging
                v
           staging (auto)
                |
                | QA / review
                v
           master + tag -> GitHub Actions testa + approval + deploy production
```
