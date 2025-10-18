# Performance Analytics Controller
#
# Provides endpoints for viewing team and player performance metrics.
# Delegates complex calculations to PerformanceAnalyticsService.
#
# Features:
# - Team overview statistics (wins, losses, KDA, etc.)
# - Win rate trends over time
# - Performance breakdown by role
# - Top performer identification
# - Individual player statistics
#
# @example Get team performance for last 30 days
#   GET /api/v1/analytics/performance
#
# @example Get performance with player stats
#   GET /api/v1/analytics/performance?player_id=123
#
class Api::V1::Analytics::PerformanceController < Api::V1::BaseController
  include Analytics::Concerns::AnalyticsCalculations

  # Returns performance analytics for the organization
  #
  # Supports filtering by date range and includes individual player stats if requested.
  #
  # GET /api/v1/analytics/performance
  #
  # @param start_date [Date] Start date for filtering (optional)
  # @param end_date [Date] End date for filtering (optional)
  # @param time_period [String] Predefined period: week, month, or season (optional)
  # @param player_id [Integer] Player ID for individual stats (optional)
  # @return [JSON] Performance analytics data
  def index
    matches = apply_date_filters(organization_scoped(Match))
    players = organization_scoped(Player).active

    service = Analytics::Services::PerformanceAnalyticsService.new(matches, players)
    performance_data = service.calculate_performance_data(player_id: params[:player_id])

    render_success(performance_data)
  end

  private

  # Applies date range filters to matches based on params
  #
  # @param matches [ActiveRecord::Relation] Matches relation to filter
  # @return [ActiveRecord::Relation] Filtered matches
  def apply_date_filters(matches)
    if params[:start_date].present? && params[:end_date].present?
      matches.in_date_range(params[:start_date], params[:end_date])
    elsif params[:time_period].present?
      days = time_period_to_days(params[:time_period])
      matches.where('game_start >= ?', days.days.ago)
    else
      matches.recent(30) # Default to last 30 days
    end
  end

  # Converts time period string to number of days
  #
  # @param period [String] Time period (week, month, season)
  # @return [Integer] Number of days
  def time_period_to_days(period)
    case period
    when 'week' then 7
    when 'month' then 30
    when 'season' then 90
    else 30
    end
  end

  # Legacy method - kept for backwards compatibility
  # TODO: Remove after migrating all callers to PerformanceAnalyticsService
  def calculate_team_overview(matches)
    stats = PlayerMatchStat.where(match: matches)

    {
      total_matches: matches.count,
      wins: matches.victories.count,
      losses: matches.defeats.count,
      win_rate: calculate_win_rate(matches),
      avg_game_duration: matches.average(:game_duration)&.round(0),
      avg_kda: calculate_avg_kda(stats),
      avg_kills_per_game: stats.average(:kills)&.round(1),
      avg_deaths_per_game: stats.average(:deaths)&.round(1),
      avg_assists_per_game: stats.average(:assists)&.round(1),
      avg_gold_per_game: stats.average(:gold_earned)&.round(0),
      avg_damage_per_game: stats.average(:damage_dealt_total)&.round(0),
      avg_vision_score: stats.average(:vision_score)&.round(1)
    }
  end

  # Legacy methods - moved to PerformanceAnalyticsService and AnalyticsCalculations
  # These methods now delegate to the concern
  # TODO: Remove after confirming no external dependencies

  def identify_best_performers(players, matches)
    players.map do |player|
      stats = PlayerMatchStat.where(player: player, match: matches)
      next if stats.empty?

      {
        player: PlayerSerializer.render_as_hash(player),
        games: stats.count,
        avg_kda: calculate_avg_kda(stats),
        avg_performance_score: stats.average(:performance_score)&.round(1) || 0,
        mvp_count: stats.joins(:match).where(matches: { victory: true }).count
      }
    end.compact.sort_by { |p| -p[:avg_performance_score] }.take(5)
  end

  def calculate_match_type_breakdown(matches)
    matches.group(:match_type).select(
      'match_type',
      'COUNT(*) as total',
      'SUM(CASE WHEN victory THEN 1 ELSE 0 END) as wins'
    ).map do |stat|
      win_rate = stat.total.zero? ? 0 : ((stat.wins.to_f / stat.total) * 100).round(1)
      {
        match_type: stat.match_type,
        total: stat.total,
        wins: stat.wins,
        losses: stat.total - stat.wins,
        win_rate: win_rate
      }
    end
  end

  # Methods moved to Analytics::Concerns::AnalyticsCalculations:
  # - calculate_win_rate
  # - calculate_avg_kda

  def calculate_player_stats(player, matches)
    stats = PlayerMatchStat.where(player: player, match: matches)

    return nil if stats.empty?

    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)
    games_played = stats.count

    # Calculate win rate as decimal (0-1) for frontend
    wins = stats.joins(:match).where(matches: { victory: true }).count
    win_rate = games_played.zero? ? 0.0 : (wins.to_f / games_played)

    # Calculate KDA
    deaths = total_deaths.zero? ? 1 : total_deaths
    kda = ((total_kills + total_assists).to_f / deaths).round(2)

    # Calculate CS per min
    total_cs = stats.sum(:cs)
    total_duration = matches.where(id: stats.pluck(:match_id)).sum(:game_duration)
    cs_per_min = calculate_cs_per_min(total_cs, total_duration)

    # Calculate gold per min
    total_gold = stats.sum(:gold_earned)
    gold_per_min = calculate_gold_per_min(total_gold, total_duration)

    # Calculate vision score
    vision_score = stats.average(:vision_score)&.round(1) || 0.0

    {
      player_id: player.id,
      summoner_name: player.summoner_name,
      games_played: games_played,
      win_rate: win_rate,
      kda: kda,
      cs_per_min: cs_per_min,
      gold_per_min: gold_per_min,
      vision_score: vision_score,
      damage_share: 0.0, # Would need total team damage to calculate
      avg_kills: (total_kills.to_f / games_played).round(1),
      avg_deaths: (total_deaths.to_f / games_played).round(1),
      avg_assists: (total_assists.to_f / games_played).round(1)
    }
  end
end
