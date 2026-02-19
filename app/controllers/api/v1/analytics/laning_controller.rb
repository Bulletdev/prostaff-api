# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Laning Phase Analytics Controller
      #
      # Returns CS, gold, and early-game metrics for a given player.
      # Timeline data (gold_diff@10/@15) is not available from the data source,
      # so those fields are omitted (nil) and the frontend falls back gracefully.
      #
      class LaningController < Api::V1::BaseController
        def show
          player = organization_scoped(Player).find(params[:player_id])

          stats = PlayerMatchStat.joins(:match)
                                 .includes(:match)
                                 .where(player: player, match: { organization: current_organization })
                                 .order('"match"."game_start" DESC')
                                 .limit(20)

          games = stats.count
          wins  = stats.where(match: { victory: true }).count

          laning_data = {
            player:           PlayerSerializer.render_as_hash(player),
            avg_cs_per_min:   stats.average(:cs_per_min)&.round(1) || calculate_avg_cs_per_min(stats),
            avg_cs_total:     stats.average(:cs)&.round(1) || 0,
            lane_win_rate:    games.zero? ? nil : ((wins.to_f / games) * 100).round(1),
            first_blood_rate: games.zero? ? nil : ((stats.where(first_blood: true).count.to_f / games) * 100).round(1),
            first_tower_rate: games.zero? ? nil : ((stats.where(first_tower: true).count.to_f / games) * 100).round(1),
            avg_gold:         stats.average(:gold_earned)&.round(0) || 0,
            # Timeline fields not available from data source
            gold_diff_10:     nil,
            gold_diff_15:     nil,
            cs_diff_10:       nil,
            cs_diff_15:       nil,
            solo_kills:       nil,
            laning_trend:     build_laning_trend(stats)
          }

          render_success(laning_data)
        end

        private

        def build_laning_trend(stats)
          stats.map do |stat|
            next unless stat.match.game_start

            duration_mins = stat.match.game_duration ? stat.match.game_duration / 60.0 : 25
            cs = stat.cs || 0
            cs_pm = duration_mins > 0 ? (cs / duration_mins).round(1) : 0

            {
              date:      stat.match.game_start.strftime('%Y-%m-%d'),
              cs_total:  cs,
              cs_per_min: cs_pm,
              gold:      stat.gold_earned || 0,
              gold_diff: 0,  # not available
              champion:  stat.champion,
              victory:   stat.match.victory
            }
          end.compact.sort_by { |d| d[:date] }
        end

        def calculate_avg_cs_per_min(stats)
          total_cs      = 0
          total_minutes = 0

          stats.each do |stat|
            next unless stat.match.game_duration

            total_cs      += stat.cs || 0
            total_minutes += stat.match.game_duration / 60.0
          end

          total_minutes.zero? ? 0 : (total_cs / total_minutes).round(1)
        end
      end
    end
  end
end
