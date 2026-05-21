# frozen_string_literal: true

# Represents an organization's enrollment in a tournament.
# Tracks status from pending → approved/rejected, and links to the roster snapshot.
class TournamentTeam < ApplicationRecord
  STATUSES = %w[pending approved rejected withdrawn disqualified].freeze

  # Associations
  belongs_to :tournament
  belongs_to :organization

  has_many :tournament_roster_snapshots, dependent: :destroy
  has_many :match_reports,               dependent: :destroy
  has_many :team_checkins,               dependent: :destroy

  # Matches where this team participates
  has_many :matches_as_team_a, class_name: 'TournamentMatch', foreign_key: :team_a_id, dependent: :nullify
  has_many :matches_as_team_b, class_name: 'TournamentMatch', foreign_key: :team_b_id, dependent: :nullify
  has_many :won_matches,       class_name: 'TournamentMatch', foreign_key: :winner_id,  dependent: :nullify
  has_many :lost_matches,      class_name: 'TournamentMatch', foreign_key: :loser_id,   dependent: :nullify

  # Validations
  validates :team_name, presence: true, length: { maximum: 50 }
  validates :team_tag,  presence: true, length: { in: 2..5 }
  validates :status,    inclusion: { in: STATUSES }
  validates :tournament_id, uniqueness: { scope: :organization_id, message: 'already enrolled' }

  # Scopes
  scope :pending,  -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }

  def approved?
    status == 'approved'
  end

  def pending?
    status == 'pending'
  end

  def approve!
    update!(status: 'approved', approved_at: Time.current)
  end

  def reject!
    update!(status: 'rejected', rejected_at: Time.current)
  end

  def withdraw!
    update!(status: 'withdrawn')
  end
end
