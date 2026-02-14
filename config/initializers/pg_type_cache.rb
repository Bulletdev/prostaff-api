# frozen_string_literal: true

# Cache PostgreSQL type information to reduce 5,912 redundant queries
# Original issue: 13.8s total from repeated pg_type lookups
module PgTypeCache
  COMMON_TYPES = %w[
    uuid text varchar char bpchar
    int2 int4 int8 smallint integer bigint
    float4 float8 real double
    numeric decimal money
    bool boolean
    date time timetz timestamp timestamptz interval
    json jsonb
    bytea
    point line lseg box path polygon circle
    cidr inet macaddr macaddr8
    bit varbit
    tsvector tsquery
    xml
    pg_lsn
    int4range int8range numrange tsrange tstzrange daterange
  ].freeze

  class << self
    def preload!
      return unless enabled?

      Rails.logger.info "Preloading PostgreSQL type information..."

      types_data = fetch_types(COMMON_TYPES)
      store_in_cache(types_data)

      Rails.logger.info "✓ Cached #{types_data.size} PostgreSQL types"
    rescue => e
      Rails.logger.error "Failed to preload pg_types: #{e.message}"
    end

    def fetch_types(type_names)
      placeholders = type_names.each_with_index.map { |_, i| "$#{i + 1}" }.join(', ')

      sql = <<~SQL
        SELECT
          t.oid,
          t.typname,
          t.typelem,
          t.typdelim,
          t.typinput,
          r.rngsubtype,
          t.typtype,
          t.typbasetype,
          t.typsend,
          t.typreceive,
          t.typoutput
        FROM pg_type as t
        LEFT JOIN pg_range as r ON t.oid = r.rngtypid
        WHERE t.typname IN (#{placeholders})
      SQL

      ActiveRecord::Base.connection.exec_query(sql, 'SQL', type_names).to_a
    end

    def store_in_cache(types_data)
      return unless redis_available?

      types_data.each do |type|
        cache_key = "pg_type:#{type['typname']}"
        Rails.cache.write(cache_key, type, expires_in: 24.hours)
      end

      # Also store as batch for bulk lookups
      Rails.cache.write('pg_type:common_batch', types_data, expires_in: 24.hours)
    end

    def get_type(type_name)
      return nil unless redis_available?

      cache_key = "pg_type:#{type_name}"
      Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        fetch_types([type_name]).first
      end
    end

    def get_types(type_names)
      return fetch_types(type_names) unless redis_available?

      Rails.cache.fetch("pg_type:batch:#{type_names.sort.join(',')}", expires_in: 24.hours) do
        fetch_types(type_names)
      end
    end

    def invalidate_all!
      return unless redis_available?

      total_deleted = 0
      cursor = '0'

      # Use SCAN instead of KEYS to avoid blocking Redis
      loop do
        cursor, keys = Rails.cache.redis.scan(cursor, match: 'pg_type:*', count: 100)
        if keys.any?
          Rails.cache.redis.del(*keys)
          total_deleted += keys.size
        end
        break if cursor == '0'
      end

      Rails.logger.info "Invalidated #{total_deleted} pg_type cache entries"
    end

    private

    def enabled?
      redis_available? && ActiveRecord::Base.connection.active?
    end

    def redis_available?
      # Thread-safe check
      Thread.current[:pgtc_redis_available] ||= begin
        Rails.cache.respond_to?(:redis) && Rails.cache.redis.ping == 'PONG'
      rescue
        false
      end
    end
  end
end

# Preload types after Rails initialization
Rails.application.config.after_initialize do
  # Use concurrent-ruby if available for better thread management
  if defined?(Concurrent)
    Concurrent::ScheduledTask.execute(2) do
      PgTypeCache.preload!
    rescue => e
      Rails.logger.error "PgTypeCache preload error: #{e.message}"
    end
  else
    # Fallback to Thread with proper error handling
    thread = Thread.new do
      sleep 2 # Wait for connections to stabilize
      PgTypeCache.preload!
    rescue => e
      Rails.logger.error "PgTypeCache preload error: #{e.message}"
    end

    # Don't abort application on thread errors
    thread.abort_on_exception = false

    # Name the thread for debugging
    thread.name = 'pg_type_cache_preloader' if thread.respond_to?(:name=)
  end
end
