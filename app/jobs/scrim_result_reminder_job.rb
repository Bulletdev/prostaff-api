# frozen_string_literal: true

# Daily job that manages scrim result reporting lifecycle.
#
# Responsibilities:
#   1. Initialize report records for accepted scrims that have passed their scheduled time
#   2. Send reminders to orgs that haven't reported (at 24h and 48h before deadline)
#   3. Expire reports where the deadline has passed without a submission
#
# Scheduled: daily at 10:00 UTC via sidekiq-scheduler
class ScrimResultReminderJob < ApplicationJob
  queue_as :default

  REMINDER_THRESHOLDS = [
    { days_before_deadline: 1, label: '24h' },
    { days_before_deadline: 3, label: '3 days' }
  ].freeze

  def perform
    initialize_pending_reports
    send_reminders
    expire_overdue_reports
    record_job_heartbeat
  rescue StandardError => e
    Rails.logger.error("[ScrimResultReminderJob] Failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    raise
  end

  private

  # Creates ScrimResultReport records for accepted scrims that ended but haven't been reported yet
  def initialize_pending_reports
    accepted_past_scrims.find_each do |request|
      deadline = [request.proposed_at, Time.current].max + ScrimResultReport::DEADLINE_DAYS.days

      [request.requesting_organization_id, request.target_organization_id].each do |org_id|
        ScrimResultReport.find_or_create_by!(
          scrim_request_id: request.id,
          organization_id: org_id
        ) do |r|
          r.status       = 'pending'
          r.deadline_at  = deadline
          r.attempt_count = 0
        end
      rescue ActiveRecord::RecordNotUnique
        # Race condition — already exists, ignore
      end
    end
  end

  def send_reminders
    REMINDER_THRESHOLDS.each do |threshold|
      window_start = threshold[:days_before_deadline].days.from_now
      window_end   = window_start + 1.hour

      ScrimResultReport
        .actionable
        .where(deadline_at: window_start..window_end)
        .includes(:organization, scrim_request: %i[requesting_organization target_organization])
        .find_each do |report|
          notify_pending_report(report, threshold[:label])
        end
    end
  end

  def expire_overdue_reports
    ScrimResultReport.overdue.find_each do |report|
      report.update_columns(status: 'expired', updated_at: Time.current)
      Rails.logger.info("[ScrimResultReminderJob] Expired report id=#{report.id} org=#{report.organization_id}")
    end
  end

  def accepted_past_scrims
    ScrimRequest
      .where(status: 'accepted')
      .where('proposed_at < ?', Time.current)
      .where(
        'NOT EXISTS (' \
        'SELECT 1 FROM scrim_result_reports srr ' \
        'WHERE srr.scrim_request_id = scrim_requests.id)'
      )
  end

  def notify_pending_report(report, deadline_label)
    org  = report.organization
    req  = report.scrim_request
    opp  = req.requesting_organization_id == org.id ? req.target_organization : req.requesting_organization

    Rails.logger.info(
      "[ScrimResultReminderJob] Reminding org=#{org.id} (#{org.name}) " \
      "to report scrim_request=#{req.id} vs #{opp.name} — #{deadline_label} before deadline"
    )

    # TODO: replace with in-app/email notification when notification system is implemented
    # NotificationService.notify(org, :scrim_result_reminder, scrim_request: req, ...)
  rescue StandardError => e
    Rails.logger.warn("[ScrimResultReminderJob] Reminder failed for report=#{report.id}: #{e.message}")
  end
end
