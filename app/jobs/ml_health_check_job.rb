# frozen_string_literal: true

# Periodically checks the health of the ML service and logs circuit breaker status.
#
# This job uses a direct Faraday GET (not MlServiceClient) because /health is a
# read-only probe that must bypass the circuit breaker — it is how we decide when
# to reset it manually or alert on degraded ML availability.
#
# Scheduled at low priority so it never competes with critical path jobs.
# Configure frequency in config/sidekiq.yml or sidekiq-scheduler config.
#
# ENV vars read:
#   AI_SERVICE_URL — base URL of the ML FastAPI service (default: http://localhost:8001)
class MlHealthCheckJob < ApplicationJob
  queue_as :low_priority
  sidekiq_options retry: 0 # health checks are best-effort; no retry noise

  ML_HEALTH_TIMEOUT = 2 # seconds

  def perform
    check_service_health
    log_circuit_status
  rescue StandardError => e
    Rails.logger.warn("[MlHealthCheckJob] Unexpected error during health check: #{e.message}")
  end

  private

  def check_service_health
    conn = Faraday.new(url: ENV.fetch('AI_SERVICE_URL', 'http://localhost:8001')) do |f|
      f.options.timeout      = ML_HEALTH_TIMEOUT
      f.options.open_timeout = ML_HEALTH_TIMEOUT
      f.adapter Faraday.default_adapter
    end

    resp = conn.get('/health')
    body = JSON.parse(resp.body)

    unless resp.success?
      Rails.logger.warn("[MlHealthCheckJob] ML /health returned HTTP #{resp.status}")
      return
    end

    if body['model_loaded'] == false
      Rails.logger.warn("[MlHealthCheckJob] ML service health: model_loaded=false")
    else
      Rails.logger.info("[MlHealthCheckJob] ML service healthy (model_loaded=#{body['model_loaded']})")
    end
  rescue Faraday::TimeoutError
    Rails.logger.warn('[MlHealthCheckJob] ML /health timed out')
  rescue Faraday::ConnectionFailed => e
    Rails.logger.warn("[MlHealthCheckJob] ML /health connection failed: #{e.message}")
  rescue JSON::ParserError => e
    Rails.logger.warn("[MlHealthCheckJob] ML /health returned invalid JSON: #{e.message}")
  end

  def log_circuit_status
    open_until = Sidekiq.redis { |r| r.call('GET', MlServiceClient::CIRCUIT_OPEN_UNTIL_KEY).to_i }

    if open_until > Time.now.to_i
      remaining = open_until - Time.now.to_i
      Rails.logger.warn("[MlHealthCheckJob] ML circuit breaker is OPEN — resets in #{remaining}s")
    else
      failures = Sidekiq.redis { |r| r.call('GET', MlServiceClient::CIRCUIT_FAILURES_KEY).to_i }
      if failures.positive?
        Rails.logger.info("[MlHealthCheckJob] ML circuit CLOSED with #{failures} recent failure(s) recorded")
      end
    end
  rescue StandardError => e
    Rails.logger.warn("[MlHealthCheckJob] Could not read circuit breaker state from Redis: #{e.message}")
  end
end
