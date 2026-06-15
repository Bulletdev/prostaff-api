# frozen_string_literal: true

# A single player's entry in a seasonal roster snapshot.
#
# Captures the player's role and line (main/academy/reserve/two_way)
# at the moment the snapshot was taken. Historical analysis of lineup
# changes uses the diff between consecutive snapshots.
class RosterSeasonSlot < ApplicationRecord
  include Constants

  belongs_to :roster_season_snapshot
  belongs_to :player

  TRANSFER_STATUSES = %w[joined departed loan].freeze

  validates :line, inclusion: { in: Constants::Player::LINES }
  validates :role, inclusion: { in: Constants::Player::ROLES }, allow_nil: true
  validates :transfer_status, inclusion: { in: TRANSFER_STATUSES }, allow_nil: true
  validates :player_id, uniqueness: { scope: :roster_season_snapshot_id,
                                      message: 'already in this snapshot' }

  scope :starters, -> { where(line: 'main') }
  scope :academy,  -> { where(line: 'academy') }
end
