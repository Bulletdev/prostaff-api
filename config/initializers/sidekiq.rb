require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

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
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end