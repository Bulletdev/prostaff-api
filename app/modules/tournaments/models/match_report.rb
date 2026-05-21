# frozen_string_literal: true

# Stores a captain's score report for a tournament match.
# Dual-report validation: both captains report, matching scores auto-confirm; diverging → disputed.
class MatchReport < ApplicationRecord
  STATUSES = %w[pending submitted confirmed disputed].freeze

  # Associations
  belongs_to :tournament_match
  belongs_to :tournament_team
  belongs_to :reported_by_user, class_name: 'User', optional: true

  # Validations
  validates :status, inclusion: { in: STATUSES }
  validates :team_a_score, numericality: { greater_than_or_equal_to: 0 }
  validates :team_b_score, numericality: { greater_than_or_equal_to: 0 }
  validates :evidence_url, presence: true, on: :submit
  validates :tournament_team_id, uniqueness: { scope: :tournament_match_id, message: 'already reported' }

  # Scopes
  scope :submitted,  -> { where(status: 'submitted') }
  scope :confirmed,  -> { where(status: 'confirmed') }
  scope :disputed,   -> { where(status: 'disputed') }

  def submit!(team_a_score:, team_b_score:, evidence_url:, user:)
    update!(
      team_a_score: team_a_score,
      team_b_score: team_b_score,
      evidence_url: evidence_url,
      reported_by_user: user,
      status: 'submitted',
      submitted_at: Time.current
    )
  end

  def submitted?
    status == 'submitted'
  end

  def scores_match?(other_report)
    team_a_score == other_report.team_a_score &&
      team_b_score == other_report.team_b_score
  end
end
