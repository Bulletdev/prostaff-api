# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-scheduler'

# Only configure Sidekiq if Redis is available
if ENV['REDIS_URL'].present?
  Sidekiq.configure_server do |config|
    config.redis = { url: ENV['REDIS_URL'] }

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
    config.redis = { url: ENV['REDIS_URL'] }
  end
else
  Rails.logger.warn "Redis not configured - Sidekiq will not be available. Background jobs will fail."
end
