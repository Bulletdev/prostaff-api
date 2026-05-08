# frozen_string_literal: true

module Analytics
  # Refreshes PostgreSQL materialized views for database metadata periodically.
  #
  # Scheduled every 2 hours via sidekiq.yml. Uses a distributed Redis lock to
  # prevent concurrent runs. Emits structured log fields so monitoring tools
  # can alert if the job stops executing (gap 2 from FAILURE_MODE_ANALYSIS.md).
  #
  # @example Trigger manually via Rails console
  #   Analytics::RefreshMetadataViewsJob.perform_now
  class RefreshMetadataViewsJob < ApplicationJob
    queue_as :low_priority

    LOCK_KEY = 'refresh_metadata_views:lock'
    LOCK_TTL = 30.minutes.to_i

    def perform
      start_time = Time.current

      Rails.logger.info(
        event: 'job_started',
        job: self.class.name,
        queue: queue_name.to_s
      )

      acquired = acquire_lock

      unless acquired
        Rails.logger.warn(
          event: 'job_skipped',
          job: self.class.name,
          reason: 'lock_already_held'
        )
        return
      end

      begin
        refresh_views
        invalidate_caches

        duration_ms = ((Time.current - start_time) * 1000).round

        Rails.logger.info(
          event: 'job_completed',
          job: self.class.name,
          status: 'success',
          duration_ms: duration_ms
        )

        record_job_heartbeat
        duration_ms
      ensure
        release_lock
      end
    rescue StandardError => e
      duration_ms = ((Time.current - start_time) * 1000).round

      Rails.logger.error(
        event: 'job_failed',
        job: self.class.name,
        status: 'error',
        duration_ms: duration_ms,
        error_class: e.class.to_s,
        error: e.message
      )

      release_lock
      raise
    end

    private

    def refresh_views
      ActiveRecord::Base.connection.execute('SELECT refresh_database_metadata_views();')
    end

    def invalidate_caches
      DatabaseMetadataCacheService.invalidate_all! if defined?(DatabaseMetadataCacheService)
      PgTypeCache.invalidate_all! if defined?(PgTypeCache)
    end

    def acquire_lock
      return true unless redis_available?

      result = Rails.cache.redis.set(LOCK_KEY, Time.current.to_i, nx: true, ex: LOCK_TTL)
      [true, 'OK'].include?(result)
    rescue StandardError => e
      Rails.logger.warn "Failed to acquire lock: #{e.message}"
      false
    end

    def release_lock
      return unless redis_available?

      Rails.cache.redis.del(LOCK_KEY)
    rescue StandardError => e
      Rails.logger.warn "Failed to release lock: #{e.message}"
    end

    def redis_available?
      Rails.cache.respond_to?(:redis) && Rails.cache.redis.ping == 'PONG'
    rescue StandardError
      false
    end
  end
end
