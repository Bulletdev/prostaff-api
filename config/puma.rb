# Puma configuration file for ProStaff API

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# Specifies the number of `threads` to use per worker.
# This controls how many threads Puma will use to process requests.
# The default is set to 5 threads as a decent default for most Ruby/Rails apps.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# === Production Optimizations ===
if ENV["RAILS_ENV"] == "production" || ENV["RAILS_ENV"] == "staging"
  # Increase workers in production
  workers ENV.fetch("WEB_CONCURRENCY") { 4 }

  # Bind to socket for better nginx integration (optional)
  # bind "unix://#{ENV.fetch('APP_ROOT', Dir.pwd)}/tmp/sockets/puma.sock"

  # Logging
  stdout_redirect(
    ENV.fetch("PUMA_STDOUT_LOG") { "#{Dir.pwd}/log/puma_access.log" },
    ENV.fetch("PUMA_STDERR_LOG") { "#{Dir.pwd}/log/puma_error.log" },
    true
  )

  # Worker timeout (seconds)
  # Kill workers if they hang for more than this time
  worker_timeout ENV.fetch("PUMA_WORKER_TIMEOUT") { 60 }.to_i

  # Worker boot timeout
  worker_boot_timeout ENV.fetch("PUMA_WORKER_BOOT_TIMEOUT") { 60 }.to_i

  # Worker shutdown timeout
  worker_shutdown_timeout ENV.fetch("PUMA_WORKER_SHUTDOWN_TIMEOUT") { 30 }.to_i

  # === Phased Restart (Zero Downtime Deploys) ===
  # This allows Puma to restart workers one at a time
  # instead of all at once during a restart
  # Use: pumactl phased-restart
  on_worker_boot do
    # Worker specific setup for Rails
    # This is needed for preload_app to work with ActiveRecord
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  before_fork do
    # Disconnect from database before forking
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end

  # === Nakayoshi Fork (Memory Optimization) ===
  # This reduces memory usage by running GC before forking
  nakayoshi_fork if ENV.fetch("PUMA_NAKAYOSHI_FORK") { "true" } == "true"

  # === Low Level Configuration ===
  # Configure the queue for accepting connections
  # When backlog is full, new connections are rejected
  backlog ENV.fetch("PUMA_BACKLOG") { 1024 }.to_i

  # Set the TCP_CORK and TCP_NODELAY options on the connection socket
  tcp_nopush true if ENV.fetch("PUMA_TCP_NOPUSH") { "true" } == "true"

  # === Monitoring ===
  # Activate control/status app
  # Allows you to query Puma for stats and control it
  # Access via: pumactl stats -C unix://#{Dir.pwd}/tmp/sockets/pumactl.sock
  activate_control_app "unix://#{Dir.pwd}/tmp/sockets/pumactl.sock", { no_token: true }
end

# === Development Optimizations ===
if ENV["RAILS_ENV"] == "development"
  # Use fewer workers in development
  workers 0

  # Verbose logging in development
  debug true if ENV.fetch("PUMA_DEBUG") { "false" } == "true"
end

# === Callbacks ===
on_booted do
  puts "🚀 Puma booted (PID: #{Process.pid})"
  puts "   Environment: #{ENV['RAILS_ENV']}"
  puts "   Workers: #{ENV.fetch('WEB_CONCURRENCY', 2)}"
  puts "   Threads: #{min_threads_count}-#{max_threads_count}"
  puts "   Port: #{ENV.fetch('PORT', 3000)}"
end

on_worker_boot do |worker_index|
  puts "👷 Worker #{worker_index} booted (PID: #{Process.pid})"
end

on_worker_shutdown do |worker_index|
  puts "👷 Worker #{worker_index} shutting down (PID: #{Process.pid})"
end

# === Health Check Endpoint ===
# This is automatically handled by Rails /up endpoint
# No additional configuration needed here
