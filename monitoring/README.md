# ProStaff Observability Stack

Node Exporter + cAdvisor + Prometheus + Grafana, isolado do compose principal.

## Setup

```bash
cp .env.monitoring.example .env.monitoring
# edite .env.monitoring e defina GRAFANA_ADMIN_PASSWORD
```

## Subir

```bash
docker compose -f docker-compose.monitoring.yml --env-file .env.monitoring up -d
```

## Portas

| Servico      | Porta local    | URL                          |
|--------------|---------------|------------------------------|
| Grafana      | 3001          | http://localhost:3001        |
| Prometheus   | 9090          | http://localhost:9090        |
| Node Exporter| 9100          | http://localhost:9100/metrics|
| cAdvisor     | 9200          | http://localhost:9200/metrics|

Todas as portas estão vinculadas a `127.0.0.1` — acesse via SSH tunnel em produção:

```bash
ssh -L 3001:localhost:3001 -L 9090:localhost:9090 user@seu-servidor
```

## Importar dashboards prontos

1. Acesse Grafana → Dashboards → Import
2. Cole o ID e clique em Load:

| Dashboard              | ID    |
|------------------------|-------|
| Node Exporter Full     | 1860  |
| Docker / cAdvisor      | 14282 |

3. Selecione o datasource **Prometheus** e confirme.

## Habilitar métricas da API Rails

Descomente o job `prostaff-api` em `monitoring/prometheus.yml` após adicionar
a gem `prometheus-client` e expor o endpoint `/metrics` nas rotas.

## Parar

```bash
docker compose -f docker-compose.monitoring.yml down
```

Para remover volumes (apaga histórico de métricas):

```bash
docker compose -f docker-compose.monitoring.yml down -v
```
