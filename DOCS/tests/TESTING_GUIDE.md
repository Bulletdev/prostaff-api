# ProStaff API - Guia de Testes

Guia de referencia para executar testes unitarios, de integracao, de carga e de seguranca.

---

## Indice

- [Stack de testes](#stack-de-testes)
- [Testes unitarios e de integracao (RSpec)](#testes-unitarios-e-de-integracao-rspec)
- [Qualidade de codigo](#qualidade-de-codigo)
- [Testes de seguranca](#testes-de-seguranca)
- [Testes de carga (k6)](#testes-de-carga-k6)
- [CI/CD - Automacao](#cicd---automacao)
- [Runbooks](#runbooks)

---

## Stack de testes

| Ferramenta         | Finalidade                          | Quando usar              |
|--------------------|-------------------------------------|--------------------------|
| RSpec              | Testes unitarios e de integracao    | Desenvolvimento continuo |
| SimpleCov          | Cobertura de codigo                 | Por execucao de RSpec    |
| FactoryBot         | Criacao de objetos de teste         | Dentro dos specs         |
| Faker              | Dados falsos para testes            | Dentro dos specs         |
| VCR + WebMock      | Mock de requisicoes HTTP externas   | Specs que usam Riot API  |
| DatabaseCleaner    | Limpeza do banco entre testes       | Configurado automaticamente |
| Shoulda Matchers   | Matchers para models Rails          | Specs de model           |
| RuboCop            | Linting e estilo de codigo          | Pre-commit / CI          |
| Brakeman           | Analise de seguranca do codigo      | CI + manual              |
| Bundle Audit       | Vulnerabilidades em gems            | CI + semanal             |
| Semgrep            | Analise estatica (SAST)             | CI + PRs                 |
| TruffleHog         | Deteccao de secrets no codigo       | CI + todo commit         |
| k6                 | Testes de carga e performance       | Pre-release / semanal    |
| OWASP ZAP          | Scan de seguranca web (DAST)        | Semanal / noturno        |
| Trivy              | Scan de vulnerabilidades em imagens | CI/CD                    |

---

## Testes unitarios e de integracao (RSpec)

### Pre-requisitos locais

```bash
ruby --version   # 3.4.5
bundle install

# Banco de teste (necessario PostgreSQL rodando)
bundle exec rails db:create RAILS_ENV=test
bundle exec rails db:schema:load RAILS_ENV=test
```

Com Docker:

```bash
# Subir PostgreSQL local para testes
docker compose --profile local-db up -d postgres

# Ou usar um DATABASE_URL externo no .env.test
```

### Executar testes

```bash
# Suite completa
bundle exec rspec

# Com formato de documentacao
bundle exec rspec --format documentation

# Arquivo ou diretorio especifico
bundle exec rspec spec/models/player_spec.rb
bundle exec rspec spec/controllers/

# Por tag
bundle exec rspec --tag focus
bundle exec rspec --tag ~slow

# Paralelo (mais rapido em projetos grandes)
bundle exec rspec --format progress
```

### Cobertura de codigo

SimpleCov e ativado automaticamente quando `COVERAGE=true`:

```bash
COVERAGE=true bundle exec rspec
open coverage/index.html
```

### Estrutura dos specs

```
spec/
├── controllers/          # Specs de controllers (requests)
├── factories/            # FactoryBot factories
├── integration/          # Testes de integracao end-to-end
├── jobs/                 # Specs de Sidekiq jobs
├── models/               # Specs de models (validacoes, associacoes)
├── policies/             # Specs de Pundit policies
├── requests/             # Request specs (testa HTTP completo)
├── services/             # Specs de service objects
├── support/              # Helpers e configuracoes compartilhadas
│   └── factory_bot.rb
├── rails_helper.rb       # Configuracao principal do RSpec
├── spec_helper.rb        # Configuracao base
└── swagger_helper.rb     # Configuracao do rswag (geracao de swagger)
```

### Configuracao relevante (rails_helper.rb)

- `DatabaseCleaner` configurado para limpar entre testes
- `FactoryBot` disponivel sem prefixo
- `Shoulda Matchers` configurado para Rails
- `VCR` configurado para gravar/reproduzir chamadas HTTP externas

---

## Qualidade de codigo

### RuboCop

```bash
# Verificar todos os arquivos
bundle exec rubocop

# Correcao automatica segura
bundle exec rubocop -a

# Correcao automatica incluindo sugestoes
bundle exec rubocop -A

# Arquivo especifico
bundle exec rubocop app/models/player.rb

# Paralelo (mais rapido)
bundle exec rubocop --parallel
```

Configurado com `rubocop-rails` e `rubocop-rspec`. Regras em `.rubocop.yml`.

### Brakeman (analise de seguranca do codigo Rails)

```bash
# Scan basico
brakeman --rails7

# Com output JSON (para CI/CD)
brakeman --rails7 \
  --format json \
  --output brakeman-report.json \
  --no-exit-on-warn \
  --no-exit-on-error

# Ver apenas issues de alta confianca
brakeman --rails7 -w2

# Ignorar falsos positivos interativamente
brakeman -I
```

Niveis de confianca:
- `High` - Corrigir imediatamente. Bloqueia o build no CI.
- `Medium` - Revisar e avaliar.
- `Weak` - Provavelmente falso positivo, avaliar caso a caso.

---

## Testes de seguranca

### Bundle Audit (vulnerabilidades em gems)

```bash
# Atualizar base de dados de CVEs
bundle-audit update

# Verificar vulnerabilidades
bundle-audit check

# Atualizar gem vulneravel
bundle update nome-da-gem
```

### Semgrep (analise estatica)

```bash
# Via Docker
docker run --rm -v "${PWD}:/src" returntocorp/semgrep \
  semgrep scan \
  --config=auto \
  --json \
  --output=/src/semgrep-report.json \
  --exclude='scripts/*.rb' \
  --exclude='load_tests/**' \
  --exclude='security_tests/**'

# Ou instalado localmente
pip install semgrep
semgrep scan --config=auto
```

### TruffleHog (deteccao de secrets)

```bash
# Scan do filesystem (apenas secrets verificados)
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  filesystem /src \
  --only-verified

# Scan do historico git
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  git file:///src \
  --only-verified
```

### Audit completo de seguranca

```bash
# Script all-in-one
./security_tests/scripts/full-security-audit.sh

# Scripts individuais
./security_tests/scripts/brakeman-scan.sh
./security_tests/scripts/dependency-scan.sh
./security_tests/scripts/zap-baseline-scan.sh
```

### OWASP Top 10 Checklist

Antes de qualquer deploy em producao, verificar:

- [ ] Issues criticos/altos do Brakeman corrigidos
- [ ] Nenhuma dependencia vulneravel conhecida
- [ ] Security headers configurados (via Traefik/Rack)
- [ ] Rate limiting ativo (`rack-attack`)
- [ ] Autenticacao JWT testada
- [ ] Autorizacao com Pundit testada (prevencao de IDOR)
- [ ] Validacao de parametros com strong parameters
- [ ] Secrets nao commitados no codigo
- [ ] Audit completo passou sem issues criticos

Checklist completo: `security_tests/OWASP_TOP_10_CHECKLIST.md`

---

## Testes de carga (k6)

Localizado em `load_tests/`.

### Setup

```bash
./load_tests/k6-setup.sh
```

### Tipos de teste

| Tipo    | Duracao  | Objetivo                     | Frequencia         |
|---------|----------|------------------------------|--------------------|
| Smoke   | ~1 min   | Validacao rapida             | Todo commit        |
| Load    | ~16 min  | Simulacao de trafego normal  | Antes de merge     |
| Stress  | ~28 min  | Encontrar limites            | Semanal            |
| Spike   | ~7.5 min | Picos de trafego             | Pre-release        |
| Soak    | 3+ horas | Memoria e leaks              | Mensal             |

### Executar

```bash
# Localmente (API rodando na porta 3333)
bundle exec rails server
./load_tests/run-tests.sh smoke local
./load_tests/run-tests.sh load local

# Contra staging
./load_tests/run-tests.sh load staging

# CUIDADO em producao - apenas smoke/load, nunca stress
./load_tests/run-tests.sh smoke production
```

### Interpretar resultados

Performance aceitavel (REST e suficiente):
```
http_req_duration p(95) < 500ms
http_req_failed < 1%
Sem timeouts
```

Sinais de alerta:
```
5+ chamadas de API por pagina
Payloads > 100KB com dados nao utilizados
Endpoints de dashboard com p(95) > 2s
Problemas de N+1 query visiveis
```

### Ver resultados

```bash
cat load_tests/results/load_*/summary.json | jq '.metrics.http_req_duration.values'
```

---

## CI/CD - Automacao

### Workflows ativos

**security-scan.yml** - Em todo push e PR:
- Brakeman (analise do codigo Rails)
- Bundle Audit (vulnerabilidades em gems)
- Semgrep (SAST)
- TruffleHog (deteccao de secrets)
- Falha o PR se encontrar issues criticos

**load-test.yml** - Manual ou noturno:
- Trigger manual pelo GitHub Actions
- Smoke test automatico por schedule
- Relatorio de metricas de performance

**nightly-security.yml** - Toda noite (1h UTC):
- Audit completo com OWASP ZAP
- Cria GitHub Issue automaticamente se encontrar vulnerabilidades

**deploy-staging.yml** e **deploy-production.yml** - Em cada deploy:
- RSpec (suite completa)
- RuboCop
- Brakeman
- Trivy (scan da imagem Docker)

### Executar workflows manualmente

```bash
# Via GitHub CLI
gh workflow run load-test.yml \
  -f test_type=load \
  -f environment=staging

gh workflow run security-scan.yml

# Via GitHub UI: Actions -> [Workflow] -> Run workflow
```

### Secrets necessarios para testes automatizados

```
TEST_EMAIL=test@prostaff.gg
TEST_PASSWORD=<senha_da_conta_de_teste>
```

Configurar em: **Settings** -> **Secrets and variables** -> **Actions**

---

## Runbooks

### Runbook 1: Verificacao semanal de seguranca

Toda segunda-feira, ~15 minutos:

```bash
# 1. Verificar vulnerabilidades em gems
bundle-audit update && bundle-audit check

# 2. Atualizar gems vulneraveis
bundle update nome-da-gem

# 3. Rodar testes para garantir compatibilidade
bundle exec rspec

# 4. Rodar Brakeman
brakeman --rails7

# 5. Revisar e corrigir issues encontrados
# 6. Commitar correcoes
```

### Runbook 2: Pre-release (antes de cada deploy em producao)

~30-60 minutos:

```bash
# 1. Rodar suite completa de testes
bundle exec rspec --format documentation

# 2. RuboCop sem erros
bundle exec rubocop --parallel

# 3. Brakeman sem issues criticos
brakeman --rails7 -w2

# 4. Audit de seguranca completo
./security_tests/scripts/full-security-audit.sh

# 5. Smoke test em staging
./load_tests/run-tests.sh smoke staging

# 6. Revisar OWASP checklist
# 7. Se tudo passou, criar tag e iniciar pipeline de producao
git tag -a v1.x.0 -m "Release v1.x.0"
git push origin v1.x.0
```

### Runbook 3: Resposta a incidente de seguranca

**Severidade Critica/Alta:**

```bash
# 1. AVALIAR (5 min)
# - O que esta afetado?
# - Quantos usuarios?
# - Esta sendo explorado?

# 2. CONTER (15 min)
# - Desabilitar endpoint/feature afetada se possivel
# - Notificar equipe imediatamente

# 3. CORRIGIR
bundle exec rspec spec/  # confirmar o problema existe em teste
# Implementar correcao
bundle exec rspec spec/  # confirmar a correcao funciona

# 4. DEPLOY DE EMERGENCIA
./deploy/scripts/deploy.sh production

# 5. VERIFICAR
curl https://api.prostaff.gg/up
brakeman --rails7

# 6. POS-MORTEM
# Criar documento descrevendo o incidente, causa raiz e prevencao
```

**Severidade Media/Baixa:**

```bash
# 1. Criar issue no GitHub com label 'security'
# 2. Incluir no proximo sprint
# 3. Seguir processo normal de desenvolvimento
# 4. Incluir teste de regressao na correcao
```

### Runbook 4: Investigar performance lenta

```bash
# 1. Reproduzir o problema
./load_tests/run-tests.sh load staging
# Notar quais endpoints estao lentos

# 2. Verificar logs
docker compose -f docker-compose.production.yml logs -f api | grep "Completed 200"
# Procurar queries lentas (> 100ms)

# 3. Identificar N+1 queries (no Rails console)
docker compose -f docker-compose.production.yml exec api bundle exec rails console
# > ActiveRecord::Base.logger = Logger.new(STDOUT)
# > # Executar a acao problemática

# 4. Verificar banco de dados
# EXPLAIN ANALYZE na query lenta

# 5. Correcoes comuns:
# - Adicionar eager loading: includes(:association)
# - Adicionar indice: add_index :table, :column
# - Adicionar cache: Rails.cache.fetch("key", expires_in: 5.minutes)

# 6. Verificar melhoria
./load_tests/run-tests.sh load local
# Comparar metricas antes/depois
```

### Runbook 5: Revisao mensal de seguranca

Primeiro dia de cada mes, ~2-3 horas:

```bash
# 1. Audit completo
./security_tests/scripts/full-security-audit.sh

# 2. Revisar logs de acesso
docker compose -f docker-compose.production.yml logs api | grep "401\|403\|429" | tail -100

# 3. Revisar audit logs internos (Rails console)
# > AuditLog.where("created_at > ?", 1.month.ago).where(action: "failed_login").count

# 4. Atualizar dependencias
bundle update --patch

# 5. Revisar OWASP checklist completo

# 6. Documentar resultados e acoes tomadas
```

---

## Boas praticas

### Desenvolvimento

- Rodar Brakeman antes de cada commit em mudancas sensiveis
- Revisar resultados de scan de seguranca nos PRs
- Nunca commitar secrets (TruffleHog detecta automaticamente)
- Usar strong parameters em todos os controllers
- Testar autorizacao (Pundit policies), nao apenas autenticacao

### Testes

- Rodar smoke test antes de cada PR
- Rodar load test antes de releases
- Audit de seguranca antes de deploy em producao

### Producao

- Security headers ativos (configurados via Traefik)
- Rate limiting ativo via `rack-attack`
- Error tracking configurado
- Logs monitorados

---

## Referencias

- [Load Tests](../../load_tests/README.md)
- [Security Tests](../../security_tests/README.md)
- [OWASP Top 10 Checklist](../../security_tests/OWASP_TOP_10_CHECKLIST.md)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [RSpec Docs](https://rspec.info/)
- [k6 Docs](https://k6.io/docs/)
- [Brakeman Docs](https://brakemanscanner.org/)
