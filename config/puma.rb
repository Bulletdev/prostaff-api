# frozen_string_literal: true

# ================================
# Puma Configuration - ProStaff API
# Optimized for Docker / Coolify
# ================================

# Bind obrigatório para container
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

# Ambiente
environment ENV.fetch('RAILS_ENV', 'production')

# PID (necessário para evitar erro de container restart)
pidfile ENV.fetch('PIDFILE', 'tmp/pids/server.pid')

# Threads
max_threads = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
min_threads = ENV.fetch('RAILS_MIN_THREADS', max_threads).to_i
threads min_threads, max_threads

# Workers (IMPORTANTE para container pequeno)
# Se não definir WEB_CONCURRENCY, usa 2
workers ENV.fetch('WEB_CONCURRENCY', 2).to_i

# Preload melhora uso de memória
preload_app!

plugin :tmp_restart

# ================================
# Production Settings
# ================================
if ENV['RAILS_ENV'] == 'production'

  # Timeout de worker
  worker_timeout ENV.fetch('PUMA_WORKER_TIMEOUT', 60).to_i
  worker_boot_timeout ENV.fetch('PUMA_WORKER_BOOT_TIMEOUT', 60).to_i
  worker_shutdown_timeout ENV.fetch('PUMA_WORKER_SHUTDOWN_TIMEOUT', 30).to_i

  # Nakayoshi Fork (Puma 7+)
  if respond_to?(:nakayoshi_fork) && ENV.fetch('PUMA_NAKAYOSHI_FORK', 'true') == 'true'
    nakayoshi_fork
  end

  # ActiveRecord fix para preload
  before_fork do
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  #  Removido activate_control_app
end

# ================================
# Development
# ================================
if ENV['RAILS_ENV'] == 'development'
  workers 0
  debug true if ENV.fetch('PUMA_DEBUG', 'false') == 'true'
end

# ================================
# Logs (container-friendly)
# ================================
# Melhor prática para Docker:
# logar no STDOUT ao invés de arquivos
stdout_redirect nil, nil, true

# ================================
# Boot logs
# ================================
on_booted do
  puts " Puma booted (PID: #{Process.pid})"
  puts "   Environment: #{ENV['RAILS_ENV']}"
  puts "   Workers: #{ENV.fetch('WEB_CONCURRENCY', 2)}"
  puts "   Threads: #{min_threads}-#{max_threads}"
  puts "   Port: #{ENV.fetch('PORT', 3000)}"
end

