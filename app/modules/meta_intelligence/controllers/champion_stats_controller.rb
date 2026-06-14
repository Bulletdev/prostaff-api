# frozen_string_literal: true

module MetaIntelligence
  module Controllers
    # Returns champion pick/ban statistics per league, patch, and role.
    #
    # Reads from the `champion_patch_stats` materialized table, which is
    # populated by SyncChampionPatchStatsJob. All filtering is done at the
    # database level to avoid loading unnecessary rows into memory.
    #
    # presence_rate range is [0, 2.0] per Oracle's Elixir event-sum convention:
    # a champion banned AND picked in the same game contributes 2 events.
    #
    # @example List stats for LCK patch 14.24 junglers with at least 10 games
    #   GET /api/v1/meta/champion-stats?league=LCK&patch=14.24&role=jungle&min_games=10
    class ChampionStatsController < Api::V1::BaseController
      # GET /api/v1/meta/champion-stats
      #
      # @param [String] league    filter by league (optional, e.g. 'LCK', 'CBLOL')
      # @param [String] patch     filter by patch version (optional, e.g. '14.24')
      # @param [String] role      filter by role (optional): top/jungle/mid/bot/support
      # @param [Integer] min_games minimum number of games threshold (optional, default 0)
      # @return [JSON] { data: { stats: [...], meta: { league:, patch:, total: } } }
      def index
        stats = filtered_stats

        render_success(
          {
            stats: stats.map { |s| serialize_stat(s) },
            meta: {
              league: params[:league],
              patch: params[:patch],
              total: stats.size
            }
          },
          message: 'Champion patch stats retrieved'
        )
      end

      private

      def filtered_stats
        scope = ChampionPatchStat.all
        scope = scope.for_league(params[:league]) if params[:league].present?
        scope = scope.for_patch(params[:patch])   if params[:patch].present?
        scope = scope.for_role(params[:role])     if params[:role].present?
        scope = scope.with_min_games(min_games)   if min_games.positive?
        scope.by_presence
      end

      def min_games
        [params[:min_games].to_i, 0].max
      end

      def serialize_stat(stat)
        {
          champion_name: stat.champion_name,
          role: stat.role,
          presence_rate: stat.presence_rate,
          win_rate: stat.win_rate,
          avg_pick_order: stat.avg_pick_order,
          blue_bans: stat.blue_bans,
          red_bans: stat.red_bans,
          blue_picks: stat.blue_picks,
          red_picks: stat.red_picks,
          games: stat.games,
          ban_count_per_team: stat.ban_count_per_team
        }
      end
    end
  end
end
