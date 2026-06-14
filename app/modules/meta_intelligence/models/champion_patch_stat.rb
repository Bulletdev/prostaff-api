# frozen_string_literal: true

# Materialized pick/ban statistics per champion, league, patch and role.
#
# Populated by SyncChampionPatchStatsJob from Elasticsearch via ProStaffScraperService.
# The Rails API should read from this table — never query ES live per request.
#
# presence_rate: (blue_bans + red_bans + blue_picks + red_picks) / games
# Range [0, 2.0] — Oracle's Elixir event-sum convention. A champion banned AND
# picked in the same game contributes 2 events. Not [0, 1].
#
# win_rate: wins / (blue_picks + red_picks). Only pick appearances count.
#
# avg_pick_order: global draft position, 1.0 = first overall pick, 10.0 = tenth.
class ChampionPatchStat < ApplicationRecord
  self.table_name = 'champion_patch_stats'

  LEAGUES = %w[CBLOL LCS LEC LCK LPL LJL LLA NACL VCS PCS TCL LCO].freeze

  validates :champion_name, presence: true
  validates :league,        presence: true
  validates :patch,         presence: true, format: { with: /\A\d+\.\d+\z/ }
  validates :role,          inclusion: { in: %w[top jungle mid bot support] }, allow_nil: true
  validates :blue_bans,     numericality: { greater_than_or_equal_to: 0 }
  validates :red_bans,      numericality: { greater_than_or_equal_to: 0 }
  validates :blue_picks,    numericality: { greater_than_or_equal_to: 0 }
  validates :red_picks,     numericality: { greater_than_or_equal_to: 0 }
  validates :wins,          numericality: { greater_than_or_equal_to: 0 }
  validates :games,         numericality: { greater_than_or_equal_to: 0 }
  validates :ban_count_per_team, inclusion: { in: [3, 5] }
  validates :presence_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2.0 },
                            allow_nil: true
  validates :win_rate,      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1.0 },
                            allow_nil: true
  validates :avg_pick_order, numericality: { greater_than_or_equal_to: 1.0, less_than_or_equal_to: 10.0 },
                             allow_nil: true

  scope :for_league,    ->(league) { where(league: league) }
  scope :for_patch,     ->(patch)  { where(patch: patch) }
  scope :for_role,      ->(role)   { where(role: role) }
  scope :aggregated,               -> { where(role: nil) }
  scope :by_presence,              -> { order(presence_rate: :desc) }
  scope :by_win_rate,              -> { order(win_rate: :desc) }
  scope :with_min_games, ->(n) { where('games >= ?', n) }

  # Returns total ban events across both sides.
  def total_bans
    blue_bans + red_bans
  end

  # Returns total pick appearances across both sides.
  def total_picks
    blue_picks + red_picks
  end
end
