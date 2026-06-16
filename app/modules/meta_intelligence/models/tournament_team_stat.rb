# frozen_string_literal: true

# Materialized team-level stats per tournament split from Oracle's Elixir (Datalisk).
#
# Populated by MetaIntelligence::SyncTournamentStatsJob via ProStaffScraperService.
# The `data` JSONB column stores the full Datalisk row verbatim so schema changes
# on their side don't require a migration — access specific metrics via helpers below.
#
# Common keys in `data` (field names vary slightly by OE version):
#   gp / GP       — games played
#   w  / W        — wins
#   wr / WR       — win rate (0-100)
#   gd15 / GD@15  — gold diff at 15 minutes
#   csd15         — CS diff at 15
#   xpd15         — XP diff at 15
#   fb            — first blood %
#   ft            — first tower %
#   fd            — first dragon %
#   drg           — dragon control %
#   baron         — baron control %
#   wpm           — wards placed per minute
#   wcpm          — wards cleared per minute
#   gspd          — game score per diff
class TournamentTeamStat < ApplicationRecord
  self.table_name = 'tournament_team_stats'

  validates :tournament_id, presence: true
  validates :team_name,     presence: true
  validates :league,        presence: true
  validates :year,          presence: true, numericality: { only_integer: true, greater_than: 2000 }
  validates :data,          presence: true
  validates :computed_at,   presence: true
  validates :tournament_id, uniqueness: { scope: :team_name, message: 'team already exists for this tournament' }

  scope :for_league,     ->(league) { where(league: league) }
  scope :for_year,       ->(year)   { where(year: year) }
  scope :for_tournament, ->(id)     { where(tournament_id: id) }
  scope :recent,                    -> { order(year: :desc, computed_at: :desc) }

  def games_played
    data['gp'] || data['GP'] || data['games_played']
  end

  def win_rate
    val = data['wr'] || data['WR'] || data['win_rate']
    return val if val
    return nil unless data['W'] && data['GP'].to_i.positive?

    (data['W'].to_f / data['GP'] * 100).round(1)
  end

  def gold_diff_at_15
    data['gd15'] || data['GD15'] || data['GD@15'] || data['gd_at_15']
  end

  def wpm
    data['wpm'] || data['WPM']
  end

  def dragon_control_pct
    val = data['drg'] || data['DRG%'] || data['dragon_pct']
    val.is_a?(String) ? val.to_f : val
  end

  def game_score_diff
    val = data['gspd'] || data['GSPD']
    val.is_a?(String) ? val.to_f : val
  end
end
