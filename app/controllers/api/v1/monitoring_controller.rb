# frozen_string_literal: true

module Api
  module V1
    # Exposes internal observability metrics for admin users and external monitoring tools.
    #
    # All endpoints require admin role. Intended for use by:
    #   - UptimeRobot / BetterUptime alert rules (via authenticated requests)
    #   - Internal dashboards
    #   - On-call incident response
    #
    # Gap coverage (FAILURE_MODE_ANALYSIS.md):
    #   Gap 1  — Sidekiq queue depth alert
    #   Gap 2  — Scheduled job heartbeat monitoring (stale job detection)
    #   Gap 4  — Dead queue monitoring
    #
    # @example Check Sidekiq health
    #   GET /api/v1/monitoring/sidekiq
    #   Authorization: Bearer <admin_token>
    class MonitoringController < BaseController
      before_action :require_admin!

      QUEUE_DEPTH_ALERT_THRESHOLD = ENV.fetch('SIDEKIQ_QUEUE_ALERT_THRESHOLD', 100).to_i
      DEAD_QUEUE_ALERT_THRESHOLD  = ENV.fetch('SIDEKIQ_DEAD_ALERT_THRESHOLD', 10).to_i

      # Scheduled jobs to monitor. Each entry defines the job class name,
      # expected run interval, and the threshold after which it is considered stale.
      # Names must match self.class.name inside each job (after Zeitwerk namespace
      # resolution) because record_job_heartbeat uses "prostaff:job_heartbeat:#{name}".
      SCHEDULED_JOBS = [
        { name: 'Analytics::RefreshMetadataViewsJob', interval_hours: 2, alert_after_hours: 3 },
        { name: 'Authentication::CleanupExpiredTokensJob', interval_hours: 24, alert_after_hours: 25 }
      ].freeze

      # GET /api/v1/monitoring/cache_stats
      #
      # Returns Redis-backed cache hit rate counters incremented by the
      # cache_instrumentation initializer on every cache read.
      #
      # @return [JSON] { reads, hits, misses, hit_rate }
      def cache_stats
        redis  = Rails.cache.redis
        reads  = redis.call('GET', 'metrics:cache:reads').to_i
        hits   = redis.call('GET', 'metrics:cache:hits').to_i
        misses = redis.call('GET', 'metrics:cache:misses').to_i
        rate   = reads.positive? ? (hits.to_f / reads * 100).round(2) : 0.0

        render json: {
          reads: reads,
          hits: hits,
          misses: misses,
          hit_rate: "#{rate}%",
          timestamp: Time.current.iso8601
        }
      rescue StandardError => e
        Rails.logger.error("[CACHE] Failed to read cache stats: #{e.message}")
        render json: { error: 'Cache stats unavailable' }, status: :service_unavailable
      end

      # GET /api/v1/monitoring/sidekiq
      #
      # Returns a snapshot of Sidekiq operational state including queue depths,
      # process count, scheduled and dead job counts, and heartbeat status of
      # cron jobs (gap 2 — detects if a scheduled job has not run in its window).
      #
      # Healthy thresholds (logged as alerts when exceeded):
      #   - queue_depth > 100 jobs  → Sidekiq may be down
      #   - dead_count   > 10 jobs  → jobs are failing silently
      #   - job stale               → scheduled job has not run within expected interval
      #
      # @return [JSON] Sidekiq stats with health indicators
      def sidekiq
        unless sidekiq_available?
          render json: {
            status: 'unavailable',
            message: 'Sidekiq is not configured (Redis unavailable)',
            timestamp: Time.current.iso8601
          }, status: :service_unavailable
          return
        end

        stats     = Sidekiq::Stats.new
        processes = Sidekiq::ProcessSet.new.to_a

        queue_depths   = build_queue_depths
        total_depth    = queue_depths.values.sum
        dead_count     = stats.dead_size
        job_heartbeats = build_job_heartbeats
        any_stale      = job_heartbeats.values.any? { |j| j[:stale] }

        health_status = determine_health(total_depth, dead_count, processes.size, any_stale: any_stale)
        emit_alerts(total_depth, dead_count, processes.size)
        emit_stale_job_alerts(job_heartbeats)

        render json: {
          status: health_status,
          timestamp: Time.current.iso8601,
          processes: {
            count: processes.size,
            workers: processes.map do |p|
              { hostname: p['hostname'], pid: p['pid'], concurrency: p['concurrency'], busy: p['busy'] }
            end
          },
          queues: queue_depths,
          stats: {
            enqueued: stats.enqueued,
            processed: stats.processed,
            failed: stats.failed,
            scheduled: stats.scheduled_size,
            retry: stats.retry_size,
            dead: dead_count
          },
          scheduled_jobs: job_heartbeats,
          alerts: {
            queue_depth_threshold: QUEUE_DEPTH_ALERT_THRESHOLD,
            dead_queue_threshold: DEAD_QUEUE_ALERT_THRESHOLD,
            queue_depth_exceeded: total_depth > QUEUE_DEPTH_ALERT_THRESHOLD,
            dead_queue_exceeded: dead_count > DEAD_QUEUE_ALERT_THRESHOLD,
            no_workers: processes.empty?,
            stale_jobs: any_stale
          }
        }, status: health_status == 'ok' ? :ok : :service_unavailable
      end

      private

      def require_admin!
        render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.admin?
      end

      def sidekiq_available?
        defined?(Sidekiq::Stats)
      rescue StandardError
        false
      end

      def build_queue_depths
        Sidekiq::Queue.all.each_with_object({}) do |queue, hash|
          hash[queue.name] = queue.size
        end
      end

      # Reads last-run timestamps from Redis for each scheduled job and returns
      # a hash with staleness status. Jobs that have never run return stale: true.
      def build_job_heartbeats
        Sidekiq.redis do |redis|
          SCHEDULED_JOBS.each_with_object({}) do |config, hash|
            hash[config[:name]] = build_heartbeat_entry(redis, config)
          end
        end
      rescue StandardError => e
        Rails.logger.warn(event: 'monitoring_heartbeat_read_error', error: e.message)
        {}
      end

      def build_heartbeat_entry(redis, config)
        raw = redis.call('GET', "prostaff:job_heartbeat:#{config[:name]}")
        last_run = raw ? Time.zone.parse(raw) : nil
        stale = last_run.nil? || last_run < config[:alert_after_hours].hours.ago

        {
          last_run_at: last_run&.iso8601,
          expected_interval_hours: config[:interval_hours],
          alert_after_hours: config[:alert_after_hours],
          stale: stale
        }
      end

      def determine_health(total_depth, dead_count, process_count, any_stale: false)
        return 'critical' if process_count.zero?
        return 'degraded' if dead_count > DEAD_QUEUE_ALERT_THRESHOLD
        return 'degraded' if total_depth > QUEUE_DEPTH_ALERT_THRESHOLD
        return 'degraded' if any_stale

        'ok'
      end

      def emit_alerts(total_depth, dead_count, process_count)
        if process_count.zero?
          Rails.logger.error(
            event: 'sidekiq_no_workers',
            level: 'CRITICAL',
            message: 'No Sidekiq workers running — background jobs are not being processed'
          )
        end

        if total_depth > QUEUE_DEPTH_ALERT_THRESHOLD
          Rails.logger.error(
            event: 'sidekiq_queue_depth_exceeded',
            level: 'ALERT',
            message: 'Sidekiq queue depth exceeded threshold',
            total_enqueued: total_depth,
            threshold: QUEUE_DEPTH_ALERT_THRESHOLD
          )
        end

        return unless dead_count > DEAD_QUEUE_ALERT_THRESHOLD

        Rails.logger.error(
          event: 'sidekiq_dead_queue_exceeded',
          level: 'ALERT',
          message: 'Sidekiq dead queue exceeded threshold — jobs are failing permanently',
          dead_count: dead_count,
          threshold: DEAD_QUEUE_ALERT_THRESHOLD
        )
      end

      def emit_stale_job_alerts(heartbeats)
        heartbeats.each do |job_name, data|
          next unless data[:stale]

          Rails.logger.error(
            event: 'scheduled_job_stale',
            level: 'ALERT',
            message: 'Scheduled job has not run within expected interval',
            job: job_name,
            last_run_at: data[:last_run_at],
            alert_after_hours: data[:alert_after_hours]
          )
        end
      end
    end
  end
end
