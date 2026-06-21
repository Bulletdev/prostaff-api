# frozen_string_literal: true

module Goals
  # Resolves the current value for a TeamGoal's metric_key from the appropriate data source.
  #
  # Acts as the only boundary-crossing service between the goals module and the
  # analytics/players/scraper data layers. No other code in goals/ should query
  # player_match_stats or player_rank_snapshots directly.
  #
  # Returns nil when:
  #   - The goal has no player assigned
  #   - The metric_key is blank or manual (manual check-ins are user-submitted only)
  #   - The scraper is unavailable (UnavailableError is rescued; other errors propagate)
  #
  # @example
  #   value = Goals::MetricResolver.new(goal).resolve
  #   GoalCheckIn.create!(team_goal: goal, measured_value: value, source: 'auto') if value
  class MetricResolver
    SOLOQ_QUEUE = 'RANKED_SOLO_5x5'

    def initialize(goal)
      @goal = goal
      @player = goal.player
    end

    # @return [Float, nil]
    def resolve
      return nil unless @player && @goal.metric_key.present?
      return nil if MetricRegistry.manual?(@goal.metric_key)

      case MetricRegistry.source_for(@goal.metric_key)
      when :rails_analytics then resolve_from_analytics
      when :rank_snapshot   then resolve_from_rank_snapshot
      when :scraper         then resolve_from_scraper
      end
    end

    private

    # Aggregates player_match_stats in the goal's date window.
    def resolve_from_analytics
      stats, match_ids = fetch_player_stats
      return nil if stats.none?

      compute_analytics_value(stats, match_ids)
    end

    def fetch_player_stats
      match_ids = player_match_scope.select(:id)
      stats = PlayerMatchStat.where(player_id: @player.id, match_id: match_ids)
      [stats, match_ids]
    end

    def player_match_scope
      Match
        .where(organization: @player.organization)
        .joins(:player_match_stats)
        .where(player_match_stats: { player_id: @player.id })
        .where(game_start: window_datetime_range)
    end

    def compute_analytics_value(stats, match_ids)
      {
        'kda_ratio' => -> { compute_kda(stats) },
        'cs_per_min' => -> { avg_stat(stats, :cs_per_min) },
        'vision_score_per_min' => -> { compute_vision_per_min(stats, match_ids) },
        'gold_per_min' => -> { avg_stat(stats, :gold_per_min) },
        'damage_per_min' => -> { compute_damage_per_min(stats, match_ids) },
        'kill_participation' => -> { avg_stat(stats, :kill_participation) },
        'win_rate' => -> { compute_win_rate(stats) }
      }[@goal.metric_key]&.call
    end

    def avg_stat(stats, column)
      stats.average(column)&.to_f&.round(2)
    end

    # Reads the latest solo queue snapshot — no HTTP needed.
    def resolve_from_rank_snapshot
      snapshot = PlayerRankSnapshot
                 .where(player_id: @player.id, queue_type: SOLOQ_QUEUE)
                 .order(recorded_on: :desc)
                 .first

      return nil unless snapshot

      case @goal.metric_key
      when 'soloq_lp_total' then lp_total(snapshot)
      when 'soloq_win_rate' then soloq_win_rate(snapshot)
      end
    end

    # Calls ProStaffScraperService — requires player.professional_name.
    def resolve_from_scraper
      return nil unless @player.professional_name.present?

      scraper = ProStaffScraperService.new
      profile = scraper.fetch_player_profile(name: @player.professional_name)

      return nil if profile['total_games'].to_i.zero?

      extract_scraper_metric(profile)
    rescue ProStaffScraperService::UnavailableError => e
      Rails.logger.warn("[MetricResolver] scraper unavailable player=#{@player.id} error=#{e.message}")
      nil
    end

    # --- analytics helpers ---

    def compute_kda(stats)
      kills   = stats.sum(:kills).to_f
      deaths  = stats.sum(:deaths).to_f
      assists = stats.sum(:assists).to_f
      divisor = deaths.zero? ? 1.0 : deaths
      ((kills + assists) / divisor).round(2)
    end

    def compute_vision_per_min(stats, match_ids)
      total_vision  = stats.sum(:vision_score).to_f
      total_seconds = Match.where(id: match_ids).sum(:game_duration).to_f
      return nil if total_seconds.zero?

      (total_vision / (total_seconds / 60.0)).round(2)
    end

    def compute_damage_per_min(stats, match_ids)
      total_dmg     = stats.sum(:damage_dealt_champions).to_f
      total_seconds = Match.where(id: match_ids).sum(:game_duration).to_f
      return nil if total_seconds.zero?

      (total_dmg / (total_seconds / 60.0)).round(2)
    end

    def compute_win_rate(stats)
      total = stats.count
      return nil if total.zero?

      wins = stats.joins(:match).where(matches: { victory: true }).count
      (wins.to_f / total * 100).round(2)
    end

    # --- rank_snapshot helpers ---

    def lp_total(snapshot)
      tier_lp = tier_base_lp(snapshot.tier) + division_base_lp(snapshot.rank)
      (tier_lp + snapshot.league_points.to_i).to_f
    end

    def soloq_win_rate(snapshot)
      total = snapshot.wins.to_i + snapshot.losses.to_i
      return nil if total.zero?

      (snapshot.wins.to_f / total * 100).round(2)
    end

    def tier_base_lp(tier)
      tiers = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER]
      tiers.index(tier.to_s.upcase).to_i * 400
    end

    def division_base_lp(rank)
      divisions = { 'IV' => 0, 'III' => 100, 'II' => 200, 'I' => 300 }
      divisions[rank.to_s.upcase] || 0
    end

    # --- scraper helpers ---

    def extract_scraper_metric(profile)
      case @goal.metric_key
      when 'pro_kda' then profile['avg_kda']&.to_f
      when 'pro_cs_per_min', 'pro_dpm', 'pro_gd15', 'pro_wpm'
        extract_tournament_metric(profile)
      end
    end

    # Tournament-level metrics (DPM, GD15, WPM, CSPM) are not in the player profile
    # endpoint. They require fetch_tournament_stats. We fall back to nil and log a
    # warning — callers can create a manual check-in for these until the scraper
    # exposes them per-player in the profile endpoint.
    def extract_tournament_metric(_profile)
      Rails.logger.info(
        "[MetricResolver] #{@goal.metric_key} requires tournament context — " \
        "skipping auto-resolve for player=#{@player.id}"
      )
      nil
    end

    def window_datetime_range
      start_date = @goal.start_date || 90.days.ago.to_date
      end_date   = @goal.due_date || @goal.end_date || Date.current
      (start_date.beginning_of_day..end_date.end_of_day)
    end
  end
end
