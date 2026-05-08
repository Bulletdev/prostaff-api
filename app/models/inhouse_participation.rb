# frozen_string_literal: true

# Records a single player's participation in an inhouse session.
#
# Tracks which team the player is assigned to (none/blue/red) and
# a snapshot of their tier at the time of joining, used for team balancing.
#
class InhouseParticipation < ApplicationRecord
  # Associations
  belongs_to :inhouse
  belongs_to :player

  # Validations
  validates :player_id, uniqueness: { scope: :inhouse_id, message: 'is already in this inhouse' }
  validates :team, inclusion: { in: %w[none blue red] }

  ROLES = %w[top jungle mid adc support fill].freeze

  # Scopes
  scope :blue_team, -> { where(team: 'blue') }
  scope :red_team,  -> { where(team: 'red') }
end
