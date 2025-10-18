# frozen_string_literal: true

module Analytics
  module Concerns
    # Shared utility methods for analytics calculations
    # Used across controllers and services to avoid code duplication
    module AnalyticsCalculations
      extend ActiveSupport::Concern

      # Calculates win rate percentage from a collection of matches
      #
      # @param matches [ActiveRecord::Relation, Array] Collection of Match records
      # @return [Float] Win rate as percentage (0-100), or 0 if no matches
      #
      # @example
      #   calculate_win_rate(Match.where(organization: org))
      #   # => 65.5
      def calculate_win_rate(matches)
        return 0.0 if matches.empty?

        total = matches.respond_to?(:count) ? matches.count : matches.size
        wins = matches.respond_to?(:victories) ? matches.victories.count : matches.count(&:victory?)

        ((wins.to_f / total) * 100).round(1)
      end

      # Calculates average KDA (Kill/Death/Assist ratio) from player stats
      #
      # @param stats [ActiveRecord::Relation, Array] Collection of PlayerMatchStat records
      # @return [Float] Average KDA ratio, or 0 if no stats
      #
      # @example
      #   calculate_avg_kda(PlayerMatchStat.where(match: matches))
      #   # => 3.25
      def calculate_avg_kda(stats)
        return 0.0 if stats.empty?

        total_kills = stats.respond_to?(:sum) ? stats.sum(:kills) : stats.sum(&:kills)
        total_deaths = stats.respond_to?(:sum) ? stats.sum(:deaths) : stats.sum(&:deaths)
        total_assists = stats.respond_to?(:sum) ? stats.sum(:assists) : stats.sum(&:assists)

        deaths = total_deaths.zero? ? 1 : total_deaths
        ((total_kills + total_assists).to_f / deaths).round(2)
      end

      # Calculates KDA for a specific set of kills, deaths, and assists
      #
      # @param kills [Integer] Number of kills
      # @param deaths [Integer] Number of deaths
      # @param assists [Integer] Number of assists
      # @return [Float] KDA ratio
      #
      # @example
      #   calculate_kda(10, 5, 15)
      #   # => 5.0
      def calculate_kda(kills, deaths, assists)
        deaths_divisor = deaths.zero? ? 1 : deaths
        ((kills + assists).to_f / deaths_divisor).round(2)
      end

      # Formats recent match results as a string (e.g., "WWLWL")
      #
      # @param matches [Array<Match>] Collection of matches (should be ordered)
      # @return [String] String of W/L characters representing wins/losses
      #
      # @example
      #   calculate_recent_form(recent_matches)
      #   # => "WWLWW"
      def calculate_recent_form(matches)
        matches.map { |m| m.victory? ? 'W' : 'L' }.join('')
      end

      # Calculates CS (creep score) per minute
      #
      # @param total_cs [Integer] Total minions killed
      # @param game_duration_seconds [Integer] Game duration in seconds
      # @return [Float] CS per minute, or 0 if duration is 0
      #
      # @example
      #   calculate_cs_per_min(300, 1800)
      #   # => 10.0
      def calculate_cs_per_min(total_cs, game_duration_seconds)
        return 0.0 if game_duration_seconds.zero?

        (total_cs.to_f / (game_duration_seconds / 60.0)).round(1)
      end

      # Calculates gold per minute
      #
      # @param total_gold [Integer] Total gold earned
      # @param game_duration_seconds [Integer] Game duration in seconds
      # @return [Float] Gold per minute, or 0 if duration is 0
      #
      # @example
      #   calculate_gold_per_min(15000, 1800)
      #   # => 500.0
      def calculate_gold_per_min(total_gold, game_duration_seconds)
        return 0.0 if game_duration_seconds.zero?

        (total_gold.to_f / (game_duration_seconds / 60.0)).round(0)
      end

      # Calculates damage per minute
      #
      # @param total_damage [Integer] Total damage dealt
      # @param game_duration_seconds [Integer] Game duration in seconds
      # @return [Float] Damage per minute, or 0 if duration is 0
      def calculate_damage_per_min(total_damage, game_duration_seconds)
        return 0.0 if game_duration_seconds.zero?

        (total_damage.to_f / (game_duration_seconds / 60.0)).round(0)
      end

      # Formats game duration from seconds to MM:SS format
      #
      # @param duration_seconds [Integer] Duration in seconds
      # @return [String] Formatted duration string
      #
      # @example
      #   format_duration(1845)
      #   # => "30:45"
      def format_duration(duration_seconds)
        return '00:00' if duration_seconds.nil? || duration_seconds.zero?

        minutes = duration_seconds / 60
        seconds = duration_seconds % 60
        "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
      end

      # Calculates win rate trend grouped by time period
      #
      # @param matches [ActiveRecord::Relation] Collection of Match records
      # @param group_by [Symbol] Time period to group by (:week, :day, :month)
      # @return [Array<Hash>] Array of hashes with period, matches, wins, losses, win_rate
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
    end
  end
end
