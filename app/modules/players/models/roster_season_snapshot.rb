# frozen_string_literal: true

# A point-in-time record of which players were on the active roster
# for a given organization and competitive season/split.
#
# This is the Rails model for the data the "Roster Changes" spreadsheet
# tracked manually with color-coded rows. Operations are manual: coaches
# create a snapshot when the roster is locked before a split begins.
#
# @see RosterSeasonSlot for the individual player lines within a snapshot.
class RosterSeasonSnapshot < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by, class_name: 'User'

  has_many :roster_season_slots, dependent: :destroy
  has_many :players, through: :roster_season_slots

  validates :season,        presence: true
  validates :snapshot_date, presence: true

  scope :for_season, ->(season) { where(season: season) }
  scope :recent,     -> { order(snapshot_date: :desc) }
end
