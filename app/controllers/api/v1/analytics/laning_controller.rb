# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Laning Phase Analytics Controller
      #
      # Provides early game performance metrics focusing on CS (creep score) and gold acquisition.
      # Tracks farming efficiency with CS per minute calculations and gold earnings.
      #
      # @example GET /api/v1/analytics/laning/:player_id
      #   {
      #     cs_performance: { avg_cs_total: 185.5, avg_cs_per_min: 7.4, best_cs_game: 245 },
      #     gold_performance: { avg_gold: 12500, best_gold_game: 15000 }
      #   }
      #
      # Main endpoints:
      # - GET show: Returns laning statistics for the last 20 matches with CS and gold metrics
      class LaningController < Api::V1::BaseController
        def show
          player = organization_scoped(Player).find(params[:player_id])

          stats = PlayerMatchStat.joins(:match)
                                 .where(player: player, match: { organization: current_organization })
                                 .order('matches.game_start DESC')
                                 .limit(20)

          laning_data = {
            player: PlayerSerializer.render_as_hash(player),
            cs_performance: {
              avg_cs_total: stats.average('minions_killed + jungle_minions_killed')&.round(1),
              avg_cs_per_min: calculate_avg_cs_per_min(stats),
              best_cs_game: stats.maximum('minions_killed + jungle_minions_killed'),
              worst_cs_game: stats.minimum('minions_killed + jungle_minions_killed')
            },
            gold_performance: {
              avg_gold: stats.average(:gold_earned)&.round(0),
              best_gold_game: stats.maximum(:gold_earned),
              worst_gold_game: stats.minimum(:gold_earned)
            },
            cs_by_match: stats.map do |stat|
              match_duration_mins = stat.match.game_duration ? stat.match.game_duration / 60.0 : 25
              cs_total = (stat.minions_killed || 0) + (stat.jungle_minions_killed || 0)
              cs_per_min = cs_total / match_duration_mins

              {
                match_id: stat.match.id,
                date: stat.match.game_start,
                cs_total: cs_total,
                cs_per_min: cs_per_min.round(1),
                gold: stat.gold_earned,
                champion: stat.champion,
                victory: stat.match.victory
              }
            end
          }

          render_success(laning_data)
        end

        private

        def calculate_avg_cs_per_min(stats)
          total_cs = 0
          total_minutes = 0

          stats.each do |stat|
            next unless stat.match.game_duration

            cs = (stat.minions_killed || 0) + (stat.jungle_minions_killed || 0)
            minutes = stat.match.game_duration / 60.0
            total_cs += cs
            total_minutes += minutes
          end

          return 0 if total_minutes.zero?

          (total_cs / total_minutes).round(1)
        end
      end
    end
  end
end
