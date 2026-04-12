# frozen_string_literal: true

# Immutable roster snapshot — created at inscription approval time (Roster Lock).
# Never updated after creation. Used for historical audit and dispute resolution.
class TournamentRosterSnapshot < ApplicationRecord
  POSITIONS = %w[starter substitute].freeze
  ROLES     = %w[top jungle mid adc support fill].freeze

  # Associations
  belongs_to :tournament_team
  belongs_to :player

  # Validations
  validates :summoner_name, presence: true
  validates :position, inclusion: { in: POSITIONS }
  validates :role,     inclusion: { in: ROLES }, allow_nil: true
  validates :player_id, uniqueness: { scope: :tournament_team_id, message: 'already in roster' }

  # Scopes
  scope :starters,    -> { where(position: 'starter') }
  scope :substitutes, -> { where(position: 'substitute') }
end
