# frozen_string_literal: true

# Provides application health check endpoints for container orchestration and monitoring.
#
# Endpoint design (from FAILURE_MODE_ANALYSIS.md):
#   GET /health/live  — liveness probe: is the process alive?
#                       Never checks dependencies — a Redis failure must NOT restart the container.
#   GET /health/ready — readiness probe: can the app handle traffic?
#                       Checks PostgreSQL, Redis, and Meilisearch.
#   GET /health/detailed — legacy alias kept for backwards compatibility.
#   GET /health       — static JSON handled inline in routes.rb (no DB hit).
#
# WARNING: Do NOT add dependency checks to /health/live.
# If Redis is down and the liveness probe fails, the orchestrator will restart
# the container, causing a reconnect storm that worsens the incident.
class HealthController < ActionController::API
  skip_before_action :verify_authenticity_token, raise: false

  # GET /health/live
  #
  # Liveness probe — answers: "is the process alive and able to serve requests?"
  # Must return 200 as long as Puma is running, regardless of dependency state.
  # Used by Coolify/Kubernetes restart policy.
  #
  # @return [JSON] 200 always while process is alive
  def live
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      service: 'ProStaff API'
    }, status: :ok
  end

  # GET /health/ready
  #
  # Readiness probe — answers: "should traffic be routed to this instance?"
  # Checks all critical dependencies. Returns 503 if any dependency is unavailable
  # so the load balancer can remove the instance from the pool.
  #
  # @return [JSON] 200 when all dependencies are healthy, 503 when degraded
  def ready
    checks = {
      database: check_database,
      redis: check_redis,
      meilisearch: check_meilisearch
    }

    # 'disabled' means the service is not configured (expected in some environments).
    # Only 'error' status means the service is configured but unreachable.
    all_healthy = checks.values.all? { |c| %w[ok disabled].include?(c[:status]) }
    http_status = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? 'ok' : 'degraded',
      timestamp: Time.current.iso8601,
      service: 'ProStaff API',
      checks: checks
    }, status: http_status
  end

  # GET /health/detailed
  #
  # Legacy endpoint — kept for backwards compatibility with existing monitoring.
  # Delegates to #ready for full dependency check.
  #
  # @return [JSON] same format as #ready
  def show
    ready
  end

  private

  # Executes a minimal query against PostgreSQL to confirm the connection is alive.
  #
  # @return [Hash] { status: 'ok'|'error', message: String }
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok' }
  rescue StandardError => e
    Rails.logger.error "[HealthCheck] Database check failed: #{e.message}"
    { status: 'error', message: e.message }
  end

  # PINGs Redis to confirm the connection is alive.
  # Uses a dedicated short-lived connection to avoid polluting connection pools.
  #
  # @return [Hash] { status: 'ok'|'disabled'|'error', message: String }
  def check_redis
    redis_url = ENV['REDIS_URL']

    return { status: 'disabled', message: 'REDIS_URL not configured' } unless redis_url.present?

    client = RedisClient.new(url: redis_url, timeout: 2.0)
    client.call('PING')
    client.close
    { status: 'ok' }
  rescue StandardError => e
    Rails.logger.error "[HealthCheck] Redis check failed: #{e.message}"
    { status: 'error', message: e.message }
  end

  # Calls Meilisearch /health to confirm the search service is reachable.
  # Non-critical: if Meilisearch is disabled (no URL), reports as disabled rather than error.
  #
  # @return [Hash] { status: 'ok'|'disabled'|'error', message: String }
  def check_meilisearch
    return { status: 'disabled', message: 'MEILISEARCH_URL not configured' } unless ENV['MEILISEARCH_URL'].present?

    client = defined?(MEILISEARCH_CLIENT) ? MEILISEARCH_CLIENT : nil
    return { status: 'disabled', message: 'Meilisearch client not initialized' } unless client

    client.health
    { status: 'ok' }
  rescue StandardError => e
    Rails.logger.error "[HealthCheck] Meilisearch check failed: #{e.message}"
    { status: 'error', message: e.message }
  end
end
