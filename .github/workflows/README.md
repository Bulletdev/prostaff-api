# GitHub Actions Security Workflows

Este diretório contém workflows automatizados de segurança para o ProStaff API.

## Workflows Disponíveis

### 1. `security-scan.yml` - Security Scan Completo

**Trigger:** Push/PR em `master` ou `develop`, agendamento semanal

**Jobs:**

#### Static Analysis (SAST)

1. **Brakeman** - Análise de segurança específica para Rails
2. **Dependency Check** - Verifica vulnerabilidades em gems (Bundle Audit)
3. **Semgrep** - Análise estática com regras customizáveis
4. **Secret Scan** - Detecta secrets com TruffleHog

#### Dynamic Analysis (DAST) - NOVO!

5. **SSRF Protection** - Testa proteção contra Server-Side Request Forgery
* Testa bloqueio de localhost, IPs privados, AWS metadata
* Verifica whitelist de domínios
* Confirma que autenticação é obrigatória


6. **Authentication Test** - Valida segurança de autenticação
* Testa rejeição de tokens inválidos/ausentes
* Verifica endpoints protegidos
* Valida endpoints públicos (health check)


7. **SQL Injection Test** - Testa proteção contra SQL injection
* Testa queries parametrizadas
* Verifica bloqueio de UNION injection
* Valida que erros SQL não vazam


8. **Secrets Scan** - Verifica secrets expostos
* Busca hardcoded passwords
* Verifica API keys
* Confirma .env não está no git



#### Summary

9. **Security Summary** - Consolida todos os resultados
* Posta comentário no PR com tabela de status
* Separa SAST vs DAST
* Indica se pode fazer merge



---

## Como Funciona

### Estrutura dos Jobs DAST

Cada job DAST segue este padrão:

```yaml
services:
  postgres:
    image: postgres:15-alpine
    # ...
  redis:
    image: redis:7-alpine
    # ...

steps:
  1. Checkout do código
  2. Setup Ruby + bundler
  3. Setup database (rails db:migrate)
  4. Start Rails server (porta 3333)
  5. Wait for API (/up endpoint)
  6. Run security test script
  7. Upload results (artifacts)

```

### Scripts de Teste

Os scripts estão em `.pentest/`:

| Script | Testes | O que valida |
| --- | --- | --- |
| `test-ssrf-quick.sh` | 9 | SSRF protection |
| `test-authentication-quick.sh` | 5 | JWT auth |
| `test-sql-injection-quick.sh` | 4 | SQL injection |
| `test-secrets-quick.sh` | 5 | Secrets management |

---

## Como Usar

### Desenvolvimento Local

```bash
# Rodar todos os testes de segurança
./.pentest/test-ssrf-quick.sh
./.pentest/test-authentication-quick.sh
./.pentest/test-sql-injection-quick.sh
./.pentest/test-secrets-quick.sh

```

### Pull Requests

Ao criar um PR, o workflow automaticamente:

1. Roda todos os scans (SAST + DAST)
2. Posta comentário com resumo dos resultados
3. Bloqueia merge se houver falhas críticas

**Exemplo de comentário no PR:**

```markdown
## Security Scan Summary

### Static Analysis (SAST)
| Check | Status |
|-------|--------|
| Brakeman | success |
| Dependencies | success |
| Semgrep | success |
| Secrets | success |

### Dynamic Analysis (DAST)
| Check | Status |
|-------|--------|
| SSRF Protection | success |
| Authentication | success |
| SQL Injection | success |

All security checks passed!

```

### Agendamento

O workflow pode rodar semanalmente (comentado por padrão):

```yaml
# Descomentar para ativar
schedule:
  - cron: '0 9 * * 1'  # Segunda-feira 9am UTC

```

---

## Artifacts

Cada job gera artifacts que podem ser baixados:

* `brakeman-report.json` - Relatório Brakeman
* `bundle-audit-report.txt` - Relatório de dependências
* `semgrep-report.json` - Relatório Semgrep
* `ssrf-test-results/` - Resultados dos testes SSRF

**Como baixar:**

1. Vá em Actions > Workflow run
2. Scroll down até "Artifacts"
3. Download do artifact desejado

---

## Troubleshooting

### Testes DAST falhando

**Problema:** API não sobe ou timeout esperando `/up`

**Solução:**

```yaml
# Aumentar timeout em .github/workflows/security-scan.yml
- name: Wait for API
  run: |
    timeout 120 bash -c 'until curl -sf http://localhost:3333/up; do sleep 2; done'

```

**Problema:** Testes passam localmente mas falham no CI

**Causa comum:** Diferenças de ambiente (variáveis, portas, etc)

