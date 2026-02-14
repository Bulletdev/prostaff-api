# frozen_string_literal: true

# Job to refresh database metadata materialized views periodically
# Keeps cached data fresh without impacting request performance
class RefreshMetadataViewsJob < ApplicationJob
  queue_as :low_priority

  LOCK_KEY = 'refresh_metadata_views:lock'
  LOCK_TTL = 30.minutes.to_i

  # Run every 30 minutes (configure in sidekiq.yml)
  def perform
    # Prevent concurrent execution using Redis distributed lock
    acquired = acquire_lock

    unless acquired
      Rails.logger.warn 'Refresh job already running, skipping this execution'
      return
    end

    begin
      Rails.logger.info 'Starting materialized views refresh...'

      start_time = Time.current

      # Refresh all metadata views concurrently
      ActiveRecord::Base.connection.execute('SELECT refresh_database_metadata_views();')

      duration = Time.current - start_time

      Rails.logger.info "Materialized views refreshed in #{duration.round(2)}s"

      # Also clear Redis caches to force fresh reads from materialized views
      DatabaseMetadataCacheService.invalidate_all! if defined?(DatabaseMetadataCacheService)
      PgTypeCache.invalidate_all! if defined?(PgTypeCache)

      duration
    ensure
      release_lock
    end
  rescue => e
    Rails.logger.error "Failed to refresh materialized views: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    release_lock
    raise
  end

  private

  def acquire_lock
    return true unless redis_available?

    # SET NX EX - Set if Not eXists with EXpiration
    result = Rails.cache.redis.set(LOCK_KEY, Time.current.to_i, nx: true, ex: LOCK_TTL)
    result == true || result == 'OK'
  rescue => e
    Rails.logger.warn "Failed to acquire lock: #{e.message}"
    false
  end

  def release_lock
    return unless redis_available?

    Rails.cache.redis.del(LOCK_KEY)
  rescue => e
    Rails.logger.warn "Failed to release lock: #{e.message}"
  end

  def redis_available?
    Rails.cache.respond_to?(:redis) && Rails.cache.redis.ping == 'PONG'
  rescue
    false
  end
end
