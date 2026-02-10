# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  config.eager_load = false

  # nosemgrep: ruby.rails.security.audit.detailed-exceptions.detailed-exceptions
  # We want detailed exceptions in development environment
  config.consider_all_requests_local = true

  config.server_timing = true

  # Enable caching with Redis in development
  config.action_controller.perform_caching = true

  # Use Redis for caching (mesmo que tmp/caching-dev.txt não exista)
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    connect_timeout: 30,
    read_timeout: 1,
    write_timeout: 1,
    reconnect_attempts: 1,
    expires_in: 5.minutes,
    namespace: 'prostaff_dev_cache'
  }

  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{2.days.to_i}"
  }

  config.active_storage.variant_processor = :mini_magick

  # ActionMailer configuration
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: 'localhost', port: 3333 }

  config.action_mailer.smtp_settings = {
    address: ENV.fetch('SMTP_ADDRESS', 'smtp.gmail.com'),
    port: ENV.fetch('SMTP_PORT', 587).to_i,
    user_name: ENV.fetch('SMTP_USERNAME'),
    password: ENV.fetch('SMTP_PASSWORD'),
    authentication: ENV.fetch('SMTP_AUTHENTICATION', 'plain'),
    enable_starttls_auto: ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true',
    domain: ENV.fetch('SMTP_DOMAIN', 'gmail.com')
  }

  config.active_support.deprecation = :log

  config.active_support.disallowed_deprecation = :raise

  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = :page_load

  config.active_record.verbose_query_logs = true

  config.assets.quiet = true if defined?(config.assets)

  config.assets.debug = true if defined?(config.assets)

  config.assets.quiet = true if defined?(config.assets)

  # ActiveJob configuration - use Sidekiq in development
  config.active_job.queue_adapter = :sidekiq

  # Bullet for N+1 query detection
  # Uncomment if using Bullet gem
  # config.after_initialize do
  #   Bullet.enable = true
  #   Bullet.alert = true
  #   Bullet.bullet_logger = true
  #   Bullet.console = true
  #   Bullet.rails_logger = true
  # end
end
