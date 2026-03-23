# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do # rubocop:disable Metrics/BlockLength
  config.cache_classes = true

  config.eager_load = true

  config.consider_all_requests_local = false

  # Rails Host Authorization allowlist.
  #
  # Traefik terminates external traffic and forwards with the correct Host header.
  # Docker/Coolify health checks originate from internal IPs (10.x.x.x, 172.16-31.x.x),
  # so those ranges are allowed via regex to prevent blocking liveness/readiness probes.
  #
  # Gap 9 fix (FAILURE_MODE_ANALYSIS.md): replaces config.hosts = nil so that
  # Host header injection is rejected if traffic bypasses Traefik.
  config.hosts = [
    'api.prostaff.gg',
    'prostaff.gg',
    'www.prostaff.gg',
    ENV.fetch('APP_HOST', nil),
    # Internal IPs: Docker bridge, Coolify overlay, localhost — used by health check probes
    /\A(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)(:\d+)?\z/
  ].compact

  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  config.active_storage.variant_processor = :mini_magick

  # SSL Configuration - Traefik terminates SSL, Rails receives HTTP
  # Note: SSL is enforced at the Traefik layer (reverse proxy), not at the Rails layer.
  # This is secure because: (1) Traefik handles HTTPS/TLS termination, (2) internal
  # communication between Traefik and Rails is over a private Docker network.
  # Setting force_ssl = true would cause redirect loops.
  #
  # Security: We trust X-Forwarded-Proto header from Traefik to detect HTTPS
  config.force_ssl = false # nosemgrep: ruby.lang.security.force-ssl-false.force-ssl-false
  config.ssl_options = { redirect: { exclude: ->(request) { request.path.start_with?('/health') } } }

  # Trust all proxies (Traefik, Cloudflare)
  require 'ipaddr'
  config.action_dispatch.trusted_proxies = [
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('172.16.0.0/16'),
    IPAddr.new('127.0.0.1')
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
  config.action_mailer.default_url_options = {
    host: ENV.fetch('APP_HOST', 'api.prostaff.gg'),
    protocol: 'https'
  }

  # Only configure SMTP if credentials are provided; fall back to :test to avoid
  # "SMTP-AUTH requested but missing user name" errors when vars are absent.
  if ENV['SMTP_USERNAME'].present? && ENV['SMTP_PASSWORD'].present?
    config.action_mailer.delivery_method = ENV.fetch('MAILER_DELIVERY_METHOD', 'smtp').to_sym
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('SMTP_ADDRESS', 'smtp.gmail.com'),
      port: ENV.fetch('SMTP_PORT', 587).to_i,
      user_name: ENV['SMTP_USERNAME'],
      password: ENV['SMTP_PASSWORD'],
      authentication: ENV.fetch('SMTP_AUTHENTICATION', 'plain').to_sym,
      enable_starttls_auto: ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true',
      domain: ENV.fetch('SMTP_DOMAIN', 'gmail.com')
    }
  else
    config.action_mailer.delivery_method = :test
    Rails.logger.warn '[Mailer] SMTP_USERNAME/SMTP_PASSWORD not set — mail delivery disabled (using :test adapter)'
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

  # Remove X-Runtime header — vaza tempo de processamento, facilita timing attacks
  config.middleware.delete(Rack::Runtime)

  # Security headers
  config.action_dispatch.default_headers.merge!(
    'X-Frame-Options' => 'DENY',
    'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy' => "default-src 'none'; frame-ancestors 'none'",
    'Permissions-Policy' => 'geolocation=(), camera=(), microphone=(), payment=()'
  )
end
