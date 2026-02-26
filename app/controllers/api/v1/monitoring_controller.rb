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
    #   Gap 4  — Dead queue monitoring
    #
    # @example Check Sidekiq health
    #   GET /api/v1/monitoring/sidekiq
    #   Authorization: Bearer <admin_token>
    class MonitoringController < BaseController
      before_action :require_admin!

      QUEUE_DEPTH_ALERT_THRESHOLD = ENV.fetch('SIDEKIQ_QUEUE_ALERT_THRESHOLD', 100).to_i
      DEAD_QUEUE_ALERT_THRESHOLD  = ENV.fetch('SIDEKIQ_DEAD_ALERT_THRESHOLD', 10).to_i

      # GET /api/v1/monitoring/sidekiq
      #
      # Returns a snapshot of Sidekiq operational state including queue depths,
      # process count, scheduled and dead job counts.
      #
      # Healthy thresholds (logged as alerts when exceeded):
      #   - queue_depth > 100 jobs for more than 5 min → Sidekiq may be down
      #   - dead_count   > 10 jobs                      → jobs are failing silently
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

        queue_depths  = build_queue_depths
        total_depth   = queue_depths.values.sum
        dead_count    = stats.dead_size

        health_status = determine_health(total_depth, dead_count, processes.size)
        emit_alerts(total_depth, dead_count, processes.size)

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
          alerts: {
            queue_depth_threshold: QUEUE_DEPTH_ALERT_THRESHOLD,
            dead_queue_threshold: DEAD_QUEUE_ALERT_THRESHOLD,
            queue_depth_exceeded: total_depth > QUEUE_DEPTH_ALERT_THRESHOLD,
            dead_queue_exceeded: dead_count > DEAD_QUEUE_ALERT_THRESHOLD,
            no_workers: processes.empty?
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

      def determine_health(total_depth, dead_count, process_count)
        return 'critical' if process_count.zero?
        return 'degraded' if dead_count > DEAD_QUEUE_ALERT_THRESHOLD
        return 'degraded' if total_depth > QUEUE_DEPTH_ALERT_THRESHOLD

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
    end
  end
end
