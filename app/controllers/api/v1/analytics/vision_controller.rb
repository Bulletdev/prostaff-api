# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Vision Analytics Controller
      #
      # Returns flat vision metrics so the frontend can read them directly
      # without unpacking nested keys.
      #
      class VisionController < Api::V1::BaseController
        def show
          player = organization_scoped(Player).find(params[:player_id])

          stats = PlayerMatchStat.joins(:match)
                                 .includes(:match)
                                 .where(player: player, match: { organization: current_organization })
                                 .order('"match"."game_start" DESC')
                                 .limit(20)

          vision_data = {
            player:              PlayerSerializer.render_as_hash(player),
            avg_vision_score:    stats.average(:vision_score)&.round(1) || 0,
            avg_wards_placed:    stats.average(:wards_placed)&.round(1) || 0,
            avg_wards_destroyed: stats.average(:wards_destroyed)&.round(1) || 0,
            avg_control_wards:   stats.average(:control_wards_purchased)&.round(1) || 0,
            best_vision_game:    stats.maximum(:vision_score) || 0,
            total_wards_placed:  stats.sum(:wards_placed) || 0,
            total_wards_destroyed: stats.sum(:wards_destroyed) || 0,
            vision_per_min:      calculate_avg_vision_per_min(stats),
            role_comparison:     calculate_role_comparison(player),
            vision_trend:        build_vision_trend(stats)
          }

          render_success(vision_data)
        end

        private

        def build_vision_trend(stats)
          stats.map do |stat|
            next unless stat.match.game_start

            {
              date:         stat.match.game_start.strftime('%Y-%m-%d'),
              vision_score: stat.vision_score || 0,
              wards_placed: stat.wards_placed || 0,
              wards_destroyed: stat.wards_destroyed || 0,
              champion:     stat.champion,
              victory:      stat.match.victory
            }
          end.compact.sort_by { |d| d[:date] }
        end

        def calculate_avg_vision_per_min(stats)
          total_vision  = 0
          total_minutes = 0

          stats.each do |stat|
            next unless stat.match.game_duration && stat.vision_score

            total_vision  += stat.vision_score
            total_minutes += stat.match.game_duration / 60.0
          end

          total_minutes.zero? ? 0 : (total_vision / total_minutes).round(2)
        end

        def calculate_role_comparison(player)
          team_stats   = PlayerMatchStat.joins(:player)
                                        .where(players: { organization: current_organization, role: player.role })
                                        .where.not(players: { id: player.id })
          player_stats = PlayerMatchStat.where(player: player)

          {
            player_avg: player_stats.average(:vision_score)&.round(1) || 0,
            role_avg:   team_stats.average(:vision_score)&.round(1) || 0,
            percentile: calculate_percentile(player_stats.average(:vision_score), team_stats)
          }
        end

        def calculate_percentile(player_avg, team_stats)
          return 0 if player_avg.nil? || team_stats.empty?

          all_averages = team_stats.group(:player_id).average(:vision_score).values
          all_averages << player_avg
          all_averages.sort!

          rank = all_averages.index(player_avg) + 1
          ((rank.to_f / all_averages.size) * 100).round(0)
        end
      end
    end
  end
end
