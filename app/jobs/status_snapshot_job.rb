# frozen_string_literal: true

require 'sidekiq/api'

# Records a health snapshot for every infrastructure component every 5 minutes.
# Results are persisted in status_snapshots and consumed by the public status page.
class StatusSnapshotJob < ApplicationJob
  queue_as :default

  RIOT_HEARTBEAT_PATTERN = 'prostaff:job_heartbeat:*Riot*'
  RIOT_STALENESS_HOURS   = 25

  def perform
    checked_at = Time.current

    StatusIncident::COMPONENTS.each do |component|
      result = check_component(component)
      StatusSnapshot.create!(
        component: component,
        status: result[:status],
        response_time_ms: result[:response_time_ms],
        checked_at: checked_at
      )
    rescue StandardError => e
      Rails.logger.error("[STATUS] Failed to record snapshot for #{component}: #{e.message}")
    end

    record_job_heartbeat
  rescue StandardError => e
    Rails.logger.error("[STATUS] StatusSnapshotJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  private

  def check_component(component)
    send(:"check_#{component}")
  end

  def check_api
    ms = measure { ApplicationRecord.connection.execute('SELECT 1') }
    { status: 'operational', response_time_ms: ms }
  rescue StandardError
    { status: 'operational', response_time_ms: nil }
  end

  def check_database
    ms = measure { ApplicationRecord.connection.execute('SELECT 1') }
    { status: 'operational', response_time_ms: ms }
  rescue StandardError => e
    Rails.logger.error("[STATUS] Database check failed: #{e.message}")
    { status: 'major_outage', response_time_ms: nil }
  end

  def check_redis
    ms = measure do
      Sidekiq.redis(&:ping)
    end
    { status: 'operational', response_time_ms: ms }
  rescue StandardError => e
    Rails.logger.error("[STATUS] Redis check failed: #{e.message}")
    { status: 'major_outage', response_time_ms: nil }
  end

  def check_websocket
    cable_config = ActionCable.server.config.cable
    adapter = cable_config&.fetch('adapter', nil) || cable_config&.fetch(:adapter, nil)

    if adapter&.include?('redis')
      redis_result = check_redis
      return { status: redis_result[:status], response_time_ms: nil }
    end

    { status: 'operational', response_time_ms: nil }
  rescue StandardError => e
    Rails.logger.error("[STATUS] WebSocket check failed: #{e.message}")
    { status: 'major_outage', response_time_ms: nil }
  end

  def check_sidekiq
    stats = Sidekiq::Stats.new
    queues = Sidekiq::Queue.all.map(&:latency)
    max_latency = queues.max || 0

    status = if stats.dead_size > 50
               'major_outage'
             elsif max_latency > 300
               'degraded_performance'
             else
               'operational'
             end

    { status: status, response_time_ms: nil }
  rescue StandardError => e
    Rails.logger.error("[STATUS] Sidekiq check failed: #{e.message}")
    { status: 'major_outage', response_time_ms: nil }
  end

  def check_riot_api
    status = Sidekiq.redis do |redis|
      keys = scan_keys(redis, RIOT_HEARTBEAT_PATTERN)
      recent = keys.any? do |key|
        raw = redis.call('GET', key)
        next false unless raw

        last_run = Time.zone.parse(raw)
        last_run > RIOT_STALENESS_HOURS.hours.ago
      end
      recent ? 'operational' : 'degraded_performance'
    end

    { status: status, response_time_ms: nil }
  rescue StandardError => e
    Rails.logger.error("[STATUS] Riot API heartbeat check failed: #{e.message}")
    { status: 'degraded_performance', response_time_ms: nil }
  end

  # Uses SCAN instead of KEYS to avoid blocking Redis under load.
  def scan_keys(redis, pattern)
    keys   = []
    cursor = '0'
    loop do
      cursor, batch = redis.call('SCAN', cursor, 'MATCH', pattern, 'COUNT', '100')
      keys.concat(batch)
      break if cursor == '0'
    end
    keys
  end

  def measure
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
  end
end
