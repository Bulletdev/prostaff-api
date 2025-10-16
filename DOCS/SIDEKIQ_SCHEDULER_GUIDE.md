# Sidekiq Scheduler Guide

Este guia explica como usar o Sidekiq com agendamento de tarefas recorrentes usando `sidekiq-scheduler`.

## O que foi Configurado

### 1. Gems Instaladas

```ruby
gem "sidekiq", "~> 7.0"
gem "sidekiq-scheduler"
```

### 2. Arquivo de Configuração

`config/sidekiq.yml` contém:
- Configurações básicas do Sidekiq (concurrency, queues, etc.)
- Schedule de jobs recorrentes

### 3. Initializer

`config/initializers/sidekiq.rb` carrega automaticamente o schedule quando o Sidekiq inicia.

### 4. Job Agendado

`CleanupExpiredTokensJob` executa diariamente às 2h da manhã para limpar:
- Tokens de reset de senha expirados ou usados
- Tokens JWT blacklisted expirados

---

## Como Iniciar o Sidekiq

### Desenvolvimento (Local)

```bash
# Certifique-se de que o Redis está rodando
redis-cli ping  # Deve retornar "PONG"

# Inicie o Sidekiq
bundle exec sidekiq
```

### Com Docker Compose

O Sidekiq já deve estar configurado no `docker-compose.yml`:

```yaml
sidekiq:
  build: .
  command: bundle exec sidekiq
  depends_on:
    - postgres
    - redis
  environment:
    - REDIS_URL=redis://redis:6379/0
    - DATABASE_URL=postgresql://postgres:password@postgres:5432/prostaff_api_development
```

Inicie com:

```bash
docker-compose up sidekiq
```

---

## Gerenciamento de Schedule

### Adicionar Novo Job Agendado

Edite `config/sidekiq.yml`:

```yaml
:schedule:
  # Job existente
  cleanup_expired_tokens:
    cron: '0 2 * * *'
    class: CleanupExpiredTokensJob
    description: 'Clean up expired tokens'

  # Novo job com cron expression
  sync_player_stats:
    cron: '*/30 * * * *'  # A cada 30 minutos
    class: SyncPlayerStatsJob
    description: 'Sync player stats from Riot API'

  # Novo job com expressão "every"
  send_daily_digest:
    every: '1d'  # Uma vez por dia
    class: SendDailyDigestJob
    description: 'Send daily digest email to users'

  # Job com expressão "in"
  cleanup_old_logs:
    in: 1h  # Executa 1 hora após o início
    class: CleanupOldLogsJob
    description: 'Clean up old log files'
```

### Formatos de Agendamento

#### Cron Expression

```yaml
cron: '0 2 * * *'  # Diariamente às 2:00 AM
cron: '*/15 * * * *'  # A cada 15 minutos
cron: '0 */6 * * *'  # A cada 6 horas
cron: '0 9 * * 1'  # Toda segunda-feira às 9:00 AM
cron: '0 0 1 * *'  # Primeiro dia de cada mês à meia-noite
```

Formato: `minute hour day month day_of_week`

#### Every Expression

```yaml
every: '30s'   # A cada 30 segundos
every: '5m'    # A cada 5 minutos
every: '2h'    # A cada 2 horas
every: '1d'    # Uma vez por dia
every: '1w'    # Uma vez por semana
```

#### At Expression

```yaml
at: '3:41 am'          # Diariamente às 3:41 AM
at: 'Tuesday 14:00'    # Toda terça às 14:00
at: 'first day 10:00'  # Primeiro dia do mês às 10:00
```

---

## Monitoramento

### Web UI do Sidekiq

Adicione ao `config/routes.rb`:

```ruby
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Proteja em produção!
  mount Sidekiq::Web => '/sidekiq'
end
```

Acesse: `http://localhost:3333/sidekiq`

### CLI do Sidekiq

```bash
# Ver jobs enfileirados
bundle exec sidekiq-cli stats

# Ver status dos workers
bundle exec sidekiq-cli status

# Parar Sidekiq gracefully
bundle exec sidekiqctl stop tmp/pids/sidekiq.pid

# Parar Sidekiq forçadamente
bundle exec sidekiqctl stop tmp/pids/sidekiq.pid 0
```

---

## Comandos Úteis

### Via Rails Console

