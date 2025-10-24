# frozen_string_literal: true

module Analytics
  module Concerns
    # Shared utility methods for analytics calculations
    # Used across controllers and services to avoid code duplication
    #
    # Can be used as module methods or included in classes:
    #   Analytics::Concerns::AnalyticsCalculations.calculate_win_rate(matches)
    #   # or
    #   include Analytics::Concerns::AnalyticsCalculations
    #   calculate_win_rate(matches)
    module AnalyticsCalculations
      extend ActiveSupport::Concern

      # Calculates win rate percentage from a collection of matches
      #
      # @param matches [Array, ActiveRecord::Relation] Collection of matches
      # @return [Float] Win rate percentage
      def calculate_win_rate(matches)
        return 0.0 if matches.empty?

        total = Array.wrap(matches).size
        wins = matches.try(:victories)&.count || matches.count(&:victory?)

        ((wins.to_f / total) * 100).round(1)
      end
      module_function :calculate_win_rate

      # Calculates average KDA (Kill/Death/Assist ratio) from player stats
      #
      # @param stats [Array, ActiveRecord::Relation] Player statistics
      # @return [Float] Average KDA
      def calculate_avg_kda(stats)
        return 0.0 if stats.empty?

        total_kills = stats.try(:sum, :kills) || stats.sum(&:kills)
        total_deaths = stats.try(:sum, :deaths) || stats.sum(&:deaths)
        total_assists = stats.try(:sum, :assists) || stats.sum(&:assists)

        deaths = total_deaths.zero? ? 1 : total_deaths
        ((total_kills + total_assists).to_f / deaths).round(2)
      end
      module_function :calculate_avg_kda

      # Calculates KDA for a single set of stats
      #
      # @param kills [Integer] Number of kills
      # @param deaths [Integer] Number of deaths
      # @param assists [Integer] Number of assists
      # @return [Float] KDA ratio
      def calculate_kda(kills, deaths, assists)
        deaths_divisor = deaths.zero? ? 1 : deaths
        ((kills + assists).to_f / deaths_divisor).round(2)
      end
      module_function :calculate_kda

      # Generates win/loss form string (e.g., "WWLWL")
      #
      # @param matches [Array] Collection of matches
      # @return [String] Form string
      def calculate_recent_form(matches)
        matches.map { |m| m.victory? ? 'W' : 'L' }.join('')
      end
      module_function :calculate_recent_form

      # Calculates creep score per minute
      #
      # @param total_cs [Integer] Total creep score
      # @param game_duration_seconds [Integer] Game duration in seconds
      # @return [Float] CS per minute
      def calculate_cs_per_min(total_cs, game_duration_seconds)
        return 0.0 if game_duration_seconds.zero?

        (total_cs.to_f / (game_duration_seconds / 60.0)).round(1)
      end
      module_function :calculate_cs_per_min

      # Calculates gold earned per minute
      #
      # @param total_gold [Integer] Total gold earned
      # @param game_duration_seconds [Integer] Game duration in seconds
      # @return [Float] Gold per minute
      def calculate_gold_per_min(total_gold, game_duration_seconds)
        return 0.0 if game_duration_seconds.zero?

        (total_gold.to_f / (game_duration_seconds / 60.0)).round(0)
      end
      module_function :calculate_gold_per_min

      # Calculates damage dealt per minute
      #
      # @param total_damage [Integer] Total damage dealt
      # @param game_duration_seconds [Integer] Game duration in seconds
      # @return [Float] Damage per minute
      def calculate_damage_per_min(total_damage, game_duration_seconds)
        return 0.0 if game_duration_seconds.zero?

        (total_damage.to_f / (game_duration_seconds / 60.0)).round(0)
      end
      module_function :calculate_damage_per_min

      # Formats duration in seconds to MM:SS format
      #
      # @param duration_seconds [Integer] Duration in seconds
      # @return [String] Formatted duration
      def format_duration(duration_seconds)
        return '00:00' if duration_seconds.nil? || duration_seconds.zero?

        minutes = duration_seconds / 60
        seconds = duration_seconds % 60
        "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
      end
      module_function :format_duration

      # Calculates win rate trend over time
      #
      # @param matches [Array] Collection of matches
      # @param group_by [Symbol] Grouping period (:day, :week, :month)
      # @return [Array<Hash>] Trend data by period
      def calculate_win_rate_trend(matches, group_by: :week)
        grouped = matches.group_by do |match|
          case group_by
          when :day
            match.game_start.beginning_of_day
          when :month
            match.game_start.beginning_of_month
          else # :week
            match.game_start.beginning_of_week
          end
        end

        grouped.map do |period, period_matches|
          wins = period_matches.count(&:victory?)
          total = period_matches.size
          win_rate = total.zero? ? 0.0 : ((wins.to_f / total) * 100).round(1)

          {
            period: period.strftime('%Y-%m-%d'),
            matches: total,
            wins: wins,
            losses: total - wins,
            win_rate: win_rate
          }
        end.sort_by { |data| data[:period] }
      end
      module_function :calculate_win_rate_trend

      # Calculates performance statistics grouped by role
      #
      # @param matches [Array] Collection of matches
      # @param damage_field [Symbol] Damage field to use
      # @return [Array<Hash>] Performance data by role
      def calculate_performance_by_role(matches, damage_field: :damage_dealt_total)
        stats = PlayerMatchStat.joins(:player).where(match: matches)
        grouped_stats = group_stats_by_role(stats, damage_field)

        grouped_stats.map { |stat| format_role_stat(stat) }
      end
      module_function :calculate_performance_by_role

      class << self
        private

      def group_stats_by_role(stats, damage_field)
        stats.group('players.role').select(
          'players.role',
          'COUNT(*) as games',
          'AVG(player_match_stats.kills) as avg_kills',
          'AVG(player_match_stats.deaths) as avg_deaths',
          'AVG(player_match_stats.assists) as avg_assists',
          'AVG(player_match_stats.gold_earned) as avg_gold',
          "AVG(player_match_stats.#{damage_field}) as avg_damage",
          'AVG(player_match_stats.vision_score) as avg_vision'
        )
      end

      def format_role_stat(stat)
        {
          role: stat.role,
          games: stat.games,
          avg_kda: format_avg_kda(stat),
          avg_gold: stat.avg_gold&.round(0) || 0,
          avg_damage: stat.avg_damage&.round(0) || 0,
          avg_vision: stat.avg_vision&.round(1) || 0
        }
      end

      def format_avg_kda(stat)
        {
          kills: stat.avg_kills&.round(1) || 0,
          deaths: stat.avg_deaths&.round(1) || 0,
          assists: stat.avg_assists&.round(1) || 0
        }
      end
      end
    end
  end
end
