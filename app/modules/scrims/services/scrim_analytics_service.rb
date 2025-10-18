module Scrims
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
        win_rate: calculate_overall_win_rate(scrims),
        most_practiced_opponent: most_frequent_opponent(scrims),
        focus_areas: focus_area_breakdown(scrims),
        improvement_metrics: track_improvement(scrims),
        completion_rate: completion_rate(scrims)
      }
    end

    # Stats grouped by opponent
    def stats_by_opponent
      scrims = @organization.scrims.includes(:opponent_team)

      scrims.group(:opponent_team_id).map do |opponent_id, opponent_scrims|
        next if opponent_id.nil?

        opponent_team = OpponentTeam.find(opponent_id)
        {
          opponent_team: {
            id: opponent_team.id,
            name: opponent_team.name,
            tag: opponent_team.tag
          },
          total_scrims: opponent_scrims.size,
          total_games: opponent_scrims.sum(&:games_completed).to_i,
          win_rate: calculate_win_rate(opponent_scrims)
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
          win_rate: calculate_win_rate(area_scrims),
          avg_completion: average_completion_percentage(area_scrims)
        }
      end
    end

    # Performance against specific opponent
    def opponent_performance(opponent_team_id)
      scrims = @organization.scrims
                           .where(opponent_team_id: opponent_team_id)
                           .includes(:match)

      {
        head_to_head_record: calculate_record(scrims),
        total_games: scrims.sum(:games_completed),
        win_rate: calculate_win_rate(scrims),
        avg_game_duration: avg_duration(scrims),
        most_successful_comps: successful_compositions(scrims),
        improvement_over_time: performance_trend(scrims),
        last_5_results: last_n_results(scrims, 5)
      }
    end

    # Identify patterns in successful scrims
    def success_patterns
      winning_scrims = @organization.scrims.select { |s| s.win_rate > 50 }

      {
        best_focus_areas: best_performing_focus_areas(winning_scrims),
        best_time_of_day: best_performance_time_of_day(winning_scrims),
        optimal_games_count: optimal_games_per_scrim(winning_scrims),
        common_objectives: common_objectives_in_wins(winning_scrims)
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
        initial_win_rate: calculate_win_rate(first_quarter),
        recent_win_rate: calculate_win_rate(last_quarter),
        improvement_delta: calculate_win_rate(last_quarter) - calculate_win_rate(first_quarter),
        games_played_trend: games_played_trend(all_scrims),
        consistency_score: consistency_score(all_scrims)
      }
    end

    private

    def calculate_overall_win_rate(scrims)
      all_results = scrims.flat_map(&:game_results)
      return 0 if all_results.empty?

      wins = all_results.count { |result| result['victory'] == true }
      ((wins.to_f / all_results.size) * 100).round(2)
    end

    def calculate_win_rate(scrims)
      all_results = scrims.flat_map(&:game_results)
      return 0 if all_results.empty?

      wins = all_results.count { |result| result['victory'] == true }
      ((wins.to_f / all_results.size) * 100).round(2)
    end

    def calculate_record(scrims)
      all_results = scrims.flat_map(&:game_results)
      wins = all_results.count { |result| result['victory'] == true }
      losses = all_results.size - wins

      "#{wins}W - #{losses}L"
    end

    def most_frequent_opponent(scrims)
      opponent_counts = scrims.group_by(&:opponent_team_id).transform_values(&:count)
      most_frequent_id = opponent_counts.max_by { |_, count| count }&.first

      return nil if most_frequent_id.nil?

      opponent = OpponentTeam.find_by(id: most_frequent_id)
      opponent&.name
    end

    def focus_area_breakdown(scrims)
      scrims.where.not(focus_area: nil)
            .group(:focus_area)
            .count
    end

    def track_improvement(scrims)
      ordered_scrims = scrims.order(created_at: :asc)
      return {} if ordered_scrims.count < 10

      first_10 = ordered_scrims.limit(10)
      last_10 = ordered_scrims.last(10)

      {
        initial_win_rate: calculate_win_rate(first_10),
        recent_win_rate: calculate_win_rate(last_10),
        improvement: calculate_win_rate(last_10) - calculate_win_rate(first_10)
      }
    end

    def completion_rate(scrims)
      completed = scrims.select { |s| s.status == 'completed' }.count
      return 0 if scrims.count.zero?

      ((completed.to_f / scrims.count) * 100).round(2)
    end

    def avg_duration(scrims)
      results_with_duration = scrims.flat_map(&:game_results)
                                    .select { |r| r['duration'].present? }

      return 0 if results_with_duration.empty?

      avg_seconds = results_with_duration.sum { |r| r['duration'].to_i } / results_with_duration.size
      minutes = avg_seconds / 60
      seconds = avg_seconds % 60

      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end

    def successful_compositions(scrims)
      # This would require match data integration
      # For now, return placeholder
      []
    end

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

    def last_n_results(scrims, n)
      scrims.order(scheduled_at: :desc).limit(n).map do |scrim|
        {
          date: scrim.scheduled_at,
          win_rate: scrim.win_rate,
          games_played: scrim.games_completed,
          focus_area: scrim.focus_area
        }
      end
    end

    def best_performing_focus_areas(scrims)
      scrims.group_by(&:focus_area)
            .transform_values { |s| calculate_win_rate(s) }
            .sort_by { |_, wr| -wr }
            .first(3)
            .to_h
    end

    def best_performance_time_of_day(scrims)
      by_hour = scrims.group_by { |s| s.scheduled_at&.hour }

      by_hour.transform_values { |s| calculate_win_rate(s) }
             .sort_by { |_, wr| -wr }
             .first&.first
    end

    def optimal_games_per_scrim(scrims)
      by_games = scrims.group_by(&:games_planned)

      by_games.transform_values { |s| calculate_win_rate(s) }
              .sort_by { |_, wr| -wr }
              .first&.first
    end

    def common_objectives_in_wins(scrims)
      objectives = scrims.flat_map { |s| s.objectives.keys }
      objectives.tally.sort_by { |_, count| -count }.first(5).to_h
    end

    def games_played_trend(scrims)
      scrims.group_by { |s| s.created_at.beginning_of_week }
            .transform_values { |s| s.sum(&:games_completed) }
    end

    def consistency_score(scrims)
      win_rates = scrims.map(&:win_rate)
      return 0 if win_rates.empty?

      mean = win_rates.sum / win_rates.size
      variance = win_rates.sum { |wr| (wr - mean)**2 } / win_rates.size
      std_dev = Math.sqrt(variance)

      # Lower std_dev = more consistent (convert to 0-100 scale)
      [100 - std_dev, 0].max.round(2)
    end

    def average_completion_percentage(scrims)
      percentages = scrims.map(&:completion_percentage)
      return 0 if percentages.empty?

      (percentages.sum / percentages.size).round(2)
    end
  end
end
