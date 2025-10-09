# ProStaff API - Security Testing Lab

Laboratório completo de testes de segurança para a API ProStaff, incluindo análise estática, análise dinâmica e varredura de vulnerabilidades.

## Ferramentas Incluídas

| Ferramenta | Tipo | Descrição |
|------------|------|-----------|
| **OWASP ZAP** | DAST | Análise dinâmica de segurança web |
| **Brakeman** | SAST | Analisador de segurança específico para Rails |
| **Semgrep** | SAST | Análise estática de código com regras customizáveis |
| **Trivy** | SCA | Scanner de vulnerabilidades em dependências |
| **Dependency-Check** | SCA | Análise de vulnerabilidades conhecidas (CVE) |
| **Nuclei** | DAST | Scanner de vulnerabilidades web rápido |

##  Quick Start

### 1. Iniciar o Laboratório Completo

\`\`\`bash
./security_tests/start-security-lab.sh
\`\`\`

Este comando irá:
- ✅ Iniciar todos os containers de ferramentas de segurança
- ✅ Iniciar a aplicação ProStaff API  
- ✅ Aguardar a API ficar pronta
- ✅ Conectar tudo na mesma rede Docker

### 2. Executar Todos os Scans

\`\`\`bash
./security_tests/run-security-scans.sh
\`\`\`

### 3. Parar o Laboratório

\`\`\`bash
./security_tests/stop-security-lab.sh
\`\`\`

## 📊 Relatórios

Após executar os scans, os relatórios estarão disponíveis em:

```
security_tests/
├── reports/
│   ├── brakeman/
│   │   └── brakeman-report.html
│   ├── dependency-check/
│   │   ├── dependency-check-report.html
│   │   └── dependency-check-report.json
│   ├── semgrep/
│   │   └── semgrep-report.json
│   ├── trivy/
│   │   └── trivy-report.json
│   └── nuclei/
│       └── nuclei-report.json
└── zap/
    └── reports/
        ├── zap-report.html
        └── zap-report.json
```

### Visualizar Relatórios

```bash
# Brakeman
xdg-open security_tests/reports/brakeman/brakeman-report.html

# Dependency Check
xdg-open security_tests/reports/dependency-check/dependency-check-report.html

# ZAP
xdg-open security_tests/zap/reports/zap-report.html

# JSON reports
cat security_tests/reports/semgrep/semgrep-report.json | jq
cat security_tests/reports/trivy/trivy-report.json | jq
```

## Executar Scans Individuais

### Brakeman (já executado automaticamente ao iniciar)
```bash
docker exec prostaff-brakeman brakeman --rails7 --output /reports/brakeman-report.html --format html
```

### Semgrep
```bash
docker exec prostaff-semgrep semgrep \
  --config=auto \
  --json \
  --output=/reports/semgrep-report.json \
  /src
```

### Trivy
```bash
docker exec prostaff-trivy trivy fs \
  --format json \
  --output /reports/trivy-report.json \
  /app
```

### Nuclei
```bash
docker exec prostaff-nuclei nuclei \
  -u http://prostaff-api:3000 \
  -json \
  -o /reports/nuclei-report.json
```

### OWASP ZAP - Baseline Scan
```bash
docker exec prostaff-zap zap-baseline.py \
  -t http://prostaff-api:3000 \
  -J /zap/reports/zap-report.json \
  -r /zap/reports/zap-report.html
```

### OWASP ZAP - Full Scan (mais lento, mais completo)
```bash
docker exec prostaff-zap zap-full-scan.py \
  -t http://prostaff-api:3000 \
  -J /zap/reports/zap-full-report.json \
  -r /zap/reports/zap-full-report.html
```

## 🌐 Interfaces Web

- **ProStaff API**: http://localhost:3333
- **ZAP Web Interface**: http://localhost:8087/zap
- **ZAP API**: http://localhost:8097

## Comandos Úteis

### Verificar Status dos Containers
```bash
docker ps | grep prostaff
```

### Ver Logs
```bash
# API
docker logs prostaff-api -f

# ZAP
docker logs prostaff-zap -f

# Brakeman
docker logs prostaff-brakeman