```ruby
# Ver schedule carregado
Sidekiq.schedule

# Ver próximas execuções
SidekiqScheduler::Scheduler.instance.rufus_scheduler.jobs.each do |job|
  puts "#{job.tags.first}: next run at #{job.next_time}"
end

# Recarregar schedule
SidekiqScheduler::Scheduler.instance.reload_schedule!

# Executar job manualmente (imediatamente)
CleanupExpiredTokensJob.perform_now

# Enfileirar job para execução em background
CleanupExpiredTokensJob.perform_later

# Enfileirar job com delay
CleanupExpiredTokensJob.set(wait: 1.hour).perform_later
```

### Testar Schedule

```ruby
# No console Rails
schedule_file = Rails.root.join('config', 'sidekiq.yml')
schedule = YAML.load_file(schedule_file)
pp schedule[:schedule]
```

---

## Exemplo de Job Completo

```ruby
# app/jobs/example_scheduled_job.rb
class ExampleScheduledJob < ApplicationJob
  queue_as :default

  # Opcional: retry com estratégia customizada
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(*args)
    Rails.logger.info "Starting ExampleScheduledJob..."

    # Sua lógica aqui
    do_something_important

    Rails.logger.info "ExampleScheduledJob completed successfully"
  rescue => e
    Rails.logger.error "Error in ExampleScheduledJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e  # Re-raise para o Sidekiq tentar novamente
  end

  private

  def do_something_important
    # Implementação
  end
end
```

---

## Configurações de Produção

### Variáveis de Ambiente

```env
# Redis
REDIS_URL=redis://redis:6379/0

# Sidekiq
SIDEKIQ_CONCURRENCY=10
SIDEKIQ_TIMEOUT=30
```

### Atualizar Sidekiq Initializer

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5
  }

  # Configurações dinâmicas
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5).to_i
  config.timeout = ENV.fetch('SIDEKIQ_TIMEOUT', 25).to_i
end
```

### systemd Service (Linux)

Crie `/etc/systemd/system/sidekiq.service`:

```ini
[Unit]
Description=Sidekiq Background Worker
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/prostaff-api/current
Environment=RAILS_ENV=production
ExecStart=/usr/local/bin/bundle exec sidekiq
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Gerenciar:

```bash
sudo systemctl enable sidekiq
sudo systemctl start sidekiq
sudo systemctl status sidekiq
sudo systemctl restart sidekiq
```

---

## Troubleshooting

### Jobs Não Estão Executando

1. Verifique se o Sidekiq está rodando:
   ```bash
   ps aux | grep sidekiq
   ```

2. Verifique os logs:
   ```bash
   tail -f log/sidekiq.log
   ```

3. Verifique o schedule carregado (console Rails):
   ```ruby
   Sidekiq.schedule
   ```

### Redis Não Está Conectando

```bash
# Teste a conexão
redis-cli -u $REDIS_URL ping

# Verifique as configurações
echo $REDIS_URL
```

### Jobs Falhando Silenciosamente

Adicione logging detalhado:

```ruby
class MyJob < ApplicationJob
  def perform
    Rails.logger.info "Job started at #{Time.current}"
    # ... seu código ...
  rescue => e
    Rails.logger.error "Job failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
```

### Schedule Não Atualiza

Reinicie o Sidekiq após alterar `config/sidekiq.yml`:

```bash
# Desenvolvimento
pkill -USR1 sidekiq  # Graceful restart

# Produção com systemd
sudo systemctl restart sidekiq
```

---

## Melhores Práticas

1. **Jobs Idempotentes**: Jobs devem ser seguros para executar múltiplas vezes
2. **Timeout Apropriado**: Configure timeout adequado para jobs longos
3. **Retry Strategy**: Defina estratégia de retry apropriada
4. **Logging**: Sempre adicione logs detalhados
5. **Monitoramento**: Use a Web UI para monitorar performance
6. **Queues Separadas**: Use queues diferentes para prioridades diferentes
7. **Error Handling**: Sempre capture e logue exceções
8. **Cleanup**: Tenha jobs de limpeza para dados temporários

---

## Referências

- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq/wiki)
- [Sidekiq-Scheduler Documentation](https://github.com/sidekiq-scheduler/sidekiq-scheduler)
- [Cron Expression Generator](https://crontab.guru/)
- [Fugit (cron parser)](https://github.com/floraison/fugit)

---

## Suporte

Para questões ou problemas, consulte a documentação oficial ou abra uma issue no repositório.
