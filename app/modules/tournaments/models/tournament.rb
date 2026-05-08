# frozen_string_literal: true

# Represents a double-elimination tournament for ArenaBR.
# Manages registration, bracket generation, and lifecycle transitions.
class Tournament < ApplicationRecord
  STATUSES = %w[draft registration_open seeding in_progress finished cancelled].freeze
  FORMATS  = %w[double_elimination single_elimination].freeze
  GAMES    = %w[league_of_legends].freeze

  # Associations
  has_many :tournament_teams,   dependent: :destroy
  has_many :tournament_matches, dependent: :destroy
  has_many :approved_teams, -> { where(status: 'approved') },
           class_name: 'TournamentTeam'

  # Validations
  validates :name,   presence: true, length: { maximum: 100 }
  validates :game,   inclusion: { in: GAMES }
  validates :format, inclusion: { in: FORMATS }
  validates :status, inclusion: { in: STATUSES }
  validates :max_teams, numericality: { greater_than: 0 }
  validates :entry_fee_cents,  numericality: { greater_than_or_equal_to: 0 }
  validates :prize_pool_cents, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :open_registration, -> { where(status: 'registration_open') }
  scope :active,            -> { where(status: %w[registration_open seeding in_progress]) }
  scope :by_scheduled,      -> { order(scheduled_start_at: :asc) }

  def registration_open?
    status == 'registration_open'
  end

  def bracket_generated?
    if association(:tournament_matches).loaded?
      tournament_matches.any?
    else
      tournament_matches.exists?
    end
  end

  def enrolled_teams_count
    # Use loaded association (avoids N+1 when preloaded via includes)
    if association(:tournament_teams).loaded?
      tournament_teams.count { |t| t.status == 'approved' }
    else
      tournament_teams.where(status: 'approved').count
    end
  end

  def slots_available?
    enrolled_teams_count < max_teams
  end

  def entry_fee_reais
    entry_fee_cents / 100.0
  end

  def prize_pool_reais
    prize_pool_cents / 100.0
  end
end
