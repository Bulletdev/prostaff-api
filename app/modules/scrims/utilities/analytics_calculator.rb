# frozen_string_literal: true

module Scrims
  module Utilities
    # Pure calculation utilities for scrim analytics
    # All methods are stateless and can be called as module functions
    #
    # @example
    #   Scrims::Utilities::AnalyticsCalculator.calculate_win_rate(scrims)
    module AnalyticsCalculator
      extend self

      # Calculates win rate from scrim game results
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Float] Win rate percentage
      def calculate_win_rate(scrims)
        all_results = scrims.flat_map(&:game_results)
        return 0 if all_results.empty?

        wins = all_results.count { |result| result['victory'] == true }
        ((wins.to_f / all_results.size) * 100).round(2)
      end

      # Formats record as "XW - YL" string
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [String] Formatted record
      def calculate_record(scrims)
        all_results = scrims.flat_map(&:game_results)
        wins = all_results.count { |result| result['victory'] == true }
        losses = all_results.size - wins

        "#{wins}W - #{losses}L"
      end

      # Finds most frequent opponent from scrims
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [String, nil] Opponent team name or nil
      def most_frequent_opponent(scrims)
        opponent_counts = scrims.group_by(&:opponent_team_id).transform_values(&:count)
        most_frequent_id = opponent_counts.max_by { |_, count| count }&.first

        return nil unless most_frequent_id

        opponent = OpponentTeam.find_by(id: most_frequent_id)
        opponent&.name
      end

      # Calculates completion rate of scrims
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Float] Completion rate percentage
      def completion_rate(scrims)
        completed = scrims.count { |s| s.status == 'completed' }
        return 0 if scrims.none?

        ((completed.to_f / scrims.count) * 100).round(2)
      end

      # Calculates average game duration
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [String] Formatted duration (MM:SS)
      def avg_duration(scrims)
        results_with_duration = scrims.flat_map(&:game_results)
                                      .select { |r| r['duration'].present? }

        return '00:00' if results_with_duration.empty?

        avg_seconds = results_with_duration.sum { |r| r['duration'].to_i } / results_with_duration.size
        format_duration(avg_seconds)
      end

      # Returns last N scrim results
      #
      # @param scrims [ActiveRecord::Relation] Scrim relation
      # @param limit [Integer] Number of results to return
      # @return [Array<Hash>] Last N results
      def last_n_results(scrims, limit)
        scrims.order(scheduled_at: :desc).limit(limit).map do |scrim|
          {
            date: scrim.scheduled_at,
            win_rate: scrim.win_rate,
            games_played: scrim.games_completed,
            focus_area: scrim.focus_area
          }
        end
      end

      # Finds best performing focus areas
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Hash] Top 3 focus areas with win rates
      def best_performing_focus_areas(scrims)
        scrims.group_by(&:focus_area)
              .transform_values { |s| calculate_win_rate(s) }
              .sort_by { |_, wr| -wr }
              .first(3)
              .to_h
      end

      # Finds best time of day for performance
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Integer, nil] Hour with best win rate
      def best_performance_time_of_day(scrims)
        by_hour = scrims.group_by { |s| s.scheduled_at&.hour }

        by_hour.transform_values { |s| calculate_win_rate(s) }
               .max_by { |_, wr| wr }
               &.first
      end

      # Finds optimal number of games per scrim
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Integer, nil] Optimal games count
      def optimal_games_per_scrim(scrims)
        by_games = scrims.group_by(&:games_planned)

        by_games.transform_values { |s| calculate_win_rate(s) }
                .max_by { |_, wr| wr }
                &.first
      end

      # Finds common objectives in winning scrims
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Hash] Top 5 objectives with counts
      def common_objectives_in_wins(scrims)
        objectives = scrims.flat_map { |s| s.objectives.keys }
        objectives.tally.sort_by { |_, count| -count }.first(5).to_h
      end

      # Calculates games played trend by week
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Hash] Games played by week
      def games_played_trend(scrims)
        scrims.group_by { |s| s.created_at.beginning_of_week }
              .transform_values { |s| s.sum { |scrim| scrim.games_completed || 0 } }
      end

      # Calculates consistency score (0-100, higher = more consistent)
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Float] Consistency score
      def consistency_score(scrims)
        win_rates = scrims.map(&:win_rate)
        return 0 if win_rates.empty?

        mean = win_rates.sum / win_rates.size
        variance = win_rates.sum { |wr| (wr - mean)**2 } / win_rates.size
        std_dev = Math.sqrt(variance)

        # Lower std_dev = more consistent (convert to 0-100 scale)
        [100 - std_dev, 0].max.round(2)
      end

      # Calculates average completion percentage
      #
      # @param scrims [Array<Scrim>] Collection of scrims
      # @return [Float] Average completion percentage
      def average_completion_percentage(scrims)
        percentages = scrims.map(&:completion_percentage)
        return 0 if percentages.empty?

        (percentages.sum / percentages.size).round(2)
      end

      # Calculates performance trend over groups of scrims
      #
      # @param scrims [ActiveRecord::Relation] Ordered scrim relation
      # @return [Array<Hash>] Trend data
      def performance_trend(scrims)
        ordered = scrims.order(scheduled_at: :asc)
        return [] if ordered.count < 3

        ordered.each_cons(3).map do |group|
          {
            date_range: "#{group.first.scheduled_at.to_date} - #{group.last.scheduled_at.to_date}",
            win_rate: calculate_win_rate(group)
          }
        end
      end

      private

      # Formats duration in seconds to MM:SS
      #
      # @param seconds [Integer] Duration in seconds
      # @return [String] Formatted duration
      def format_duration(seconds)
        minutes = seconds / 60
        secs = seconds % 60
        "#{minutes}:#{secs.to_s.rjust(2, '0')}"
      end
    end
  end
end
