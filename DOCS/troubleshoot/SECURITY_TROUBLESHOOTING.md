# Security Troubleshooting Guide

Instrucoes para executar scans de seguranca manualmente e resolver problemas comuns.

---

## Indice

- [Pre-requisitos](#pre-requisitos)
- [1. Brakeman - Analise do codigo Rails](#1-brakeman---analise-do-codigo-rails)
- [2. Bundle Audit - Vulnerabilidades em gems](#2-bundle-audit---vulnerabilidades-em-gems)
- [3. Semgrep - Analise estatica](#3-semgrep---analise-estatica)
- [4. TruffleHog - Deteccao de secrets](#4-trufflehog---deteccao-de-secrets)
- [5. Problemas comuns e solucoes](#5-problemas-comuns-e-solucoes)
- [6. Workflows GitHub Actions](#6-workflows-github-actions)
- [7. Thresholds e criterios de falha](#7-thresholds-e-criterios-de-falha)
- [8. Referencias](#8-referencias)

---

## Pre-requisitos

```bash
ruby --version   # 3.4.8
docker --version

# jq (opcional, para parsing de JSON)
sudo apt-get install jq
```

---

## 1. Brakeman - Analise do codigo Rails

### Instalacao

```bash
gem install brakeman --no-document
```

### Executar scan

```bash
# Scan basico
brakeman --rails7

# Com output JSON
brakeman --rails7 \
  --format json \
  --output brakeman-report.json \
  --no-exit-on-warn \
  --no-exit-on-error

# Apenas issues de alta confianca (usado no CI)
brakeman --rails7 -w2 --no-pager
```

### Verificar issues de alta confianca

```bash
# Com jq
jq '[.warnings[] | select(.confidence == "High")] | length' brakeman-report.json

# Com Ruby
ruby -rjson -e "
  data = JSON.parse(File.read('brakeman-report.json'))
  high = data['warnings'].select{|w| w['confidence'] == 'High'}
  puts \"High confidence issues: #{high.count}\"
  high.each do |w|
    puts \"- #{w['warning_type']} in #{w['file']}:#{w['line']}\"
    puts \"  #{w['message']}\"
  end
"
```

### Interpretar resultados

| Nivel      | Acao                                                   |
|------------|--------------------------------------------------------|
| High       | Corrigir imediatamente. Bloqueia o CI.                 |
| Medium     | Revisar e avaliar. Pode ser falso positivo.            |
| Weak       | Provavelmente falso positivo. Avaliar caso a caso.     |

### Ignorar falsos positivos

```bash
# Modo interativo para marcar falsos positivos
brakeman -I

# Editar .brakeman.ignore manualmente para adicionar excecoes permanentes
```

---

## 2. Bundle Audit - Vulnerabilidades em gems

### Instalacao

```bash
gem install bundler-audit --no-document
```

### Executar scan

```bash
# Atualizar base de dados de CVEs
bundle-audit update

# Verificar vulnerabilidades
bundle-audit check

# Salvar output
bundle-audit check --output bundle-audit.txt
```

### Resolver vulnerabilidades encontradas

```bash
# Ver qual gem esta vulneravel
bundle-audit check

# Atualizar gem especifica
bundle update nome-da-gem

# Ver versao atual
bundle list | grep nome-da-gem

# Ver informacoes da gem
bundle info nome-da-gem
```

---

## 3. Semgrep - Analise estatica

### Executar via Docker

```bash
# Scan completo
docker run --rm -v "${PWD}:/src" returntocorp/semgrep \
  semgrep scan \
  --config=auto \
  --json \
  --output=/src/semgrep-report.json

# Scan com exclusoes (recomendado para este projeto)
docker run --rm -v "${PWD}:/src" returntocorp/semgrep \
  semgrep scan \
  --config=auto \
  --json \
  --output=/src/semgrep-report.json \
  --exclude='scripts/*.rb' \
  --exclude='scripts/*.sh' \
  --exclude='load_tests/**' \
  --exclude='security_tests/**'
```

### Executar localmente (sem Docker)

```bash
pip install semgrep
semgrep scan --config=auto
```

### Verificar erros encontrados

```bash
# Com jq
jq '[.results[] | select(.extra.severity == "ERROR")] | length' semgrep-report.json

# Com Ruby
ruby -rjson -e "
  data = JSON.parse(File.read('semgrep-report.json'))
  errors = data['results'].select{|r| r.dig('extra', 'severity') == 'ERROR'}
  puts \"ERROR findings: #{errors.count}\"
  errors.each do |r|
    puts \"- #{r['check_id']}\"
    puts \"  File: #{r['path']}:#{r['start']['line']}\"
    puts \"  Message: #{r.dig('extra', 'message')}\"
    puts
  end
"
```

### Suprimir falsos positivos

```ruby
# Suprimir regra especifica com comentario inline
# nosemgrep: rule-id
codigo_aqui

# Suprimir qualquer regra
# nosemgrep
codigo_aqui
```

```bash
# Criar arquivo de ignore
echo "scripts/" >> .semgrepignore
echo "load_tests/" >> .semgrepignore
```

---

## 4. TruffleHog - Deteccao de secrets

### Executar via Docker

```bash
# Apenas secrets verificados (recomendado para CI)
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  filesystem /src \
  --only-verified

# Incluindo nao verificados (mais ruidoso)
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  filesystem /src

# Scan no historico git
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  git file:///src \
  --only-verified
```

TruffleHog so produz output se encontrar secrets. Sem output = sem secrets detectados.

### Ignorar falsos positivos

Criar `.trufflehogignore`:

```
.env.example
*.md
test_data/
```

---

## 5. Problemas comuns e solucoes

### Brakeman: Rails EOL detectado

```bash
# Atualizar Rails no Gemfile
# gem "rails", "~> 7.2.0"
bundle update rails
bundle exec rspec  # garantir que testes passam
```

### Bundle Audit: CVE em gem

```bash
# 1. Identificar a gem
bundle-audit check

# 2. Atualizar
bundle update nome-da-gem

# 3. Se nao houver versao segura, avaliar alternativas ou abrir issue
bundle info nome-da-gem
```

### Semgrep: mass assignment em :role

Falso positivo comum neste projeto. O campo `:role` refere-se a posicao no jogo (top/jungle/mid/adc/support), nao a role de usuario do sistema.

```ruby
def player_params
  # :role refers to in-game position (top/jungle/mid/adc/support), not user role
  # nosemgrep
  params.require(:player).permit(
    :summoner_name, :real_name, :role, # ...
  )
end
```

### GitHub Actions: shell injection

Nunca usar `${{ github.* }}` diretamente em `run:`. Usar variaveis de ambiente:

```yaml
# Vulneravel
- name: Example
  run: echo "Value: ${{ github.event.inputs.value }}"

# Seguro
- name: Example
  env:
    INPUT_VALUE: ${{ github.event.inputs.value }}
  run: echo "Value: $INPUT_VALUE"
```

### TruffleHog: flag duplicado

```yaml
# Errado
extra_args: --only-verified --fail

# Correto
extra_args: --only-verified
```

### Docker indisponivel para Semgrep

```bash
pip install semgrep
semgrep scan --config=auto
```

### Brakeman: warning sobre SQL injection em query dinamica

Verificar se a query usa `sanitize_sql` ou parametros bind corretamente:

```ruby
# Inseguro - gera warning
User.where("name = '#{params[:name]}'")

# Seguro
User.where(name: params[:name])
User.where("name = ?", params[:name])
```

### Rate limiting nao funcionando (rack-attack)

```bash
# Verificar configuracao no ambiente correto
# config/initializers/rack_attack.rb
# Rails.cache deve estar configurado (Redis)

# Testar rate limit
./scripts/test_rate_limit.sh
```

---

## 6. Workflows GitHub Actions

### Ver execucoes recentes

```bash
gh run list --workflow=security-scan.yml
gh run view <run-id> --log
```

### Testar workflows localmente com Act

```bash
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

act -j brakeman
act -j dependency-check
act -j semgrep
```

### Workflows de seguranca

| Workflow                   | Gatilho                          | O que verifica                   |
|----------------------------|----------------------------------|----------------------------------|
| `security-scan.yml`        | Push master/develop, PRs, semanal | Brakeman, Bundle Audit, Semgrep, TruffleHog |
| `nightly-security.yml`     | Todo dia 1h UTC                  | Audit completo com ZAP           |
| `deploy-production.yml`    | Tag v*.*.*                       | Trivy (imagem Docker)            |

---

## 7. Thresholds e criterios de falha

### Criterios que bloqueiam o build (CI falha)

| Ferramenta   | Criterio                                          |
|--------------|---------------------------------------------------|
| Brakeman     | Issues de alta confianca > 0 (`-w2`)              |
| Bundle Audit | Qualquer vulnerabilidade conhecida                |
| Semgrep      | Findings de severidade ERROR > 0                  |
| TruffleHog   | Verified secrets encontrados                      |
| RSpec        | Qualquer teste falhando                           |
| RuboCop      | Qualquer offense (no CI com `--parallel`)         |

### Criterios que geram alerta (build passa)

| Ferramenta   | Criterio                                          |
|--------------|---------------------------------------------------|
| Brakeman     | Issues de confianca Medium ou Weak                |
| Semgrep      | Findings de severidade WARNING                    |
| TruffleHog   | Unverified secrets                                |

---

## 8. Referencias

### Documentacao oficial

- **Brakeman**: https://brakemanscanner.org/
- **Bundle Audit**: https://github.com/rubysec/bundler-audit
- **Semgrep**: https://semgrep.dev/docs/
- **TruffleHog**: https://github.com/trufflesecurity/trufflehog
- **OWASP ZAP**: https://www.zaproxy.org/docs/

### Bancos de dados de vulnerabilidades

- **Ruby Advisory Database**: https://github.com/rubysec/ruby-advisory-db
- **CVE Database**: https://cve.mitre.org/
- **NVD**: https://nvd.nist.gov/

### OWASP

- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **Rails Security Guide**: https://guides.rubyonrails.org/security.html
- **Rails Cheatsheet**: https://cheatsheetseries.owasp.org/cheatsheets/Ruby_on_Rails_Cheat_Sheet.html

---

## Manutencao das ferramentas

```bash
# Atualizar ferramentas regularmente
gem update brakeman
gem update bundler-audit
bundle-audit update

docker pull returntocorp/semgrep:latest
docker pull trufflesecurity/trufflehog:latest
```

### Schedule dos scans automatizados (GitHub Actions)

- **On Push**: Branches `master` e `develop`
- **On PR**: Pull requests para `master` e `develop`
- **Schedule**: Semanalmente nas segundas-feiras, 9h UTC
- **Nightly audit**: Todo dia, 1h UTC
