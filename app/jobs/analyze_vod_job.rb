# frozen_string_literal: true

# Submits a VOD analysis request to the VideoAI service and records the
# external job ID for later polling via analyze_status.
#
# Idempotent: skips silently if the job is already done or failed.
# Error handling: marks the job as failed and logs the error — never re-raises.
#
# @example Enqueue from controller
#   AnalyzeVodJob.perform_later(job.id)
class AnalyzeVodJob < ApplicationJob
  queue_as :default

  def perform(analysis_job_id)
    job = VodAnalysisJob.find(analysis_job_id)
    return if job.done? || job.failed?

    job.update!(status: 'queued')

    # VodReview uses OrganizationScoped default_scope — must bypass it in background jobs
    # where Current.organization_id is not set.
    vod_review = VodReview.unscoped.find(job.vod_review_id)

    response = VideoAiClient.create_job(
      vod_review_id: job.vod_review_id,
      video_url: vod_review.video_url
    )

    job.update!(
      external_job_id: response[:job_id],
      status: 'downloading'
    )

    Rails.logger.info("[VOD] Analysis job #{analysis_job_id} queued with external_job_id=#{response[:job_id]}")
  rescue VideoAiClient::Error => e
    Rails.logger.error("[VOD] VideoAI error for job #{analysis_job_id}: #{e.message}")
    job&.update_columns(status: 'failed', error_message: e.message, updated_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[VOD] Unexpected error for job #{analysis_job_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    job&.update_columns(status: 'failed', error_message: e.message, updated_at: Time.current)
  end
end
