# frozen_string_literal: true

class CleanupExpiredTokensJob < ApplicationJob
  queue_as :default

  # This job should be scheduled to run periodically (e.g., daily)
  # You can use cron, sidekiq-scheduler, or a similar tool to schedule this job

  def perform
    Rails.logger.info "Starting cleanup of expired tokens..."

    # Cleanup expired password reset tokens
    password_reset_deleted = PasswordResetToken.cleanup_old_tokens
    Rails.logger.info "Cleaned up #{password_reset_deleted} expired password reset tokens"

    # Cleanup expired blacklisted tokens
    blacklist_deleted = TokenBlacklist.cleanup_expired
    Rails.logger.info "Cleaned up #{blacklist_deleted} expired blacklisted tokens"

    Rails.logger.info "Token cleanup completed successfully"
  rescue => e
    Rails.logger.error "Error during token cleanup: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
