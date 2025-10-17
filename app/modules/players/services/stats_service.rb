# frozen_string_literal: true

module Players
  module Services
    # Service responsible for calculating player statistics and performance metrics
    # Extracted from PlayersController to follow Single Responsibility Principle
    class StatsService
      attr_reader :player

      def initialize(player)
        @player = player
      end

      # Get comprehensive player statistics
      def calculate_stats
        matches = player.matches.order(game_start: :desc)
        recent_matches = matches.limit(20)
        player_stats = PlayerMatchStat.where(player: player, match: matches)

        {
          player: player,
          overall: calculate_overall_stats(matches, player_stats),
          recent_form: calculate_recent_form_stats(recent_matches),
          champion_pool: player.champion_pools.order(games_played: :desc).limit(5),
          performance_by_role: calculate_performance_by_role(player_stats)
        }
      end

      # Calculate player win rate
      def self.calculate_win_rate(matches)
        return 0 if matches.empty?

        ((matches.victories.count.to_f / matches.count) * 100).round(1)
      end

      # Calculate average KDA
      def self.calculate_avg_kda(stats)
        return 0 if stats.empty?

        total_kills = stats.sum(:kills)
        total_deaths = stats.sum(:deaths)
        total_assists = stats.sum(:assists)

        deaths = total_deaths.zero? ? 1 : total_deaths
        ((total_kills + total_assists).to_f / deaths).round(2)
      end

      # Calculate recent form (W/L pattern)
      def self.calculate_recent_form(matches)
        matches.map { |m| m.victory? ? 'W' : 'L' }
      end

      private

      def calculate_overall_stats(matches, player_stats)
        {
          total_matches: matches.count,
          wins: matches.victories.count,
          losses: matches.defeats.count,
          win_rate: self.class.calculate_win_rate(matches),
          avg_kda: self.class.calculate_avg_kda(player_stats),
          avg_cs: player_stats.average(:cs)&.round(1) || 0,
          avg_vision_score: player_stats.average(:vision_score)&.round(1) || 0,
          avg_damage: player_stats.average(:damage_dealt_champions)&.round(0) || 0
        }
      end

      def calculate_recent_form_stats(recent_matches)
        {
          last_5_matches: self.class.calculate_recent_form(recent_matches.limit(5)),
          last_10_matches: self.class.calculate_recent_form(recent_matches.limit(10))
        }
      end

      def calculate_performance_by_role(stats)
        stats.group(:role).select(
          'role',
          'COUNT(*) as games',
          'AVG(kills) as avg_kills',
          'AVG(deaths) as avg_deaths',
          'AVG(assists) as avg_assists',
          'AVG(performance_score) as avg_performance'
        ).map do |stat|
          {
            role: stat.role,
            games: stat.games,
            avg_kda: {
              kills: stat.avg_kills&.round(1) || 0,
              deaths: stat.avg_deaths&.round(1) || 0,
              assists: stat.avg_assists&.round(1) || 0
            },
            avg_performance: stat.avg_performance&.round(1) || 0
          }
        end
      end
    end
  end
end
