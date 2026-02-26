# frozen_string_literal: true

# Removes expired password reset tokens and blacklisted JWT tokens from the database.
#
# Scheduled daily at 2 AM via sidekiq.yml.
# Emits structured log fields so monitoring tools can alert if the job
# stops executing (gap 2 from FAILURE_MODE_ANALYSIS.md).
#
# @example Trigger manually via Rails console
#   CleanupExpiredTokensJob.perform_now
class CleanupExpiredTokensJob < ApplicationJob
  queue_as :default

  def perform
    start_time = Time.current

    Rails.logger.info(
      event: 'job_started',
      job: self.class.name,
      queue: queue_name.to_s
    )

    password_reset_deleted = PasswordResetToken.cleanup_old_tokens
    blacklist_deleted      = TokenBlacklist.cleanup_expired

    duration_ms = ((Time.current - start_time) * 1000).round

    Rails.logger.info(
      event: 'job_completed',
      job: self.class.name,
      status: 'success',
      duration_ms: duration_ms,
      password_reset_deleted: password_reset_deleted,
      blacklist_deleted: blacklist_deleted
    )

    record_job_heartbeat
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

    raise
  end
end
