# frozen_string_literal: true

# Materialized per-player stats per tournament split from Oracle's Elixir (Datalisk).
#
# Populated by MetaIntelligence::SyncTournamentStatsJob via ProStaffScraperService.
# The `data` JSONB column stores the full Datalisk row verbatim.
#
# Common keys in `data`:
#   gp / GP         — games played
#   kda / KDA       — KDA ratio
#   k / K           — avg kills
#   d / D           — avg deaths
#   a / A           — avg assists
#   kp / KP%        — kill participation %
#   dpm / DPM       — damage per minute
#   dmg / DMG%      — damage share %
#   csm / CSM       — CS per minute
#   egpm / EGPM     — earned gold per minute
#   gd15 / GD@15    — gold diff at 15 minutes
#   csd15 / CSD@15  — CS diff at 15
#   wpm / WPM       — wards placed per minute
class TournamentPlayerStat < ApplicationRecord
  self.table_name = 'tournament_player_stats'

  validates :tournament_id, presence: true
  validates :player_name,   presence: true
  validates :league,        presence: true
  validates :year,          presence: true, numericality: { only_integer: true, greater_than: 2000 }
  validates :data,          presence: true
  validates :computed_at,   presence: true
  validates :tournament_id, uniqueness: { scope: :player_name, message: 'player already exists for this tournament' }

  scope :for_league,          ->(league) { where(league: league) }
  scope :for_year,            ->(year)   { where(year: year) }
  scope :for_tournament,      ->(id)     { where(tournament_id: id) }
  scope :for_team,            ->(team)   { where(team_name: team) }
  scope :for_position,        ->(pos)    { where(position: pos) }
  scope :recent,                         -> { order(year: :desc, computed_at: :desc) }
  scope :by_professional_name, ->(name)  { where("LOWER(player_name) = LOWER(?)", name.to_s.strip) if name.present? }

  def games_played
    data['gp'] || data['GP'] || data['games_played']
  end

  def kda
    data['kda'] || data['KDA']
  end

  def deaths
    data['d'] || data['D'] || data['deaths']
  end

  def assists
    data['a'] || data['A'] || data['assists']
  end

  def damage_per_minute
    data['dpm'] || data['DPM']
  end

  def damage_share
    data['dmg'] || data['DMG%'] || data['damage_share']
  end

  def cs_per_minute
    data['csm'] || data['CSM']
  end

  def gold_diff_at_15
    data['gd15'] || data['GD@15'] || data['csd15'] || data['CSD@15']
  end

  def kill_participation
    data['kp'] || data['KP%'] || data['kill_participation']
  end
end
