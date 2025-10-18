# frozen_string_literal: true

module Analytics
  module Services
    # Service for calculating performance analytics
    #
    # Extracts complex analytics calculations from PerformanceController
    # to follow Single Responsibility Principle and reduce controller complexity.
    #
    # @example Calculate performance for matches
    #   service = PerformanceAnalyticsService.new(matches, players)
    #   data = service.calculate_performance_data(player_id: 123)
    #
    class PerformanceAnalyticsService
      include Analytics::Concerns::AnalyticsCalculations

      attr_reader :matches, :players

      def initialize(matches, players)
        @matches = matches
        @players = players
      end

      # Calculates complete performance data
      #
      # @param player_id [Integer, nil] Optional player ID for individual stats
      # @return [Hash] Performance analytics data
      def calculate_performance_data(player_id: nil)
        data = {
          overview: team_overview,
          win_rate_trend: win_rate_trend,
          performance_by_role: performance_by_role,
          best_performers: best_performers,
          match_type_breakdown: match_type_breakdown
        }

        if player_id
          player = @players.find_by(id: player_id)
          data[:player_stats] = player_statistics(player) if player
        end

        data
      end

      private

      # Calculates team overview statistics
      def team_overview
        stats = PlayerMatchStat.where(match: @matches)

        {
          total_matches: @matches.count,
          wins: @matches.victories.count,
          losses: @matches.defeats.count,
          win_rate: calculate_win_rate(@matches),
          avg_game_duration: @matches.average(:game_duration)&.round(0),
          avg_kda: calculate_avg_kda(stats),
          avg_kills_per_game: stats.average(:kills)&.round(1),
          avg_deaths_per_game: stats.average(:deaths)&.round(1),
          avg_assists_per_game: stats.average(:assists)&.round(1),
          avg_gold_per_game: stats.average(:gold_earned)&.round(0),
          avg_damage_per_game: stats.average(:damage_dealt_total)&.round(0),
          avg_vision_score: stats.average(:vision_score)&.round(1)
        }
      end

      # Calculates win rate trend over time
      def win_rate_trend
        calculate_win_rate_trend(@matches, group_by: :week)
      end

      # Calculates performance statistics grouped by role
      def performance_by_role
        stats = PlayerMatchStat.joins(:player).where(match: @matches)

        stats.group('players.role').select(
          'players.role',
          'COUNT(*) as games',
          'AVG(player_match_stats.kills) as avg_kills',
          'AVG(player_match_stats.deaths) as avg_deaths',
          'AVG(player_match_stats.assists) as avg_assists',
          'AVG(player_match_stats.gold_earned) as avg_gold',
          'AVG(player_match_stats.damage_dealt_total) as avg_damage',
          'AVG(player_match_stats.vision_score) as avg_vision'
        ).map do |stat|
          {
            role: stat.role,
            games: stat.games,
            avg_kda: build_kda_hash(stat),
            avg_gold: stat.avg_gold&.round(0) || 0,
            avg_damage: stat.avg_damage&.round(0) || 0,
            avg_vision: stat.avg_vision&.round(1) || 0
          }
        end
      end

      # Identifies top performing players
      def best_performers
        @players.map do |player|
          stats = PlayerMatchStat.where(player: player, match: @matches)
          next if stats.empty?

          {
            player: player_hash(player),
            games: stats.count,
            avg_kda: calculate_avg_kda(stats),
            avg_performance_score: stats.average(:performance_score)&.round(1) || 0,
            mvp_count: stats.joins(:match).where(matches: { victory: true }).count
          }
        end.compact.sort_by { |p| -p[:avg_performance_score] }.take(5)
      end

      # Calculates match statistics grouped by match type
      def match_type_breakdown
        @matches.group(:match_type).select(
          'match_type',
          'COUNT(*) as total',
          'SUM(CASE WHEN victory THEN 1 ELSE 0 END) as wins'
        ).map do |stat|
          total = stat.total.to_i
          wins = stat.wins.to_i
          win_rate = total.zero? ? 0.0 : ((wins.to_f / total) * 100).round(1)

          {
            match_type: stat.match_type,
            total: total,
            wins: wins,
            losses: total - wins,
            win_rate: win_rate
          }
        end
      end

      # Calculates individual player statistics
      #
      # @param player [Player] The player to calculate stats for
      # @return [Hash, nil] Player statistics or nil if no data
      def player_statistics(player)
        return nil unless player

        stats = PlayerMatchStat.where(player: player, match: @matches)
        return nil if stats.empty?

        total_kills = stats.sum(:kills)
        total_deaths = stats.sum(:deaths)
        total_assists = stats.sum(:assists)
        games_played = stats.count

        wins = stats.joins(:match).where(matches: { victory: true }).count
        win_rate = games_played.zero? ? 0.0 : (wins.to_f / games_played)

        kda = calculate_kda(total_kills, total_deaths, total_assists)

        total_cs = stats.sum(:cs)
        total_duration = @matches.where(id: stats.pluck(:match_id)).sum(:game_duration)

        {
          player_id: player.id,
          summoner_name: player.summoner_name,
          games_played: games_played,
          win_rate: win_rate,
          kda: kda,
          cs_per_min: calculate_cs_per_min(total_cs, total_duration),
          gold_per_min: calculate_gold_per_min(stats.sum(:gold_earned), total_duration),
          vision_score: stats.average(:vision_score)&.round(1) || 0.0,
          damage_share: 0.0,
          avg_kills: (total_kills.to_f / games_played).round(1),
          avg_deaths: (total_deaths.to_f / games_played).round(1),
          avg_assists: (total_assists.to_f / games_played).round(1)
        }
      end

      # Helper to build KDA hash from stat object
      def build_kda_hash(stat)
        {
          kills: stat.avg_kills&.round(1) || 0,
          deaths: stat.avg_deaths&.round(1) || 0,
          assists: stat.avg_assists&.round(1) || 0
        }
      end

      # Helper to serialize player to hash
      def player_hash(player)
        PlayerSerializer.render_as_hash(player)
      end
    end
  end
end
