# frozen_string_literal: true

# Represents a single match within a tournament bracket.
# Uses FK self-references (next_match_winner_id, next_match_loser_id) for O(1) bracket progression.
class TournamentMatch < ApplicationRecord
  STATUSES      = %w[scheduled checkin_open in_progress awaiting_report awaiting_confirm
                     disputed confirmed completed walkover].freeze
  BRACKET_SIDES = %w[upper lower grand_final].freeze

  # Associations
  belongs_to :tournament
  belongs_to :team_a,  class_name: 'TournamentTeam', optional: true
  belongs_to :team_b,  class_name: 'TournamentTeam', optional: true
  belongs_to :winner,  class_name: 'TournamentTeam', optional: true
  belongs_to :loser,   class_name: 'TournamentTeam', optional: true

  # Self-referential — O(1) bracket progression
  belongs_to :next_match_winner, class_name: 'TournamentMatch', optional: true,
                                 foreign_key: :next_match_winner_id
  belongs_to :next_match_loser,  class_name: 'TournamentMatch', optional: true,
                                 foreign_key: :next_match_loser_id

  has_many :match_reports, dependent: :destroy
  has_many :team_checkins, dependent: :destroy

  # Validations
  validates :status,       inclusion: { in: STATUSES }
  validates :bracket_side, inclusion: { in: BRACKET_SIDES }
  validates :round_label,  presence: true
  validates :round_order,  numericality: { greater_than_or_equal_to: 0 }
  validates :match_number, numericality: { greater_than: 0 }

  # Scopes
  scope :scheduled,     -> { where(status: 'scheduled') }
  scope :checkin_open,  -> { where(status: 'checkin_open') }
  scope :in_progress,   -> { where(status: 'in_progress') }
  scope :disputed,      -> { where(status: 'disputed') }
  scope :upper_bracket, -> { where(bracket_side: 'upper') }
  scope :lower_bracket, -> { where(bracket_side: 'lower') }
  scope :by_round,      -> { order(:round_order, :match_number) }

  def checkin_for(team)
    team_checkins.find_by(tournament_team: team)
  end

  def team_a_checked_in?
    team_checkins.exists?(tournament_team: team_a)
  end

  def team_b_checked_in?
    team_checkins.exists?(tournament_team: team_b)
  end

  def both_checked_in?
    team_a_checked_in? && team_b_checked_in?
  end

  def report_for(team)
    match_reports.find_by(tournament_team: team)
  end

  def both_reported?
    match_reports.where(status: 'submitted').count == 2
  end

  def open_for_checkin?
    status == 'checkin_open'
  end

  def open_for_report?
    status.in?(%w[awaiting_report awaiting_confirm])
  end

  def disputed?
    status == 'disputed'
  end
end
