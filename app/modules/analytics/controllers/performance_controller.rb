# frozen_string_literal: true

module Analytics
  module Controllers
    class PerformanceController < Api::V1::BaseController
      include ::Analytics::Concerns::AnalyticsCalculations

      def index
        # Team performance analytics
        matches = organization_scoped(Match)
        players = organization_scoped(Player).active

        # Date range filter
        matches = if params[:start_date].present? && params[:end_date].present?
                    matches.in_date_range(params[:start_date], params[:end_date])
                  else
                    matches.recent(30) # Default to last 30 days
                  end

        performance_data = {
          overview: calculate_team_overview(matches),
          win_rate_trend: calculate_win_rate_trend(matches),
          performance_by_role: calculate_performance_by_role(matches, damage_field: :total_damage_dealt),
          best_performers: identify_best_performers(players, matches),
          match_type_breakdown: calculate_match_type_breakdown(matches)
        }

        render_success(performance_data)
      end

      private

      def calculate_team_overview(matches)
        stats = PlayerMatchStat.where(match: matches)

        {
          total_matches: matches.count,
          wins: matches.victories.count,
          losses: matches.defeats.count,
          win_rate: calculate_win_rate(matches),
          avg_game_duration: matches.average(:game_duration)&.round(0),
          avg_kda: calculate_avg_kda(stats),
          avg_kills_per_game: stats.average(:kills)&.round(1),
          avg_deaths_per_game: stats.average(:deaths)&.round(1),
          avg_assists_per_game: stats.average(:assists)&.round(1),
          avg_gold_per_game: stats.average(:gold_earned)&.round(0),
          avg_damage_per_game: stats.average(:total_damage_dealt)&.round(0),
          avg_vision_score: stats.average(:vision_score)&.round(1)
        }
      end

      def identify_best_performers(players, matches)
        players.map do |player|
          stats = PlayerMatchStat.where(player: player, match: matches)
          next if stats.empty?

          {
            player: PlayerSerializer.render_as_hash(player),
            games: stats.count,
            avg_kda: calculate_avg_kda(stats),
            avg_performance_score: stats.average(:performance_score)&.round(1) || 0,
            mvp_count: stats.joins(:match).where(matches: { victory: true }).count
          }
        end.compact.sort_by { |p| -p[:avg_performance_score] }.take(5)
      end

      def calculate_match_type_breakdown(matches)
        matches.group(:match_type).select(
          'match_type',
          'COUNT(*) as total',
          'SUM(CASE WHEN victory THEN 1 ELSE 0 END) as wins'
        ).map do |stat|
          win_rate = stat.total.zero? ? 0 : ((stat.wins.to_f / stat.total) * 100).round(1)
          {
            match_type: stat.match_type,
            total: stat.total,
            wins: stat.wins,
            losses: stat.total - stat.wins,
            win_rate: win_rate
          }
        end
      end
    end
  end
end
