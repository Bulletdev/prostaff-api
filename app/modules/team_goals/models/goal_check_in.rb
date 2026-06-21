# frozen_string_literal: true

# Append-only record of a measured value for a TeamGoal at a point in time.
#
# Created either automatically by Goals::EvaluateGoalsJob (source: 'auto')
# or manually by a user submitting progress (source: 'manual').
# Records are never soft-deleted — the history is the point.
#
# @attr [Decimal] measured_value  The resolved metric value at check-in time
# @attr [String]  source          'auto' (job) or 'manual' (user)
# @attr [Text]    note            Optional context from the user
class GoalCheckIn < ApplicationRecord
  SOURCES = %w[auto manual].freeze

  belongs_to :team_goal
  belongs_to :organization
  belongs_to :created_by, class_name: 'User', optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :organization_id, presence: true

  scope :auto_generated, -> { where(source: 'auto') }
  scope :manual_entries, -> { where(source: 'manual') }
  scope :chronological, -> { order(created_at: :asc) }
  scope :recent, ->(n = 10) { order(created_at: :desc).limit(n) }
end
