# ProStaff API - Load & Stress Testing

Suite de testes de carga usando k6 para medir performance da API, identificar gargalos e validar estabilidade sob carga.

## Objetivos

1. **Baseline de Performance**: Estabelecer metricas base da API REST atual
2. **Identificar Gargalos**: Encontrar endpoints lentos e problemas de N+1 query
3. **Breaking Points**: Determinar capacidade maxima antes de degradacao
4. **Pre-deploy Validation**: Garantir que mudancas nao regridam performance

## Setup

### Instalar k6

```bash
./load_tests/k6-setup.sh
```

Ou manualmente:
- **Linux**: `sudo apt-get install k6`
- **macOS**: `brew install k6`
- **Windows**: `choco install k6`

### Configurar Usuario de Teste

Crie o usuario de teste no banco ou use credenciais existentes:

```bash
# No arquivo .env
TEST_EMAIL=test@prostaff.gg
TEST_PASSWORD=Test123!@#
```

## Cenarios de Teste

### 1. Smoke Test (1 min)

**Objetivo**: Verificacao rapida de sanidade, carga minima

```bash
./load_tests/run-tests.sh smoke local
```

**Perfil**:
- 1 virtual user
- Testa endpoints basicos
- Valida setup e autenticacao

### 2. Load Test (16 min)

**Objetivo**: Simulacao de trafego normal

```bash
./load_tests/run-tests.sh load local
```

**Perfil**:
- Rampa 0 -> 10 -> 50 usuarios
- Workflows realistas de usuario
- p(95) < 1000ms

**Casos de Uso**:
- Dashboard browsing (60%)
- Analytics review (30%)
- Gestao de players (10%)

### 3. Stress Test (28 min)

**Objetivo**: Encontrar ponto de quebra

```bash
./load_tests/run-tests.sh stress local
```

**Perfil**:
- Rampa 0 -> 50 -> 100 -> 200 -> 300 usuarios
- Queries agressivas
- Testa DB connection pool, Redis, memoria

### 4. Spike Test (7.5 min)

**Objetivo**: Pico subito de trafego (ex: anuncio de torneio)

```bash
./load_tests/run-tests.sh spike local
```

**Perfil**:
- Salto instantaneo: 10 -> 500 usuarios
- Testa caching e recuperacao
- Mede tempo de estabilizacao

### 5. Soak Test (3+ horas)

**Objetivo**: Estabilidade de longa duracao, deteccao de memory leaks

```bash
./load_tests/run-tests.sh soak local
```

**Perfil**:
- 50 usuarios concorrentes por 3 horas
- Monitora degradacao ao longo do tempo
- Detecta memory leaks e problemas de connection pool

## Interpretando Resultados

### Metricas Principais

**Tempos de Resposta**:
- `http_req_duration`: Tempo total da requisicao
- `http_req_waiting`: Tempo ate o primeiro byte (TTFB)
- p(95) < 1000ms - Aceitavel
- p(95) > 2000ms - Problema

**Throughput**:
- `http_reqs`: Total de requisicoes
- `iterations`: Workflows completos de usuario
- Maior e melhor

**Erros**:
- `http_req_failed`: Requisicoes com falha
- < 1% - Aceitavel
- > 5% - Problema critico

**Metricas Customizadas**:
- `dashboard_duration`: Tempo de carregamento do dashboard
- `analytics_duration`: Tempo de query de analytics
- `errors`: Taxa de erros

### Localizacao dos Resultados

```
load_tests/results/
├── smoke_20260225_120000/
│   ├── results.json       # Metricas completas
│   ├── summary.json       # Stats agregados
│   └── output.log         # Saida do console
```

### Lendo o Summary

```bash
# Ver metricas principais
jq '.metrics.http_req_duration' results/smoke_*/summary.json

# Verificar taxa de erros
jq '.metrics.http_req_failed.values.rate' results/smoke_*/summary.json

# Percentis de tempo de resposta
jq '.metrics.http_req_duration.values' results/smoke_*/summary.json
```

