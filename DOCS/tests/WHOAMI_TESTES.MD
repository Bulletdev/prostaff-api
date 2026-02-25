# Lab de Testes - Resumo

Resumo do ambiente de testes configurado para o ProStaff API.

---

## O que esta configurado

### Testes de carga (k6)

Localizado em `load_tests/`. Usa k6 para avaliar performance dos endpoints REST.

Tipos de cenario disponivel:
- Smoke (1 min) - validacao rapida
- Load (16 min) - trafego normal
- Stress (28 min) - limite da aplicacao
- Spike (7.5 min) - picos de trafego
- Soak (3h+) - leaks de memoria

Setup:
```bash
./load_tests/k6-setup.sh
bundle exec rails server
./load_tests/run-tests.sh smoke local
```

### Testes de seguranca (OWASP)

Localizado em `security_tests/`.

Ferramentas incluidas:
- OWASP ZAP (scanner web)
- Brakeman (analise estatica Rails)
- Bundle Audit (vulnerabilidades em gems)
- Semgrep (SAST)
- Trivy (scan de containers)
- TruffleHog (deteccao de secrets)
- Nuclei (scanner de vulnerabilidades)

Setup:
```bash
./security_tests/zap-setup.sh
./security_tests/scripts/brakeman-scan.sh
./security_tests/scripts/full-security-audit.sh
```

### Automacao CI/CD

- Security scan em todo PR (`.github/workflows/security-scan.yml`)
- Smoke test automatico diario (`.github/workflows/load-test.yml`)
- Audit completo noturno, 1h UTC (`.github/workflows/nightly-security.yml`)
- Cria GitHub Issue automaticamente se vulnerabilidades forem encontradas

---

## Uso rapido

### Verificar performance

```bash
bundle exec rails server
./load_tests/run-tests.sh smoke local    # 1 min
./load_tests/run-tests.sh load local     # 16 min
```

### Verificar seguranca

```bash
./security_tests/scripts/brakeman-scan.sh   # ~30s
bundle-audit update && bundle-audit check   # ~10s
```

### Pre-release completo

```bash
# Staging
./load_tests/run-tests.sh load staging
./security_tests/scripts/full-security-audit.sh https://staging-api.prostaff.gg
```

---

## Referencias

Ver [TESTING_GUIDE.md](TESTING_GUIDE.md) para documentacao completa com runbooks e boas praticas.
