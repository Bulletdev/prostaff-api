# frozen_string_literal: true

# Implements the circuit breaker pattern to prevent cascade failures.
#
# The circuit has three states:
#   - closed  (normal): requests pass through; failures are counted
#   - open    (tripped): requests are rejected immediately; no upstream calls
#   - half-open (recovery): a limited number of probe requests are allowed
#
# State is stored in Redis via Sidekiq.redis so it is shared across all Puma
# workers and Sidekiq threads without adding another dependency.
#
# @example Wrap a Riot API call
#   CircuitBreakerService.call("riot_api") do
#     make_request(url)
#   end
#
# @example Handle an open circuit
#   begin
#     CircuitBreakerService.call("riot_api") { fetch_data }
#   rescue CircuitBreakerService::CircuitOpenError
#     render_error(message: "Service temporarily unavailable", ...)
#   end
class CircuitBreakerService
  FAILURE_THRESHOLD = ENV.fetch('CIRCUIT_BREAKER_THRESHOLD', 5).to_i
  RECOVERY_TIMEOUT  = 60
  HALF_OPEN_MAX     = 2

  CircuitOpenError = Class.new(StandardError)

  # @param service_name [String] unique name for this circuit (used as Redis key prefix)
  # @return [Object] return value of the block
  # @raise [CircuitOpenError] when the circuit is open
  def self.call(service_name, &)
    new(service_name).call(&)
  end

  def initialize(service_name)
    @service_name = service_name
    @key_failures = "circuit_breaker:#{service_name}:failures"
    @key_state    = "circuit_breaker:#{service_name}:state"
    @key_opened   = "circuit_breaker:#{service_name}:opened_at"
  end

  def call(&)
    case current_state
    when :open
      raise CircuitOpenError, "Circuit #{@service_name} is open"
    when :half_open
      attempt_recovery(&)
    else
      execute_with_tracking(&)
    end
  end

  private

  def current_state
    Sidekiq.redis do |redis|
      stored = redis.call('GET', @key_state)
      return :closed unless stored == 'open'

      opened_at = redis.call('GET', @key_opened).to_f
      return :open if Time.now.to_f - opened_at < RECOVERY_TIMEOUT

      :half_open
    end
  end

  def execute_with_tracking
    result = yield
    Sidekiq.redis { |r| r.call('DEL', @key_failures) }
    result
  rescue StandardError => e
    record_failure
    raise e
  end

  def attempt_recovery
    result = yield
    Sidekiq.redis do |r|
      r.call('DEL', @key_failures)
      r.call('DEL', @key_state)
    end
    Rails.logger.info("[CIRCUIT_BREAKER] Circuit #{@service_name} CLOSED after recovery")
    result
  rescue StandardError => e
    Sidekiq.redis do |r|
      r.call('SET', @key_state, 'open')
      r.call('SET', @key_opened, Time.now.to_f.to_s)
    end
    raise e
  end

  def record_failure
    failures = Sidekiq.redis { |r| r.call('INCR', @key_failures) }
    return unless failures >= FAILURE_THRESHOLD

    Sidekiq.redis do |r|
      r.call('SET', @key_state, 'open')
      r.call('SET', @key_opened, Time.now.to_f.to_s)
    end
    Rails.logger.warn("[CIRCUIT_BREAKER] Circuit #{@service_name} OPENED after #{failures} consecutive failures")
  end
end
