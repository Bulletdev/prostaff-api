# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # KDA Trend Analytics Controller
      #
      # Tracks kill/death/assist performance trends over time for players.
      # Analyzes recent match history to identify performance patterns and calculate rolling averages.
      #
      # @example GET /api/v1/analytics/kda_trend/:player_id
      #   {
      #     kda_by_match: [{ match_id: 1, kda: 3.5, kills: 5, deaths: 2, assists: 2, victory: true }],
      #     averages: { last_10_games: 3.2, last_20_games: 2.9, overall: 2.8 }
      #   }
      #
      # Main endpoints:
      # - GET show: Returns KDA trends for the last 50 matches with rolling averages
      class KdaTrendController < Api::V1::BaseController
        def show
          player = organization_scoped(Player).find(params[:player_id])

          # Get recent matches for the player
          stats = PlayerMatchStat.joins(:match)
                                 .where(player: player, matches: { organization_id: current_organization.id })
                                 .order('matches.game_start DESC')
                                 .limit(50)
                                 .includes(:match)

          trend_data = {
            player: PlayerSerializer.render_as_hash(player),
            kda_by_match: stats.map do |stat|
              kda = stat.deaths.zero? ? (stat.kills + stat.assists).to_f : ((stat.kills + stat.assists).to_f / stat.deaths)
              {
                match_id: stat.match.id,
                date: stat.match.game_start,
                kills: stat.kills,
                deaths: stat.deaths,
                assists: stat.assists,
                kda: kda.round(2),
                champion: stat.champion,
                victory: stat.match.victory
              }
            end,
            averages: {
              last_10_games: calculate_kda_average(stats.limit(10)),
              last_20_games: calculate_kda_average(stats.limit(20)),
              overall: calculate_kda_average(stats)
            }
          }

          render_success(trend_data)
        end

        private

        def calculate_kda_average(stats)
          return 0 if stats.empty?

          total_kills = stats.sum(:kills)
          total_deaths = stats.sum(:deaths)
          total_assists = stats.sum(:assists)

          deaths = total_deaths.zero? ? 1 : total_deaths
          ((total_kills + total_assists).to_f / deaths).round(2)
        end
      end
    end
  end
end
