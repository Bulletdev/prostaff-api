# frozen_string_literal: true

# Daily LP snapshot for a player, enabling rank progression charts over time.
#
# One record per player per queue type per day (enforced by unique index).
# Created by SyncPlayerRankJob as part of the Riot API sync routine.
#
# @attr [String] queue_type  Riot queue identifier (RANKED_SOLO_5x5 | RANKED_FLEX_SR)
# @attr [String] tier        Rank tier (IRON..CHALLENGER)
# @attr [String] rank        Division within tier (I..IV); nil for apex tiers
# @attr [Integer] league_points  Current LP at snapshot time
# @attr [Integer] wins       Wins this season at snapshot time
# @attr [Integer] losses     Losses this season at snapshot time
# @attr [Date] recorded_on   Date the snapshot was taken
class PlayerRankSnapshot < ApplicationRecord
  belongs_to :player

  QUEUE_TYPES = %w[RANKED_SOLO_5x5 RANKED_FLEX_SR].freeze

  validates :queue_type, inclusion: { in: QUEUE_TYPES }
  validates :league_points, numericality: { greater_than_or_equal_to: 0 }
  validates :recorded_on, presence: true
  validates :player_id, uniqueness: { scope: %i[queue_type recorded_on] }

  scope :solo_queue, -> { where(queue_type: "RANKED_SOLO_5x5") }
  scope :flex_queue, -> { where(queue_type: "RANKED_FLEX_SR") }
  scope :recent,     lambda { |days = 90| where(recorded_on: (days.days.ago.to_date)..Date.current) }
  scope :chronological, -> { order(recorded_on: :asc) }
end
