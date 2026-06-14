# frozen_string_literal: true

module MetaIntelligence
  # Materializes champion pick/ban statistics from Elasticsearch into champion_patch_stats.
  #
  # Queries ProStaffScraperService#fetch_champion_stats for each (league, patch) pair
  # and upserts rows using the UNIQUE constraint (champion_name, league, patch, role).
  #
  # Designed to run weekly via Sidekiq cron and also after historical backfills complete.
  # Idempotent: re-running a (league, patch) pair overwrites with fresh values.
  #
  # @example Enqueue for a specific league + patch
  #   MetaIntelligence::SyncChampionPatchStatsJob.perform_later('CBLOL', '14.10')
  #
  # @example Enqueue for all patches of a league (discovery mode)
  #   MetaIntelligence::SyncChampionPatchStatsJob.perform_later('CBLOL')
  class SyncChampionPatchStatsJob < ApplicationJob
    queue_as :meta_intelligence

    retry_on ProStaffScraperService::UnavailableError, wait: 5.minutes, attempts: 3
    retry_on StandardError, wait: 10.minutes, attempts: 2

    # @param league [String] e.g. 'CBLOL', 'LCS'
    # @param patch  [String, nil] e.g. '14.10'. nil = let the Scraper return all patches and sync each.
    # @param min_games [Integer] minimum games to include a champion (avoids noise from tiny samples)
    def perform(league, patch = nil, min_games: 3)
      Rails.logger.info(
        "[SyncChampionPatchStatsJob] starting — league=#{league} patch=#{patch || 'all'} " \
        "min_games=#{min_games}"
      )

      scraper = ProStaffScraperService.new
      result  = scraper.fetch_champion_stats(league: league, patch: patch, min_games: min_games)

      total_games = result['total_games'] || result[:total_games] || 0
      champions   = result['champions']   || result[:champions]   || []

      if champions.empty?
        Rails.logger.warn("[SyncChampionPatchStatsJob] no champions returned — league=#{league} patch=#{patch}")
        return
      end

      upserted = upsert_all(league, patch, total_games, champions)

      Rails.logger.info(
        "[SyncChampionPatchStatsJob] complete — league=#{league} patch=#{patch || 'all'} " \
        "champions=#{champions.size} upserted=#{upserted}"
      )
    end

    private

    def upsert_all(league, patch, total_games, champions)
      rows = champions.flat_map do |c|
        build_rows(league, patch, total_games, c)
      end

      return 0 if rows.empty?

      ChampionPatchStat.upsert_all(
        rows,
        unique_by: :uq_champion_patch_stats,
        update_only: %i[
          blue_bans red_bans blue_picks red_picks wins games
          ban_count_per_team presence_rate win_rate avg_pick_order computed_at
        ]
      )

      rows.size
    end

    def build_rows(league, patch, total_games, champion_data)
      fields = extract_fields(champion_data)
      now    = Time.current.utc
      [build_base_row(league, patch, total_games, fields, now)]
    end

    # Normalises a champion data hash that may use string or symbol keys.
    # Each `fetch_val` call is one branch, so we keep this at 1 branch/field
    # by delegating to a single helper instead of `||` chains.
    def extract_fields(data)
      {
        champion: fetch_val(data, 'champion'),
        role: fetch_val(data, 'role'),
        blue_bans: fetch_val(data, 'blue_bans', 0).to_i,
        red_bans: fetch_val(data, 'red_bans', 0).to_i,
        blue_picks: fetch_val(data, 'blue_picks', 0).to_i,
        red_picks: fetch_val(data, 'red_picks', 0).to_i,
        wins: fetch_val(data, 'wins', 0).to_i,
        avg_order: fetch_val(data, 'avg_pick_order')
      }
    end

    # Accepts both string and symbol key access — the Scraper may return either.
    def fetch_val(hash, str_key, default = nil)
      hash[str_key] || hash[str_key.to_sym] || default
    end

    def build_base_row(league, patch, total_games, fields, now)
      ban_sum  = fields[:blue_bans]  + fields[:red_bans]
      pick_sum = fields[:blue_picks] + fields[:red_picks]
      {
        champion_name: fields[:champion],
        league: league,
        patch: patch.to_s,
        role: fields[:role].presence,
        blue_bans: fields[:blue_bans],
        red_bans: fields[:red_bans],
        blue_picks: fields[:blue_picks],
        red_picks: fields[:red_picks],
        wins: fields[:wins],
        games: total_games,
        ban_count_per_team: 5,
        presence_rate: compute_presence_rate(ban_sum, pick_sum, total_games),
        win_rate: compute_win_rate(fields[:wins], pick_sum),
        avg_pick_order: fields[:avg_order],
        computed_at: now,
        created_at: now,
        updated_at: now
      }
    end

    # ban_sum  = blue_bans + red_bans (pre-summed by caller)
    # pick_sum = blue_picks + red_picks (pre-summed by caller)
    # presence_rate = (ban_sum + pick_sum) / total_games; range [0, 2.0]
    def compute_presence_rate(ban_sum, pick_sum, total_games)
      return nil if total_games.zero?

      ((ban_sum + pick_sum).to_f / total_games).round(4)
    end

    def compute_win_rate(wins, pick_sum)
      return nil if pick_sum.zero?

      (wins.to_f / pick_sum).round(4)
    end
  end
end
