# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Discard jobs whose associated record was deleted before the job ran.
  # Without this, DeserializationError causes Sidekiq to retry up to 25 times.
  discard_on ActiveJob::DeserializationError

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  protected

  # Writes a "last ran at" timestamp to Sidekiq Redis so MonitoringController
  # can detect when a scheduled job has not executed within its expected interval.
  #
  # Call this at the end of a successful #perform, before the rescue block.
  # Safe to call even if Redis is unavailable — failures are warned and swallowed.
  #
  # Key format: prostaff:job_heartbeat:<ClassName>
  # TTL: 7 days (survives a weekend without the job running)
  def record_job_heartbeat
    return unless defined?(Sidekiq)

    key = "prostaff:job_heartbeat:#{self.class.name}"
    Sidekiq.redis { |r| r.call('SET', key, Time.current.iso8601, 'EX', 7 * 24 * 3600) }
  rescue StandardError => e
    Rails.logger.warn(
      event: 'job_heartbeat_error',
      job: self.class.name,
      error: e.message
    )
  end
end
