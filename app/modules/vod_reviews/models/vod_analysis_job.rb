# frozen_string_literal: true

# Tracks asynchronous video analysis requests sent to the VideoAI service.
#
# Each VodReview can have multiple analysis jobs (one per user-triggered request).
# The job progresses through statuses: pending -> queued -> downloading -> analyzing -> done | failed.
#
# @example Check if analysis is still running
#   job.in_progress?   # true when queued, downloading, or analyzing
#
# @example Retrieve results only when safe
#   job.suggested_timestamps if job.done?
class VodAnalysisJob < ApplicationRecord
  belongs_to :vod_review

  STATUSES = %w[pending queued downloading analyzing done failed].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :pending_or_queued, -> { where(status: %w[pending queued]) }
  scope :in_progress, -> { where(status: %w[downloading analyzing]) }
  scope :done, -> { where(status: 'done') }

  def done?
    status == 'done'
  end

  def failed?
    status == 'failed'
  end

  def in_progress?
    %w[queued downloading analyzing].include?(status)
  end
end