## Executando por Ambiente

### Local
```bash
./load_tests/run-tests.sh load local
```

### Staging
```bash
./load_tests/run-tests.sh load staging
```

### Producao (CUIDADO!)
```bash
# Execute apenas smoke/load, NUNCA stress contra producao
./load_tests/run-tests.sh smoke production
./load_tests/run-tests.sh load production
```

**Nunca execute stress/spike/soak contra producao.**

## Analisando Gargalos

### Endpoints Lentos

Procure por `http_req_duration` alto em endpoints especificos:

```
# Saida do k6
dashboard loaded
  avg=1250ms  -- Lento!
  p(95)=2500ms

players list loaded
  avg=150ms   -- Rapido
  p(95)=300ms
```

**Acoes**:
1. Verificar Rails logs para N+1 queries
2. Adicionar indexes no banco
3. Implementar caching
4. Considerar paginacao

### Problemas de Banco

Sintomas:
- Erros durante stress test
- `http_req_failed` aumenta com a carga
- Erros 500/503 nos logs

**Verificacao**:
```bash
# Nos logs do Rails durante o teste
tail -f log/development.log | grep -E '(timeout|connection|pool)'
```

**Solucoes**:
- Aumentar DB connection pool
- Adicionar read replicas
- Otimizar queries lentas

### Memory Leaks

Execute o soak test e monitore:

```bash
# Durante o soak test
docker stats prostaff-api
# Ou localmente
top -p $(pgrep -f puma)
```

**Sinais de alerta**:
- Uso de memoria crescendo ao longo do tempo
- Erros OOM apos horas
- Degradacao do tempo de resposta

## Testes Continuos

### Checklist Pre-deploy

```bash
# Antes de cada release
./load_tests/run-tests.sh smoke staging
./load_tests/run-tests.sh load staging

# Para mudancas criticas de performance
./load_tests/run-tests.sh stress staging
```

### Integracao CI/CD

Ver `.github/workflows/load-test.yml` (se configurado).

## Uso Avancado

### Cenarios Customizados

Crie seu proprio teste em `scenarios/`:

```javascript
import { config } from '../config.js';

export const options = {
  stages: [
    { duration: '5m', target: 100 },
  ],
};

export default function() {
  // Logica do teste
}
```

### Variaveis de Ambiente

```bash
# Configuracao customizada
BASE_URL=http://localhost:3333 \
TEST_EMAIL=custom@email.com \
./load_tests/run-tests.sh load local
```

### Formatos de Output

```bash
# CSV
k6 run --out csv=results.csv scenarios/load-test.js

# InfluxDB (analise de series temporais)
k6 run --out influxdb=http://localhost:8086/k6 scenarios/load-test.js
```

## Endpoints Testados

Baseado nas rotas atuais da API (`config/routes.rb`):

| Grupo | Endpoints |
|-------|-----------|
| Auth | `POST /api/v1/auth/login`, `GET /api/v1/auth/me` |
| Dashboard | `GET /api/v1/dashboard/stats`, `GET /api/v1/dashboard/activities` |
| Players | `GET /api/v1/players`, `GET /api/v1/players/:id` |
| Analytics | `GET /api/v1/analytics/performance`, `GET /api/v1/analytics/kda-trend/:id` |
| Matches | `GET /api/v1/matches`, `GET /api/v1/matches/:id` |

Configuracao completa em `load_tests/config.js`.

## Recursos

- [k6 Documentation](https://k6.io/docs/)
- [Load Testing Best Practices](https://k6.io/docs/testing-guides/test-types/)
- [Interpreting Results](https://k6.io/docs/using-k6/metrics/)

## Proximos Passos

1. Executar smoke test para validar setup
2. Executar load test para baseline de performance
3. Identificar endpoints lentos nos resultados
4. Otimizar gargalos encontrados
5. Re-executar testes para medir melhoria
