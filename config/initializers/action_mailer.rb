# frozen_string_literal: true

Rails.application.configure do
  config.action_mailer.delivery_method = ENV.fetch('MAILER_DELIVERY_METHOD', 'smtp').to_sym

  config.action_mailer.smtp_settings = {
    address:              ENV.fetch('SMTP_ADDRESS', 'smtp.gmail.com'),
    port:                 ENV.fetch('SMTP_PORT', 587).to_i,
    domain:               ENV.fetch('SMTP_DOMAIN', 'gmail.com'),
    user_name:            ENV['SMTP_USERNAME'],
    password:             ENV['SMTP_PASSWORD'],
    authentication:       ENV.fetch('SMTP_AUTHENTICATION', 'plain').to_sym,
    enable_starttls_auto: ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true'
  }

  config.action_mailer.default_url_options = {
    host: ENV.fetch('FRONTEND_URL', 'http://localhost:8888').gsub(%r{https?://}, ''),
    protocol: ENV.fetch('FRONTEND_URL', 'http://localhost:8888').start_with?('https') ? 'https' : 'http'
  }

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  config.action_mailer.deliver_later_queue_name = 'mailers'
end
