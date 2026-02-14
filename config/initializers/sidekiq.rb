# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-scheduler'

# Gracefully handle Redis unavailability
def configure_sidekiq_with_retry
  return false unless ENV['REDIS_URL'].present?

  # Test Redis connection before configuring Sidekiq
  begin
    redis_url = ENV['REDIS_URL']
    Rails.logger.info "Testing Redis connection: #{redis_url.gsub(/:[^:@]+@/, ':***@')}"

    # Quick connection test with timeout
    redis_client = RedisClient.new(url: redis_url, timeout: 2.0)
    redis_client.call('PING')
    redis_client.close

    Rails.logger.info "✓ Redis connection successful"
    true
  rescue => e
    Rails.logger.error "✗ Redis connection failed: #{e.class} - #{e.message}"
    Rails.logger.error "  Sidekiq and background jobs will be disabled"
    Rails.logger.error "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
    false
  end
end

# Only configure Sidekiq if Redis is actually reachable
if configure_sidekiq_with_retry
  Sidekiq.configure_server do |config|
    config.redis = {
      url: ENV['REDIS_URL'],
      network_timeout: 5,
      pool_timeout: 5
    }

    config.on(:startup) do
      schedule_file = Rails.root.join('config', 'sidekiq.yml')
      if File.exist?(schedule_file)
        schedule = YAML.load_file(schedule_file)
        if schedule && schedule[:schedule]
          Sidekiq.schedule = schedule[:schedule]
          SidekiqScheduler::Scheduler.instance.reload_schedule!
        end
      end
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = {
      url: ENV['REDIS_URL'],
      network_timeout: 5,
      pool_timeout: 5
    }
  end

  Rails.logger.info "✓ Sidekiq configured successfully"
else
  Rails.logger.warn "⚠ Redis not available - Sidekiq disabled. Background jobs will not run."
  Rails.logger.warn "  Check REDIS_URL environment variable and Redis service status"
end
