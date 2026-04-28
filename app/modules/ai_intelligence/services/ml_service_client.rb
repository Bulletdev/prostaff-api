# frozen_string_literal: true

# Shared HTTP client for all calls to the ProStaff ML service (FastAPI).
#
# Responsibilities:
#   - Single Faraday connection pointed at AI_SERVICE_URL
#   - Kill switch: ML_SERVICE_ENABLED=false raises MlServiceDisabledError immediately
#   - Lightweight circuit breaker backed by Redis (via Sidekiq.redis — no extra gem):
#       "ml_circuit:failures"   — INCR counter with TTL, resets on success
#       "ml_circuit:open_until" — Unix timestamp; while Time.now < value, circuit is open
#
# Circuit breaker behaviour:
#   - Open check:  if open_until > now  → raise MlCircuitOpenError (fast fail, no network call)
#   - On success:  DEL failures key
#   - On network error (timeout / connection failed): INCR failures (TTL 60s)
#       If failures >= ML_CIRCUIT_BREAK_THRESHOLD → SET open_until = now + ML_CIRCUIT_BREAK_RESET_SECONDS
#
# ENV vars:
#   AI_SERVICE_URL                 (default: 'http://localhost:8001')
#   ML_SERVICE_ENABLED             (default: 'true')   — set to 'false' to kill-switch
#   ML_SERVICE_TIMEOUT             (default: '5')       — seconds for .post() callers that omit timeout:
#   ML_CIRCUIT_BREAK_THRESHOLD     (default: '3')       — consecutive failures before opening
#   ML_CIRCUIT_BREAK_RESET_SECONDS (default: '120')     — seconds the circuit stays open
#
# Usage:
#   MlServiceClient.post('/recommend', payload, timeout: 5)
#   # => parsed Hash (symbolized keys) or raises one of the errors below
#
# Errors (all subclass StandardError):
#   MlServiceClient::MlServiceDisabledError  — kill switch is active
#   MlServiceClient::MlCircuitOpenError      — circuit is open, request not attempted
#   MlServiceClient::MlServiceError          — upstream returned non-2xx or bad JSON
module MlServiceClient
  # ── Error hierarchy ────────────────────────────────────────────────────────
  MlServiceDisabledError = Class.new(StandardError)
  MlCircuitOpenError     = Class.new(StandardError)
  MlServiceError         = Class.new(StandardError)

  # ── Redis keys ─────────────────────────────────────────────────────────────
  CIRCUIT_FAILURES_KEY   = 'ml_circuit:failures'
  CIRCUIT_OPEN_UNTIL_KEY = 'ml_circuit:open_until'
  CIRCUIT_FAILURES_TTL   = 60 # seconds — window for counting consecutive failures

  # ── ENV helpers (read fresh each call so the values can change at runtime) ─
  def self.base_url
    ENV.fetch('AI_SERVICE_URL', 'http://localhost:8001')
  end

  def self.service_enabled?
    ENV.fetch('ML_SERVICE_ENABLED', 'true') != 'false'
  end

  def self.circuit_threshold
    ENV.fetch('ML_CIRCUIT_BREAK_THRESHOLD', '3').to_i
  end

  def self.circuit_reset_seconds
    ENV.fetch('ML_CIRCUIT_BREAK_RESET_SECONDS', '120').to_i
  end

  # ── Public interface ────────────────────────────────────────────────────────

  # POST to the ML service.
  #
  # @param path    [String]  e.g. '/recommend'
  # @param payload [Hash]    request body (will be JSON-encoded)
  # @param timeout [Integer] per-request timeout in seconds
  # @return [Hash] parsed response body (symbolized keys)
  # @raise [MlServiceDisabledError, MlCircuitOpenError, MlServiceError]
  def self.post(path, payload, timeout: ENV.fetch('ML_SERVICE_TIMEOUT', '5').to_i)
    raise MlServiceDisabledError, 'ML service is disabled (ML_SERVICE_ENABLED=false)' unless service_enabled?

    check_circuit!

    begin
      response = connection(timeout: timeout).post(path) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = payload.to_json
      end

      unless response.success?
        raise MlServiceError, "ML service returned HTTP #{response.status} from #{path}"
      end

      result = JSON.parse(response.body, symbolize_names: true)
      record_success
      result

    rescue Faraday::TimeoutError => e
      record_failure
      raise MlServiceError, "timeout calling #{path}: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      record_failure
      raise MlServiceError, "connection failed calling #{path}: #{e.message}"
    rescue Faraday::Error => e
      record_failure
      raise MlServiceError, "network error calling #{path}: #{e.message}"
    rescue JSON::ParserError => e
      raise MlServiceError, "invalid JSON response from #{path}: #{e.message}"
    end
  end

  # ── Circuit breaker helpers ─────────────────────────────────────────────────

  # Raises MlCircuitOpenError when the circuit is open.
  def self.check_circuit!
    open_until = Sidekiq.redis { |r| r.call('GET', CIRCUIT_OPEN_UNTIL_KEY).to_i }
    return unless open_until > Time.now.to_i

    remaining = open_until - Time.now.to_i
    raise MlCircuitOpenError, "ML circuit breaker is open for #{remaining}s more"
  end

  def self.record_success
    Sidekiq.redis { |r| r.call('DEL', CIRCUIT_FAILURES_KEY) }
  end

  def self.record_failure
    failures = Sidekiq.redis do |r|
      count = r.call('INCR', CIRCUIT_FAILURES_KEY)
      # Reset TTL on every increment so the window is sliding
      r.call('EXPIRE', CIRCUIT_FAILURES_KEY, CIRCUIT_FAILURES_TTL)
      count
    end

    return unless failures >= circuit_threshold

    reset = circuit_reset_seconds
    Sidekiq.redis do |r|
      r.call('SET', CIRCUIT_OPEN_UNTIL_KEY, (Time.now.to_i + reset).to_s)
    end
    Rails.logger.warn(
      "[MlServiceClient] Circuit breaker OPEN after #{failures} consecutive failures — " \
      "will reset in #{reset}s"
    )
  end

  # ── Faraday connection ──────────────────────────────────────────────────────

  def self.connection(timeout:)
    Faraday.new(url: base_url) do |f|
      f.options.timeout      = timeout
      f.options.open_timeout = timeout
      f.adapter Faraday.default_adapter
    end
  end

  private_class_method :check_circuit!, :record_success, :record_failure, :connection
end
