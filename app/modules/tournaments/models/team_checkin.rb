# frozen_string_literal: true

# Records that a team's captain confirmed presence before match start.
# Unique per team per match. Missing checkin at deadline triggers WalkoverJob.
class TeamCheckin < ApplicationRecord
  # Associations
  belongs_to :tournament_match
  belongs_to :tournament_team
  belongs_to :checked_in_by, class_name: 'User', optional: true

  # Validations
  validates :tournament_team_id, uniqueness: { scope: :tournament_match_id, message: 'already checked in' }

  validate :team_is_participant

  private

  def team_is_participant
    return unless tournament_match && tournament_team

    return if [tournament_match.team_a_id, tournament_match.team_b_id].include?(tournament_team_id)

    errors.add(:tournament_team, 'is not a participant in this match')
  end
end
