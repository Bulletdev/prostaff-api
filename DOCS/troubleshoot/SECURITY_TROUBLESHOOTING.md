# Security Troubleshooting Guide

Este documento contém instruções para executar manualmente os scans de segurança do projeto e resolver problemas comuns.

## Índice

- [Pré-requisitos](#pré-requisitos)
- [1. Brakeman - Security Scanner](#1-brakeman---security-scanner)
- [2. Bundle Audit - Dependency Vulnerabilities](#2-bundle-audit---dependency-vulnerabilities)
- [3. Semgrep - Static Analysis](#3-semgrep---static-analysis)
- [4. TruffleHog - Secret Detection](#4-trufflehog---secret-detection)
- [5. Resolvendo Problemas Comuns](#5-resolvendo-problemas-comuns)
- [6. Referências](#6-referências)

---

## Pré-requisitos

```bash
ruby --version  # 3.4.5

docker --version

# jq (opcional, para parsing de JSON)
sudo apt-get install jq
```

---

## 1. Brakeman - Security Scanner

### Instalação

```bash
gem install brakeman --no-document
```

### Executar Scan Completo

```bash
brakeman --rails7

brakeman --rails7 \
  --format json \
  --output brakeman-report.json \
  --no-exit-on-warn \
  --no-exit-on-error
```

### Verificar High Confidence Issues

```bash
jq '[.warnings[] | select(.confidence == "High")] | length' brakeman-report.json

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

### Interpretando Resultados

- **Confidence Levels**: High, Medium, Weak
- **High confidence**: Deve ser corrigido imediatamente
- **Medium confidence**: Revisar e avaliar
- **Weak confidence**: Pode ser falso positivo

### Ignorar False Positives

```bash
brakeman -I

# Editar .brakeman.ignore manualmente sempre que necessário skipar um warning
```

---

## 2. Bundle Audit - Dependency Vulnerabilities

### Instalação

```bash
gem install bundler-audit --no-document
```

### Executar Scan

```bash
# Atualizar database de vulnerabilidades
bundle-audit update

bundle-audit check

# Checar com output para arquivo
bundle-audit check --output bundle-audit.txt
```

### Atualizar Gems Vulneráveis

```bash
# Ver qual gem tem vulnerabilidade
bundle-audit check

# Atualizar gem específica
bundle update nome-da-gem

# Atualizar todas as gems
bundle update
```

### Verificar Versões

```bash
# Ver versão atual de uma gem
bundle list | grep nome-da-gem

# Ver versão no Gemfile.lock
grep -A 1 "nome-da-gem (" Gemfile.lock
```

---

## 3. Semgrep - Static Analysis

### Executar com Docker

```bash
# Scan completo
docker run --rm -v "${PWD}:/src" returntocorp/semgrep \
  semgrep scan \
  --config=auto \
  --json \
  --output=/src/semgrep-report.json

# Scan com exclusões
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

### Verificar Erros

```bash
# Com jq
jq '[.results[] | select(.extra.severity == "ERROR")] | length' semgrep-report.json

# Com Ruby
ruby -rjson -e "
  data = JSON.parse(File.read('semgrep-report.json'))
  results = data['results']
  errors = results.select{|r| r.dig('extra', 'severity') == 'ERROR'}
  puts \"ERROR severity findings: #{errors.count}\"
  errors.each do |r|
    puts \"- #{r['check_id']}\"
    puts \"  File: #{r['path']}:#{r['start']['line']}\"
    puts \"  Message: #{r.dig('extra', 'message')}\"
    puts
  end
"
```

### Suprimir False Positives

```bash
# Adicionar comentário no código
# nosemgrep: rule-id
código_aqui

# Ou comentário genérico
# nosemgrep
código_aqui

# Criar .semgrepignore
echo "scripts/" >> .semgrepignore
echo "load_tests/" >> .semgrepignore
```

---

## 4. TruffleHog - Secret Detection

### Executar com Docker

```bash
# Scan apenas verified secrets
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  filesystem /src \
  --only-verified

# Scan incluindo unverified
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  filesystem /src

# Scan em commits do Git
docker run --rm -v "${PWD}:/src" trufflesecurity/trufflehog:latest \
  git file:///src \
  --only-verified
```

### Verificar Resultados

TruffleHog mostra secrets encontrados diretamente no output. Se nenhum secret for encontrado, não haverá output.

### Ignorar False Positives

Crie um `.trufflehogignore`:

```bash
# Exemplo
.env.example
*.md
test_data/
```

---

## 5. Resolvendo Problemas Comuns

### Problema: Brakeman encontra Rails EOL

**Solução:**
```bash
# Atualizar Rails no Gemfile
# Mudar de: gem "rails", "~> 7.1.0"
# Para:     gem "rails", "~> 7.2.0"

bundle update rails
```

### Problema: Bundle Audit encontra CVE em gem

**Solução:**
```bash
# 1. Identificar a gem vulnerável
bundle-audit check

# 2. Atualizar a gem
bundle update nome-da-gem

# 3. Se não houver versão segura, avaliar alternativas
bundle info nome-da-gem
```

### Problema: Semgrep encontra mass assignment em :role

**Solução:**

Este é geralmente um falso positivo quando `:role` se refere a posição no jogo (top/jungle/mid/adc/support) e não a role de usuário.

```ruby
def player_params
  # :role refers to in-game position (top/jungle/mid/adc/support), not user role
  # nosemgrep
  params.require(:player).permit(
    :summoner_name, :real_name, :role, # ...
  )
end
```

### Problema: GitHub Actions shell injection

**Solução:**

Nunca use `${{ github.* }}` diretamente em `run:` scripts. Use environment variables:

```yaml
# ❌ Vulnerável
- name: Example
  run: |
    echo "Value: ${{ github.event.inputs.value }}"

# ✅ Seguro
- name: Example
  env:
    INPUT_VALUE: ${{ github.event.inputs.value }}
  run: |
    echo "Value: $INPUT_VALUE"
```

### Problema: TruffleHog error "flag 'fail' cannot be repeated"

**Solução:**

Remova o flag `--fail` duplicado no workflow:

```yaml
# ❌ Errado
extra_args: --only-verified --fail

# ✅ Correto
*extra_args: --only-verified
```

### Problema: Docker não disponível para Semgrep

**Solução:**

Instale Semgrep localmente:

```bash
pip install semgrep

semgrep scan --config=auto
```

---

## 6. Comandos Rápidos de Verificação

### Script All-in-One

Crie um arquivo `scripts/security-check.sh`:

```bash
#!/bin/bash
set -e

echo "🔍 Running security checks..."
echo

echo "1️⃣  Brakeman..."
brakeman --rails7 --format json --output brakeman-report.json --no-exit-on-warn --no-exit-on-error
HIGH=$(ruby -rjson -e "puts JSON.parse(File.read('brakeman-report.json'))['warnings'].select{|w| w['confidence'] == 'High'}.count")
echo "   High confidence issues: $HIGH"
echo

echo "2️⃣  Bundle Audit..."
bundle-audit update
bundle-audit check || echo "   ⚠️  Vulnerabilities found"
echo

echo "3️⃣  Semgrep..."
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan --config=auto --json --output=/src/semgrep-report.json --exclude='scripts/*.rb' --exclude='load_tests/**' || true
ERRORS=$(ruby -rjson -e "puts JSON.parse(File.read('semgrep-report.json'))['results'].select{|r| r.dig('extra', 'severity') == 'ERROR'}.count")
echo "   ERROR severity findings: $ERRORS"
echo

echo "✅ Security checks complete!"
```

Executar:

```bash
chmod +x scripts/security-check.sh
./scripts/security-check.sh
```

---

## 7. Verificar Workflows GitHub Actions

### Testar Localmente com Act

```bash
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

act -j brakeman
act -j dependency-check
act -j semgrep
```

### Ver Logs de Workflows

```bash
gh run list --workflow=security-scan.yml
gh run view <run-id> --log
```

---

## 8. Thresholds e Critérios

### Quando Falhar o Build

- **Brakeman**: High confidence issues > 0
- **Bundle Audit**: Qualquer vulnerabilidade conhecida
- **Semgrep**: ERROR severity > 0
- **TruffleHog**: Verified secrets encontrados

### Quando Apenas Alertar

- **Brakeman**: Medium/Weak confidence issues
- **Semgrep**: WARNING severity
- **TruffleHog**: Unverified secrets

---

## Referências

### Documentação Oficial

- **Brakeman**: https://brakemanscanner.org/
- **Bundle Audit**: https://github.com/rubysec/bundler-audit
- **Semgrep**: https://semgrep.dev/docs/
- **TruffleHog**: https://github.com/trufflesecurity/trufflehog

### Banco de Dados de Vulnerabilidades

- **Ruby Advisory Database**: https://github.com/rubysec/ruby-advisory-db
- **CVE Database**: https://cve.mitre.org/
- **National Vulnerability Database**: https://nvd.nist.gov/

### OWASP Resources

- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **Rails Security Guide**: https://guides.rubyonrails.org/security.html
- **Ruby on Rails Cheatsheet**: https://cheatsheetseries.owasp.org/cheatsheets/Ruby_on_Rails_Cheat_Sheet.html

---

## Manutenção

### Atualizar Tools Regularmente

```bash
gem update brakeman

gem update bundler-audit
bundle-audit update

docker pull returntocorp/semgrep:latest

docker pull trufflesecurity/trufflehog:latest
```

### Agendar Scans Automático

Os workflows do GitHub Actions já estão configurados para rodar:

- **On Push**: Branches master e develop
- **On PR**: Pull requests para master e develop
- **Schedule**: Semanalmente às segundas-feiras 9h UTC

---

**Última atualização**: 2025-10-08