# Todos os containers de segurança
docker compose -f security_tests/docker-compose.security.yml -p security_tests logs -f
```

### Reiniciar um Container Específico
```bash
docker restart prostaff-zap
docker restart prostaff-api
```

### Reconstruir a Aplicação
```bash
docker-compose build api
docker-compose up -d api
```

## Configuração

### Variáveis de Ambiente (.env)

Crie um arquivo `.env` na raiz do projeto com:

```env
# Database
POSTGRES_DB=prostaff_api_development
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
DATABASE_URL=postgresql://postgres:password@postgres:5432/prostaff_api_development

# Redis
REDIS_URL=redis://redis:6379/0

# Rails
RAILS_ENV=development
JWT_SECRET_KEY=your_secret_key_here

# API
CORS_ORIGINS=http://localhost:3000,http://localhost:3333

# External APIs
RIOT_API_KEY=your_riot_api_key_here
```

##  Boas Práticas

1. **Execute os scans regularmente**: Idealmente em cada commit ou antes de cada release
2. **Revise todos os relatórios**: Priorize vulnerabilidades críticas e altas
3. **Mantenha as ferramentas atualizadas**:
   ```bash
   docker compose -f security_tests/docker-compose.security.yml pull
   ```
4. **Documente falsos positivos**: Use arquivos de supressão quando apropriado
5. **Integre ao CI/CD**: Automatize os scans em seu pipeline

## Troubleshooting

### API não está acessível
```bash
# Verifique se a API está rodando
docker ps | grep prostaff-api

# Verifique os logs
docker logs prostaff-api

# Teste o health endpoint
curl http://localhost:3333/up
```

### ZAP pedindo autenticação
- Acesse: http://localhost:8087/zap (não http://localhost:8087)
- A autenticação foi desabilitada na configuração

### Nuclei sem resultados
- Confirme que a API está rodando: `curl http://localhost:3333/up`
- Verifique se o container está na rede correta: `docker network inspect security_tests_security-net`

### Containers encerrando imediatamente
- Verifique os logs: `docker logs <container_name>`
- Confirme que os volumes estão corretos no docker-compose.yml
- Verifique se a aplicação Rails está no diretório pai: `../`

### Erro de bundle/gems não encontradas
```bash
# Reconstrua a imagem
docker-compose build api

# Force bundle install
docker-compose run --rm api bundle install
```

## 📚 Documentação

- [OWASP ZAP](https://www.zaproxy.org/docs/)
- [Brakeman](https://brakemanscanner.org/docs/)
- [Semgrep](https://semgrep.dev/docs/)
- [Trivy](https://aquasecurity.github.io/trivy/)
- [Dependency-Check](https://jeremylong.github.io/DependencyCheck/)
- [Nuclei](https://docs.projectdiscovery.io/tools/nuclei/overview)

## 🤝 Contribuindo

Para adicionar novas ferramentas ou melhorar os scans:

1. Edite `docker-compose.security.yml`
2. Adicione scripts de execução em `run-security-scans.sh`
3. Documente as mudanças neste README
4. Teste completamente antes de commitar

## 🎯 Arquitetura

```
┌─────────────────────────────────────────────────────┐
│           Security Testing Lab Network              │
│                                                      │
│  ┌──────────────┐      ┌──────────────┐            │
│  │  ProStaff    │◄─────┤  OWASP ZAP   │  DAST      │
│  │     API      │      │  (Baseline)  │            │
│  │              │      └──────────────┘            │
│  │  Rails 7.2   │                                   │
│  │  Port: 3333  │      ┌──────────────┐            │
│  └──────┬───────┘      │    Nuclei    │  DAST      │
│         │              └──────────────┘            │
│         │                                           │
│  ┌──────▼───────────────────────────────┐          │
│  │     Application Code                 │          │
│  │                                       │          │
│  │  ┌───────────┐  ┌────────────┐      │          │
│  │  │ Brakeman  │  │  Semgrep   │  SAST│          │
│  │  └───────────┘  └────────────┘      │          │
│  │                                       │          │
│  │  ┌───────────┐  ┌────────────┐      │          │
│  │  │   Trivy   │  │Dependency- │  SCA │          │
│  │  │           │  │   Check    │      │          │
│  │  └───────────┘  └────────────┘      │          │
│  └───────────────────────────────────────┘         │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## 📝 Licença

Este laboratório de segurança é parte do projeto ProStaff API.
