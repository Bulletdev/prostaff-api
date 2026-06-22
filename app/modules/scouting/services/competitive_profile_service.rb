# frozen_string_literal: true

# Fetches a player's historical competitive profile from Elasticsearch
# via the ProStaff Scraper analytics endpoint.
#
# The join key between ProStaff player records and Leaguepedia/ES data is
# `players.professional_name` (the tournament IGN). `players.summoner_name`
# stores the current Riot ID and diverges from historical names — do not use it.
#
# Players without `professional_name` return an explicit error key so the
# frontend can guide the user to fill in the field.
#
# @example
#   result = CompetitiveProfileService.new(player: player).call
#   result[:error]               # => "no_professional_name" or nil
#   result[:competitive_games]   # => Integer
#   result[:champion_pool_competitive] # => Array of hashes
class CompetitiveProfileService
  def initialize(player:, league: nil, min_year: nil, min_games: 3)
    @player    = player
    @league    = league
    @min_year  = min_year
    @min_games = min_games
  end

  def call
    pro_name = @player.professional_name
    return { error: 'no_professional_name' } if pro_name.blank?

    raw = scraper.fetch_player_profile(
      name: pro_name,
      league: @league,
      min_year: @min_year,
      min_games: @min_games
    )

    format_response(raw, pro_name)
  rescue ProStaffScraperService::NotFoundError
    { error: 'player_not_found_in_es' }
  rescue ProStaffScraperService::UnavailableError => e
    Rails.logger.warn("[CompetitiveProfileService] scraper unavailable: #{e.message}")
    { error: 'scraper_unavailable' }
  end

  private

  def scraper
    @scraper ||= ProStaffScraperService.new
  end

  def format_response(raw, pro_name)
    {
      professional_name: pro_name,
      competitive_games: dig_raw(raw, :total_games, 0),
      competitive_win_rate: dig_raw(raw, :win_rate, 0.0),
      leagues_played: dig_raw(raw, :leagues, []),
      champion_pool_competitive: format_pool(raw),
      avg_kda_competitive: dig_raw(raw, :avg_kda),
      last_competitive_game: dig_raw(raw, :last_game)
    }
  end

  def format_pool(raw)
    pool = dig_raw(raw, :champion_pool, [])
    pool.map { |c| format_pool_entry(c) }
  end

  def format_pool_entry(entry)
    {
      champion: dig_raw(entry, :champion),
      games: dig_raw(entry, :games, 0).to_i,
      wins: dig_raw(entry, :wins, 0).to_i,
      win_rate: dig_raw(entry, :win_rate, 0.0).to_f,
      avg_kda: dig_raw(entry, :avg_kda)
    }
  end

  # Reads a key from a hash that may use string or symbol keys.
  def dig_raw(hash, key, default = nil)
    hash[key.to_s] || hash[key] || default
  end
end
