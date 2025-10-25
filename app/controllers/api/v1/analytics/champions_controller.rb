# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Champion Analytics Controller
      #
      # Provides detailed champion performance statistics for individual players.
      # Analyzes champion pool diversity, mastery levels, and win rates across all champions played.
      #
      # @example GET /api/v1/analytics/champions/:player_id
      #   {
      #     player: { id: 1, name: "Player1" },
      #     champion_stats: [{ champion: "Aatrox", games_played: 15, win_rate: 0.6, avg_kda: 3.2, mastery_grade: "A" }],
      #     champion_diversity: { total_champions: 25, highly_played: 5, average_games: 3.2 }
      #   }
      #
      # Main endpoints:
      # - GET show: Returns comprehensive champion statistics including mastery grades and diversity metrics
      class ChampionsController < Api::V1::BaseController
        def show
          player = organization_scoped(Player).find(params[:player_id])

          stats = PlayerMatchStat.where(player: player)
                                 .group(:champion)
                                 .select(
                                   'champion',
                                   'COUNT(*) as games_played',
                                   'SUM(CASE WHEN matches.victory THEN 1 ELSE 0 END) as wins',
                                   'AVG((kills + assists)::float / NULLIF(deaths, 0)) as avg_kda'
                                 )
                                 .joins(:match)
                                 .order('games_played DESC')

          champion_stats = stats.map do |stat|
            win_rate = stat.games_played.zero? ? 0 : (stat.wins.to_f / stat.games_played)
            {
              champion: stat.champion,
              games_played: stat.games_played,
              win_rate: win_rate,
              avg_kda: stat.avg_kda&.round(2) || 0,
              mastery_grade: calculate_mastery_grade(win_rate, stat.avg_kda)
            }
          end

          champion_data = {
            player: PlayerSerializer.render_as_hash(player),
            champion_stats: champion_stats,
            top_champions: champion_stats.take(5),
            champion_diversity: {
              total_champions: champion_stats.count,
              highly_played: champion_stats.count { |c| c[:games_played] >= 10 },
              average_games: if champion_stats.empty?
                               0
                             else
                               (champion_stats.sum do |c|
                                 c[:games_played]
                               end / champion_stats.count.to_f).round(1)
                             end
            }
          }

          render_success(champion_data)
        end

        private

        def calculate_mastery_grade(win_rate, avg_kda)
          score = (win_rate * 100 * 0.6) + ((avg_kda || 0) * 10 * 0.4)

          case score
          when 80..Float::INFINITY then 'S'
          when 70...80 then 'A'
          when 60...70 then 'B'
          when 50...60 then 'C'
          else 'D'
          end
        end
      end
    end
  end
end
