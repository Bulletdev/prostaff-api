# frozen_string_literal: true

# Query performance monitoring to catch slow queries
# Helps identify performance regressions early
module QueryPerformanceMonitoring
  SLOW_QUERY_THRESHOLD = ENV.fetch('SLOW_QUERY_THRESHOLD', 500).to_i # ms
  VERY_SLOW_QUERY_THRESHOLD = ENV.fetch('VERY_SLOW_QUERY_THRESHOLD', 1000).to_i # ms

  class << self
    def enable!
      return if @enabled

      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        duration = (finish - start) * 1000 # Convert to milliseconds

        next if should_ignore?(payload)

        if duration > VERY_SLOW_QUERY_THRESHOLD
          log_very_slow_query(payload, duration)
        elsif duration > SLOW_QUERY_THRESHOLD
          log_slow_query(payload, duration)
        end

        # Track query stats in Redis for analysis
        track_query_stats(payload, duration) if redis_available?
      end

      @enabled = true
      Rails.logger.info "✓ Query performance monitoring enabled (threshold: #{SLOW_QUERY_THRESHOLD}ms)"
    end

    private

    def should_ignore?(payload)
      # Ignore schema queries, EXPLAIN, and cache lookups
      return true if payload[:name] == 'SCHEMA'
      return true if payload[:name] == 'CACHE'
      return true if payload[:sql] =~ /^(BEGIN|COMMIT|ROLLBACK|SET|SHOW|EXPLAIN)/i

      false
    end

    def log_slow_query(payload, duration)
      Rails.logger.warn({
        message: 'Slow query detected',
        duration_ms: duration.round(2),
        query: sanitize_sql(payload[:sql]),
        name: payload[:name],
        binds: payload[:binds]&.map(&:value)
      }.to_json)
    end

    def log_very_slow_query(payload, duration)
      Rails.logger.error({
        message: 'VERY slow query detected',
        duration_ms: duration.round(2),
        query: sanitize_sql(payload[:sql]),
        name: payload[:name],
        binds: payload[:binds]&.map(&:value),
        backtrace: caller[0..5]
      }.to_json)

      # Send to monitoring service if configured
      report_to_monitoring_service(payload, duration) if monitoring_configured?
    end

    def track_query_stats(payload, duration)
      return unless redis_available?

      # Normalize query for grouping (remove values)
      normalized = normalize_query(payload[:sql])
      stats_key = "query_stats:#{Digest::MD5.hexdigest(normalized)}"

      # Update counters and query info
      Rails.cache.redis.pipelined do |pipeline|
        pipeline.hincrby(stats_key, 'count', 1)
        pipeline.hincrbyfloat(stats_key, 'total_time', duration)
        pipeline.hset(stats_key, 'query', normalized)
        pipeline.expire(stats_key, 24.hours.to_i)
      end

      # Update max_time separately (can't read inside pipeline)
      current_max = Rails.cache.redis.hget(stats_key, 'max_time').to_f
      Rails.cache.redis.hset(stats_key, 'max_time', duration) if duration > current_max
    rescue => e
      Rails.logger.debug "Failed to track query stats: #{e.message}"
    end

    def normalize_query(sql)
      sql
        .gsub(/\$\d+/, '$N') # Replace $1, $2 with $N
        .gsub(/'[^']*'/, "'?'") # Replace string literals
        .gsub(/\b\d+\b/, '?') # Replace numbers
        .gsub(/\s+/, ' ') # Normalize whitespace
        .strip
    end

    def sanitize_sql(sql)
      # Truncate very long queries
      sql.length > 500 ? "#{sql[0..500]}..." : sql
    end

    def redis_available?
      # Thread-safe check
      Thread.current[:qpm_redis_available] ||= begin
        Rails.cache.respond_to?(:redis) && Rails.cache.redis.ping == 'PONG'
      rescue
        false
      end
    end

    def monitoring_configured?
      # Add your monitoring service check here (e.g., Sentry, Honeybadger)
      false
    end

    def report_to_monitoring_service(payload, duration)
      # Implement reporting to your monitoring service
      # Example: Sentry.capture_message("Slow query: #{duration}ms", ...)
    end
  end
end

# Enable monitoring in production and staging
if Rails.env.production? || Rails.env.staging?
  Rails.application.config.after_initialize do
    QueryPerformanceMonitoring.enable!
  end
end

# Also enable in development if explicitly requested
if Rails.env.development? && ENV['ENABLE_QUERY_MONITORING'] == 'true'
  Rails.application.config.after_initialize do
    QueryPerformanceMonitoring.enable!
  end
end
