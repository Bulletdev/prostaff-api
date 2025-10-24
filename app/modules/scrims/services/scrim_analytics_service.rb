# frozen_string_literal: true

module Scrims
  module Services
    # Service for calculating scrim analytics
    # Delegates pure calculations to Scrims::Utilities::AnalyticsCalculator
    class ScrimAnalyticsService
      def initialize(organization)
        @organization = organization
      end

      # Overall scrim statistics
      def overall_stats(date_range: 30.days)
        scrims = @organization.scrims.where('created_at > ?', date_range.ago)

        {
          total_scrims: scrims.count,
          total_games: scrims.sum(:games_completed),
          win_rate: calculator.calculate_win_rate(scrims),
          most_practiced_opponent: calculator.most_frequent_opponent(scrims),
          focus_areas: focus_area_breakdown(scrims),
          improvement_metrics: track_improvement(scrims),
          completion_rate: calculator.completion_rate(scrims)
        }
      end

      # Stats grouped by opponent
      def stats_by_opponent
        scrims = @organization.scrims.includes(:opponent_team).to_a

        scrims.group_by(&:opponent_team_id).map do |opponent_id, opponent_scrims|
          next unless opponent_id

          opponent_team = OpponentTeam.find(opponent_id)
          {
            opponent_team: {
              id: opponent_team.id,
              name: opponent_team.name,
              tag: opponent_team.tag
            },
            total_scrims: opponent_scrims.size,
            total_games: opponent_scrims.sum(&:games_completed).to_i,
            win_rate: calculator.calculate_win_rate(opponent_scrims)
          }
        end.compact
      end

      # Stats grouped by focus area
      def stats_by_focus_area
        scrims = @organization.scrims.where.not(focus_area: nil)

        scrims.group_by(&:focus_area).transform_values do |area_scrims|
          {
            total_scrims: area_scrims.size,
            total_games: area_scrims.sum(&:games_completed).to_i,
            win_rate: calculator.calculate_win_rate(area_scrims),
            avg_completion: calculator.average_completion_percentage(area_scrims)
          }
        end
      end

      # Performance against specific opponent
      def opponent_performance(opponent_team_id)
        scrims = @organization.scrims
                              .where(opponent_team_id: opponent_team_id)
                              .includes(:match)

        {
          head_to_head_record: calculator.calculate_record(scrims),
          total_games: scrims.sum(:games_completed),
          win_rate: calculator.calculate_win_rate(scrims),
          avg_game_duration: calculator.avg_duration(scrims),
          most_successful_comps: successful_compositions(scrims),
          improvement_over_time: calculator.performance_trend(scrims),
          last_5_results: calculator.last_n_results(scrims, 5)
        }
      end

      # Identify patterns in successful scrims
      def success_patterns
        winning_scrims = @organization.scrims.select { |s| s.win_rate > 50 }

        {
          best_focus_areas: calculator.best_performing_focus_areas(winning_scrims),
          best_time_of_day: calculator.best_performance_time_of_day(winning_scrims),
          optimal_games_count: calculator.optimal_games_per_scrim(winning_scrims),
          common_objectives: calculator.common_objectives_in_wins(winning_scrims)
        }
      end

      # Track improvement trends over time
      def improvement_trends
        all_scrims = @organization.scrims.order(created_at: :asc)

        return {} if all_scrims.count < 10

        # Split into time periods
        first_quarter = all_scrims.limit(all_scrims.count / 4)
        last_quarter = all_scrims.last(all_scrims.count / 4)

        {
          initial_win_rate: calculator.calculate_win_rate(first_quarter),
          recent_win_rate: calculator.calculate_win_rate(last_quarter),
          improvement_delta: calculator.calculate_win_rate(last_quarter) - calculator.calculate_win_rate(first_quarter),
          games_played_trend: calculator.games_played_trend(all_scrims),
          consistency_score: calculator.consistency_score(all_scrims)
        }
      end

      private

      # Returns the calculator utility module
      def calculator
        @calculator ||= Scrims::Utilities::AnalyticsCalculator
      end

      # Breaks down scrims by focus area
      def focus_area_breakdown(scrims)
        scrims.where.not(focus_area: nil)
              .group(:focus_area)
              .count
      end

      # Tracks improvement metrics between early and recent scrims
      def track_improvement(scrims)
        ordered_scrims = scrims.order(created_at: :asc)
        return {} if ordered_scrims.count < 10

        first_10 = ordered_scrims.limit(10)
        last_10 = ordered_scrims.last(10)

        {
          initial_win_rate: calculator.calculate_win_rate(first_10),
          recent_win_rate: calculator.calculate_win_rate(last_10),
          improvement: calculator.calculate_win_rate(last_10) - calculator.calculate_win_rate(first_10)
        }
      end

      # Placeholder for composition analysis (requires match data)
      def successful_compositions(_scrims)
        []
      end
    end
  end
end
