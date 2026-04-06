# frozen_string_literal: true

# Stores one organization's reported outcome for a scrim series.
#
# Each ScrimRequest produces two reports — one per participating org.
# The system compares both to determine if results match and marks the
# confrontation as confirmed or disputed.
#
# Lifecycle:
#   pending      → org has not reported yet
#   reported     → this org reported, waiting for opponent
#   confirmed    → both orgs reported matching results
#   disputed     → reports conflict; orgs can re-report (up to MAX_ATTEMPTS)
#   unresolvable → MAX_ATTEMPTS exceeded with persistent conflict
#   expired      → DEADLINE_DAYS passed without a report from this org
class ScrimResultReport < ApplicationRecord
  STATUSES      = %w[pending reported confirmed disputed unresolvable expired].freeze
  MAX_ATTEMPTS  = 3
  DEADLINE_DAYS = 7

  belongs_to :scrim_request
  belongs_to :organization

  validates :status, inclusion: { in: STATUSES }
  validates :game_outcomes, presence: true, if: :reported_at?
  validate  :outcomes_are_valid, if: :reported_at?
  validate  :attempts_not_exceeded, if: :reported_at?

  scope :actionable,    -> { where(status: %w[pending disputed]) }
  scope :confirmed,     -> { where(status: 'confirmed') }
  scope :overdue,       -> { actionable.where('deadline_at < ?', Time.current) }
  scope :needs_reminder, lambda {
    actionable
      .where('deadline_at > ?', Time.current)
      .where('deadline_at < ?', (ScrimResultReport::DEADLINE_DAYS - 1).days.from_now)
  }

  def series_winner_org_id
    return nil unless status == 'confirmed'

    wins   = game_outcomes.count('win')
    losses = game_outcomes.count('loss')
    wins > losses ? organization_id : opponent_organization_id
  end

  def opponent_organization_id
    req = scrim_request
    req.requesting_organization_id == organization_id ? req.target_organization_id : req.requesting_organization_id
  end

  def re_reportable?
    status == 'disputed' && attempt_count < MAX_ATTEMPTS
  end

  def attempts_remaining
    MAX_ATTEMPTS - attempt_count
  end

  private

  def outcomes_are_valid
    return if game_outcomes.blank?

    return if game_outcomes.all? { |o| %w[win loss].include?(o) }

    errors.add(:game_outcomes, 'must only contain "win" or "loss"')
  end

  def attempts_not_exceeded
    return unless attempt_count >= MAX_ATTEMPTS && status_was == 'disputed'

    errors.add(:base, 'Maximum reporting attempts exceeded')
  end
end
