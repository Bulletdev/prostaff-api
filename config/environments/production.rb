# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.cache_classes = true

  config.eager_load = true

  config.consider_all_requests_local = false

# Disable Rails Host Authorization. 
  # Traefik already filters traffic by domain (prostaff.gg), and this 
  # prevents health checks on internal IPs (like 10.0.x.x) from being blocked.
  config.hosts = nil

  # REMOVE OR COMMENT OUT THESE OLD LINES:
  # config.hosts << 'prostaff.gg'
  # config.hosts << 'www.prostaff.gg'
  # config.hosts << 'api.prostaff.gg'
  # config.hosts << 'prostaff-api-production.up.railway.app'
  # config.hosts << 'localhost'
  # config.hosts << '127.0.0.1'

  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  config.active_storage.variant_processor = :mini_magick

  # SSL Configuration - Traefik terminates SSL, Rails receives HTTP
  config.force_ssl = false


  # Trust all proxies (Traefik, Cloudflare)
  require 'ipaddr'
  config.action_dispatch.trusted_proxies = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("172.16.0.0/16"),
    IPAddr.new("127.0.0.1"),
  ]

  config.log_level = :info

  config.log_tags = [:request_id]

  # Use Redis for caching if available, otherwise fall back to memory store
  config.cache_store = if ENV['REDIS_URL'].present?
                         [
                           :redis_cache_store,
                           {
                             url: ENV['REDIS_URL'],
                             reconnect_attempts: 3,
                             error_handler: lambda { |_method:, _returning:, exception:|
                               Rails.logger.warn "Rails cache Redis error: #{exception.message}"
                             }
                           }
                         ]
                       else
                         :memory_store
                       end

  # Use Sidekiq if Redis is available, otherwise use inline (synchronous)
  config.active_job.queue_adapter = ENV['REDIS_URL'].present? ? :sidekiq : :inline

  config.action_mailer.perform_caching = false

  # Action Mailer configuration
  config.action_mailer.delivery_method = ENV.fetch('MAILER_DELIVERY_METHOD', 'smtp').to_sym
  config.action_mailer.default_url_options = {
    host: ENV.fetch('APP_HOST', 'prostaff-api-production.up.railway.app'),
    protocol: 'https'
  }

  # Only configure SMTP if credentials are provided
  if ENV['SMTP_USERNAME'].present? && ENV['SMTP_PASSWORD'].present?
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('SMTP_ADDRESS', 'smtp.gmail.com'),
      port: ENV.fetch('SMTP_PORT', 587).to_i,
      user_name: ENV['SMTP_USERNAME'],
      password: ENV['SMTP_PASSWORD'],
      authentication: ENV.fetch('SMTP_AUTHENTICATION', 'plain').to_sym,
      enable_starttls_auto: ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true',
      domain: ENV.fetch('SMTP_DOMAIN', 'gmail.com')
    }
  end

  config.i18n.fallbacks = true

  config.active_support.report_deprecations = false

  config.log_formatter = Logger::Formatter.new

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  config.active_record.dump_schema_after_migration = false
end
