# frozen_string_literal: true

module Analytics
  module Controllers
    # Controller for team performance comparison and analytics
    # Provides endpoints to compare player statistics, team averages, and role rankings
    class TeamComparisonController < Api::V1::BaseController
      def index
        players = fetch_active_players
        matches = fetch_filtered_matches

        comparison_data = build_comparison_data(players, matches)
        render_success(comparison_data)
      end

      private

      def fetch_active_players
        organization_scoped(Player).active.includes(:player_match_stats)
      end

      def fetch_filtered_matches
        matches = organization_scoped(Match)
        apply_date_range_filter(matches)
      end

      def apply_date_range_filter(matches)
        return matches.in_date_range(params[:start_date], params[:end_date]) if date_range_provided?

        matches.recent(30)
      end

      def date_range_provided?
        params[:start_date].present? && params[:end_date].present?
      end

      def build_comparison_data(players, matches)
        {
          players: build_player_comparisons(players, matches),
          team_averages: calculate_team_averages(matches),
          role_rankings: calculate_role_rankings(players, matches)
        }
      end

      def build_player_comparisons(players, matches)
        player_stats = players.map { |player| build_player_stats(player, matches) }
        sorted_player_stats = player_stats.compact
        sorted_player_stats.sort_by { |p| -p[:avg_performance_score] }
      end

      def build_player_stats(player, matches)
        stats = PlayerMatchStat.where(player: player, match: matches)
        return nil if stats.empty?

        {
          player: PlayerSerializer.render_as_hash(player),
          games_played: stats.count,
          kda: calculate_kda(stats),
          avg_damage: calculate_average(stats, :total_damage_dealt, 0),
          avg_gold: calculate_average(stats, :gold_earned, 0),
          avg_cs: calculate_cs_average(stats),
          avg_vision_score: calculate_average(stats, :vision_score, 1),
          avg_performance_score: calculate_average(stats, :performance_score, 1),
          multikills: build_multikills_hash(stats)
        }
      end

      def calculate_average(stats, column, precision)
        stats.average(column)&.round(precision) || 0
      end

      def calculate_cs_average(stats)
        stats.average('minions_killed + jungle_minions_killed')&.round(1) || 0
      end

      def build_multikills_hash(stats)
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
          avg_damage: calculate_average(all_stats, :total_damage_dealt, 0),
          avg_gold: calculate_average(all_stats, :gold_earned, 0),
          avg_cs: calculate_cs_average(all_stats),
          avg_vision_score: calculate_average(all_stats, :vision_score, 1)
        }
      end

      def calculate_role_rankings(players, matches)
        rankings = {}

        %w[top jungle mid adc support].each do |role|
          rankings[role] = calculate_role_ranking(players, matches, role)
        end

        rankings
      end

      def calculate_role_ranking(players, matches, role)
        role_players = players.where(role: role)
        role_data = role_players.map { |player| build_role_player_stats(player, matches) }
        sorted_data = role_data.compact
        sorted_data.sort_by { |p| -p[:avg_performance] }
      end

      def build_role_player_stats(player, matches)
        stats = PlayerMatchStat.where(player: player, match: matches)
        return nil if stats.empty?

        {
          player_id: player.id,
          summoner_name: player.summoner_name,
          avg_performance: stats.average(:performance_score)&.round(1) || 0,
          games: stats.count
        }
      end
    end
  end
end
