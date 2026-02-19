# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # API Controller for team performance comparison and analytics
      # Provides endpoints to compare player statistics, team averages, and role rankings
      # with advanced filtering options
      class TeamComparisonController < Api::V1::BaseController
        def index
          players = fetch_active_players
          matches = build_matches_query

          comparison_data = build_comparison_data(players, matches)

          render json: { data: comparison_data }
        end

        private

        def fetch_active_players
          organization_scoped(Player).active
        end

        def build_matches_query
          matches = organization_scoped(Match)
          matches = apply_date_filter(matches)
          matches = apply_opponent_filter(matches)
          apply_match_type_filter(matches)
        end

        def apply_date_filter(matches)
          return matches.in_date_range(params[:start_date], params[:end_date]) if date_range_params?
          return matches.recent(params[:days].to_i) if params[:days].present?

          matches.recent(30)
        end

        def date_range_params?
          params[:start_date].present? && params[:end_date].present?
        end

        def apply_opponent_filter(matches)
          return matches unless params[:opponent_team_id].present?

          matches.where(opponent_team_id: params[:opponent_team_id])
        end

        def apply_match_type_filter(matches)
          return matches unless params[:match_type].present?

          matches.where(match_type: params[:match_type])
        end

        def build_comparison_data(players, matches)
          {
            players: build_player_comparisons(players, matches),
            team_averages: calculate_team_averages(matches),
            role_rankings: calculate_role_rankings(players, matches)
          }
        end

        # Single GROUP BY query replaces one query per player (N+1 → 1)
        def build_player_comparisons(players, matches)
          player_ids = players.pluck(:id)
          match_ids  = matches.pluck(:id)
          return [] if player_ids.empty? || match_ids.empty?

          agg_rows = PlayerMatchStat
            .where(player_id: player_ids, match_id: match_ids)
            .group(:player_id)
            .select(
              'player_id',
              'COUNT(*) AS games_played',
              'SUM(kills) AS total_kills',
              'SUM(deaths) AS total_deaths',
              'SUM(assists) AS total_assists',
              'AVG(damage_dealt_total) AS avg_damage',
              'AVG(gold_earned) AS avg_gold',
              'AVG(cs) AS avg_cs',
              'AVG(vision_score) AS avg_vision_score',
              'AVG(performance_score) AS avg_performance_score',
              'SUM(double_kills) AS double_kills',
              'SUM(triple_kills) AS triple_kills',
              'SUM(quadra_kills) AS quadra_kills',
              'SUM(penta_kills) AS penta_kills'
            )

          players_by_id = players.index_by(&:id)

          agg_rows.filter_map do |agg|
            player = players_by_id[agg.player_id]
            next unless player

            deaths = agg.total_deaths.to_i.zero? ? 1 : agg.total_deaths.to_i
            kda    = ((agg.total_kills.to_i + agg.total_assists.to_i).to_f / deaths).round(2)

            {
              player:                PlayerSerializer.render_as_hash(player),
              games_played:          agg.games_played.to_i,
              kda:                   kda,
              avg_damage:            agg.avg_damage.to_f.round(0),
              avg_gold:              agg.avg_gold.to_f.round(0),
              avg_cs:                agg.avg_cs.to_f.round(1),
              avg_vision_score:      agg.avg_vision_score.to_f.round(1),
              avg_performance_score: agg.avg_performance_score.to_f.round(1),
              multikills: {
                double: agg.double_kills.to_i,
                triple: agg.triple_kills.to_i,
                quadra: agg.quadra_kills.to_i,
                penta:  agg.penta_kills.to_i
              }
            }
          end.sort_by { |p| -p[:avg_performance_score] }
        end

        def calculate_average(stats, column, precision)
          stats.average(column)&.round(precision) || 0
        end

        def build_multikills(stats)
          {
            double: stats.sum(:double_kills),
            triple: stats.sum(:triple_kills),
            quadra: stats.sum(:quadra_kills),
            penta: stats.sum(:penta_kills)
          }
        end

        def calculate_kda(stats)
          total_kills = stats.sum(:kills)
          total_deaths = stats.sum(:deaths)
          total_assists = stats.sum(:assists)

          deaths = total_deaths.zero? ? 1 : total_deaths
          ((total_kills + total_assists).to_f / deaths).round(2)
        end

        def calculate_team_averages(matches)
          all_stats = PlayerMatchStat.where(match: matches)

          {
            avg_kda: calculate_kda(all_stats),
            avg_damage: calculate_average(all_stats, :damage_dealt_total, 0),
            avg_gold: calculate_average(all_stats, :gold_earned, 0),
            avg_cs: calculate_average(all_stats, :cs, 1),
            avg_vision_score: calculate_average(all_stats, :vision_score, 1)
          }
        end

        # Single GROUP BY across all roles — replaces 3N per-player queries
        def calculate_role_rankings(players, matches)
          player_ids = players.pluck(:id)
          match_ids  = matches.pluck(:id)

          rankings = { 'top' => [], 'jungle' => [], 'mid' => [], 'adc' => [], 'support' => [] }
          return rankings if player_ids.empty? || match_ids.empty?

          agg_rows = PlayerMatchStat
            .joins(:player)
            .where(player_id: player_ids, match_id: match_ids)
            .group('player_id, players.role, players.summoner_name')
            .select(
              'player_id',
              'players.role AS role',
              'players.summoner_name AS summoner_name',
              'COUNT(*) AS games',
              'AVG(performance_score) AS avg_performance'
            )

          agg_rows.each do |agg|
            role = agg.role
            next unless rankings.key?(role)

            rankings[role] << {
              player_id:    agg.player_id,
              summoner_name: agg.summoner_name,
              avg_performance: agg.avg_performance.to_f.round(1),
              games:           agg.games.to_i
            }
          end

          rankings.transform_values { |list| list.sort_by { |p| -p[:avg_performance] } }
        end
      end
    end
  end
end
