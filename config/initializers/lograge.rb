# frozen_string_literal: true

# Lograge — structured JSON logging (12-Factor XI)
# Replaces Rails' multi-line log format with a single JSON object per request.
# Output goes to stdout so the container runtime/orchestrator captures it.
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Include extra fields in every log line
  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:headers]&.[]('X-Request-Id'),
      user_agent: event.payload[:headers]&.[]('User-Agent'),
      remote_ip: event.payload[:headers]&.[]('REMOTE_ADDR'),
      params: event.payload[:params]
                   &.except('controller', 'action', 'format', '_method', 'authenticity_token')
    }.compact
  end
end
