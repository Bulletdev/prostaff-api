# frozen_string_literal: true

module Middleware
  # Tracks 401 Unauthorized response rates and emits a structured critical log
  # alert when the ratio exceeds the configured threshold.
  #
  # This detects scenarios like JWT secret rotation without token blacklist flush,
  # which would cause a sudden spike in 401 responses across all users.
  #
  # Algorithm: sliding window using per-minute Redis counters.
  #   - prostaff:auth_tracker:req:{minute}  → total requests in that minute
  #   - prostaff:auth_tracker:401:{minute}  → 401 responses in that minute
  #   - Both keys expire after WINDOW_MINUTES + 1 minutes to avoid stale data.
  #
  # The tracker only fires the alert once per ALERT_COOLDOWN_SECONDS to avoid
  # log flooding during a sustained incident.
  #
  # Graceful degradation: if Redis is unavailable the middleware is transparent —
  # it logs a warning and lets the request pass through unaffected.
  #
  # @example Configuring thresholds via environment variables
  #   AUTH_TRACKER_THRESHOLD=0.05    # 5% of requests returning 401 triggers alert
  #   AUTH_TRACKER_WINDOW=5          # sliding window in minutes
  class AuthFailureTracker
    NAMESPACE             = 'prostaff:auth_tracker'
    DEFAULT_THRESHOLD     = 0.05  # 5% of requests
    DEFAULT_WINDOW        = 5     # minutes
    ALERT_COOLDOWN        = 300   # seconds (5 min) between repeated alerts
    SKIP_PATHS            = %w[/health /health/live /health/ready /up].freeze

    def initialize(app)
      @app       = app
      @threshold = ENV.fetch('AUTH_TRACKER_THRESHOLD', DEFAULT_THRESHOLD).to_f
      @window    = ENV.fetch('AUTH_TRACKER_WINDOW', DEFAULT_WINDOW).to_i
    end

    def call(env)
      status, headers, body = @app.call(env)

      path = env['PATH_INFO'].to_s
      track(status, path) unless skip_tracking?(path)

      [status, headers, body]
    end

    private

    def skip_tracking?(path)
      SKIP_PATHS.any? { |p| path.start_with?(p) }
    end

    def track(status, path)
      minute_key = Time.current.strftime('%Y%m%d%H%M')
      ttl        = (@window + 1) * 60

      with_redis do |redis|
        redis.call('MULTI')

        redis.call('INCR', "#{NAMESPACE}:req:#{minute_key}")
        redis.call('EXPIRE', "#{NAMESPACE}:req:#{minute_key}", ttl)

        if status == 401
          redis.call('INCR', "#{NAMESPACE}:401:#{minute_key}")
          redis.call('EXPIRE', "#{NAMESPACE}:401:#{minute_key}", ttl)
        end

        redis.call('EXEC')

        check_spike(redis, path) if status == 401
      end
    end

    def check_spike(redis, path)
      total_reqs = sum_window(redis, 'req')
      total_401s = sum_window(redis, '401')

      return if total_reqs < 20

      rate = total_401s.to_f / total_reqs

      return unless rate >= @threshold
      return if alert_on_cooldown?(redis)

      record_alert_cooldown(redis)
      emit_spike_alert(rate, total_reqs, total_401s, path)
    end

    def emit_spike_alert(rate, total_reqs, total_401s, path)
      Rails.logger.error(
        event: 'auth_spike_detected',
        level: 'CRITICAL',
        message: '401 rate spike detected — possible JWT rotation or token invalidation issue',
        rate_pct: (rate * 100).round(2),
        threshold_pct: (@threshold * 100).round(2),
        window_minutes: @window,
        total_requests: total_reqs,
        total_401s: total_401s,
        last_path: path
      )
    end

    def sum_window(redis, bucket)
      keys = (@window - 1).downto(0).map do |i|
        minute_key = (Time.current - i.minutes).strftime('%Y%m%d%H%M')
        "#{NAMESPACE}:#{bucket}:#{minute_key}"
      end

      counts = keys.map { |k| redis.call('GET', k).to_i }
      counts.sum
    end

    def alert_on_cooldown?(redis)
      redis.call('EXISTS', "#{NAMESPACE}:alert_sent") == 1
    end

    def record_alert_cooldown(redis)
      redis.call('SET', "#{NAMESPACE}:alert_sent", '1', 'EX', ALERT_COOLDOWN)
    end

    def with_redis
      redis_url = ENV['REDIS_URL']
      return unless redis_url.present?

      client = RedisClient.new(url: redis_url, timeout: 1.0)
      yield client
      client.close
    rescue StandardError => e
      Rails.logger.warn "[AuthFailureTracker] Redis unavailable, skipping tracking: #{e.message}"
    end
  end
end