**Debug:**

```yaml
# Adicionar step de debug
- name: Debug
  run: |
    curl -v http://localhost:3333/up
    docker logs <container_name>

```

### Secrets não encontrados

**Problema:** TruffleHog não roda (action externa)

**Solução:** Script `.pentest/test-secrets-quick.sh` faz scan básico mesmo sem TruffleHog

### Rate Limit no Multi-Tenancy

**Problema:** Testes de multi-tenancy falham por rate limit (3 reg/hour)

**Solução:** Criar test data via seeds em vez de criar via API:

```ruby
# db/seeds/test_organizations.rb
if Rails.env.test?
  org1 = Organization.create!(name: "Test Org 1", slug: "test-org-1")
  org2 = Organization.create!(name: "Test Org 2", slug: "test-org-2")
  # ...
end

```

---

## Adicionando Novos Testes

### 1. Criar script de teste

```bash
# .pentest/test-new-feature.sh
#!/bin/bash
API_URL="http://localhost:3333"
# ... testes

```

### 2. Adicionar job ao workflow

```yaml
new-feature-test:
  name: New Feature Security Test
  runs-on: ubuntu-latest
  services:
    postgres: { ... }
    redis: { ... }
  steps:
    - uses: actions/checkout@v4
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.4.5
        bundler-cache: true
    - name: Setup Database
      run: bundle exec rails db:migrate RAILS_ENV=test
    - name: Start Server
      run: bundle exec rails s -p 3333 -d
    - name: Run Tests
      run: ./.pentest/test-new-feature.sh

```

### 3. Adicionar ao summary

```yaml
security-summary:
  needs: [..., new-feature-test]
  # ...
  const newFeature = '${{ needs.new-feature-test.result }}';
  # ...

```

---

## Configuração de Secrets

O workflow precisa destes secrets configurados em **Settings → Secrets → Actions**:

| Secret | Obrigatório? | Uso |
| --- | --- | --- |
| `RIOT_API_KEY` | Não | Testes que envolvem Riot API (fallback: dummy_key) |
| `SENTRY_DSN` | Não | Reporting de erros |

**Como configurar:**

1. GitHub → Repository → Settings
2. Secrets and variables → Actions
3. New repository secret
4. Nome: `RIOT_API_KEY`, Value: `sua_api_key`

---

## Performance

**Tempo médio de execução:**

| Job | Duração | Pode rodar em paralelo? |
| --- | --- | --- |
| Brakeman | ~1 min | Sim |
| Dependencies | ~2 min | Sim |
| Semgrep | ~3 min | Sim |
| SSRF Test | ~2 min | Sim |
| Auth Test | ~2 min | Sim |
| SQL Injection | ~2 min | Sim |
| Secrets | ~1 min | Sim |

**Total:** ~3-4 minutos (em paralelo)

---

## Integrações Futuras

### Recomendado adicionar:

1. **OWASP ZAP** - Scan de vulnerabilidades web
2. **Nuclei** - Template-based scanning
3. **Multi-tenancy test** - Quando resolver rate limit
4. **JWT security test** - Algorithm confusion, expiration
5. **Rate limiting test** - Validar Rack::Attack

### Como adicionar ZAP:

```yaml
zap-scan:
  name: OWASP ZAP Scan
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: ZAP Baseline Scan
      uses: zaproxy/action-baseline@v0.7.0
      with:
        target: 'http://localhost:3333'

```

---

## Compliance

Este workflow cobre:

* **OWASP Top 10 2025**
* A01: Broken Access Control (Auth tests)
* A02: Cryptographic Failures (Secrets scan)
* A03: Injection (SQL injection tests)
* A04: Insecure Design (Code review)
* A05: Security Misconfiguration (Brakeman)
* A06: Vulnerable Components (Dependency check)
* A07: Auth Failures (Auth tests)
* A08: Data Integrity (Semgrep)
* A09: Logging Failures (Code review)
* A10: SSRF (SSRF tests)


* **SAST + DAST** (Static + Dynamic analysis)
* **SCA** (Software Composition Analysis)
* **Secrets Detection**

---

## Referências

* [Brakeman Docs](https://brakemanscanner.org/docs/)
* [Bundle Audit](https://github.com/rubysec/bundler-audit)
* [Semgrep Rules](https://semgrep.dev/r)
* [TruffleHog](https://github.com/trufflesecurity/trufflehog)
* [OWASP Top 10 2025](https://owasp.org/www-project-top-ten/)

---

**Last Updated:** 2026-03-04
**Maintainer:** Security Team
**CI/CD Status:** Active

---
