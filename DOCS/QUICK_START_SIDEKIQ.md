# Quick Start: Sidekiq Scheduler

Guia rápido para iniciar o Sidekiq com agendamento de jobs.

## Pré-requisitos

- Redis instalado e rodando
- Gems instaladas (`bundle install`)

## Iniciar em Desenvolvimento

### 1. Verifique o Redis

```bash
redis-cli ping
# Deve retornar: PONG
```

Se o Redis não estiver rodando:

```bash
# Linux/Mac
redis-server

# Com Docker
docker run -d -p 6379:6379 redis:alpine
```

### 2. Inicie o Sidekiq

Em um terminal separado:

```bash
bundle exec sidekiq
```

Você deverá ver:

```
         _  _
        (_)(_)
   ___  _  _  __| | ___| | __(_) __ _
  / __|| |/ _` |/ _ \ |/ / |/ _` |
  \__ \| | (_| |  __/   <| | (_| |
  |___/|_|\__,_|\___|_|\_\_|\__, |
                              |_|

📅 Schedule loaded:
  - cleanup_expired_tokens (daily at 2:00 AM)
```

### 3. Verificar Job Agendado

No console Rails:

```ruby
rails console

# Ver schedule
Sidekiq.schedule
# => {"cleanup_expired_tokens"=>{"cron"=>"0 2 * * *", "class"=>"CleanupExpiredTokensJob", ...}}

# Ver próxima execução
SidekiqScheduler::Scheduler.instance.rufus_scheduler.jobs.each do |job|
  puts "#{job.tags.first}: next run at #{job.next_time}"
end
```

### 4. Testar Job Manualmente

```ruby
# No console Rails
CleanupExpiredTokensJob.perform_now
# => Executa imediatamente

# Ou em background
CleanupExpiredTokensJob.perform_later
# => Enfileira para execução
```

## Verificar Status

### Via Console

```ruby
# Ver jobs na fila
Sidekiq::Queue.all.each do |queue|
  puts "#{queue.name}: #{queue.size} jobs"
end

# Ver workers ativos
Sidekiq::Workers.new.size

# Ver estatísticas
stats = Sidekiq::Stats.new
puts "Processed: #{stats.processed}"
puts "Failed: #{stats.failed}"
puts "Enqueued: #{stats.enqueued}"
```

### Via Web UI (Opcional)

Adicione ao `config/routes.rb`:

```ruby
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

mount Sidekiq::Web => '/sidekiq'
```

Acesse: http://localhost:3333/sidekiq

## Logs

```bash
# Ver logs do Sidekiq
tail -f log/sidekiq.log

# Ver logs do Rails
tail -f log/development.log
```

## Parar o Sidekiq

```bash
# Graceful shutdown (aguarda jobs terminarem)
Ctrl+C

# Force shutdown
Ctrl+C (duas vezes)
```

## Troubleshooting

### Redis não conecta

```bash
# Verifique a URL do Redis
echo $REDIS_URL
# Se vazio, use: redis://localhost:6379/0

# Teste a conexão
redis-cli -u redis://localhost:6379/0 ping
```

### Schedule não carrega

```bash
# Verifique o arquivo de configuração
cat config/sidekiq.yml

# Teste o carregamento manual
bundle exec rails runner "pp YAML.load_file('config/sidekiq.yml')[:schedule]"
```

### Jobs não executam

1. Certifique-se de que o Sidekiq está rodando
2. Verifique os logs: `tail -f log/sidekiq.log`
3. Teste manualmente: `CleanupExpiredTokensJob.perform_now`

## Próximos Passos

- Leia a documentação completa: `DOCS/SIDEKIQ_SCHEDULER_GUIDE.md`
- Configure jobs adicionais em `config/sidekiq.yml`
- Adicione monitoramento com Web UI
- Configure systemd/supervisor para produção

## Jobs Configurados

### CleanupExpiredTokensJob

- **Frequência**: Diariamente às 2:00 AM
- **Função**: Limpa tokens expirados (password reset e JWT blacklist)
- **Execução manual**: `CleanupExpiredTokensJob.perform_now`

---

Pronto! Seu Sidekiq com agendamento está configurado e rodando! 🚀
