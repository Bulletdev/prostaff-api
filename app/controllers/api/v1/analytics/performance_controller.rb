class Api::V1::Analytics::PerformanceController < Api::V1::BaseController
  def index
    # Team performance analytics
    matches = organization_scoped(Match)
    players = organization_scoped(Player).active

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      matches = matches.in_date_range(params[:start_date], params[:end_date])
    else
      matches = matches.recent(30) # Default to last 30 days
    end

    performance_data = {
      overview: calculate_team_overview(matches),
      win_rate_trend: calculate_win_rate_trend(matches),
      performance_by_role: calculate_performance_by_role(matches),
      best_performers: identify_best_performers(players, matches),
      match_type_breakdown: calculate_match_type_breakdown(matches)
    }

    render_success(performance_data)
  end

  private

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
      avg_damage_per_game: stats.average(:total_damage_dealt)&.round(0),
      avg_vision_score: stats.average(:vision_score)&.round(1)
    }
  end

  def calculate_win_rate_trend(matches)
    # Calculate win rate for each week
    matches.group_by { |m| m.game_start.beginning_of_week }.map do |week, week_matches|
      wins = week_matches.count(&:victory?)
      total = week_matches.size
      win_rate = total.zero? ? 0 : ((wins.to_f / total) * 100).round(1)

      {
        week: week.strftime('%Y-%m-%d'),
        matches: total,
        wins: wins,
        losses: total - wins,
        win_rate: win_rate
      }
    end.sort_by { |d| d[:week] }
  end

  def calculate_performance_by_role(matches)
    stats = PlayerMatchStat.joins(:player).where(match: matches)

    stats.group('players.role').select(
      'players.role',
      'COUNT(*) as games',
      'AVG(player_match_stats.kills) as avg_kills',
      'AVG(player_match_stats.deaths) as avg_deaths',
      'AVG(player_match_stats.assists) as avg_assists',
      'AVG(player_match_stats.gold_earned) as avg_gold',
      'AVG(player_match_stats.total_damage_dealt) as avg_damage',
      'AVG(player_match_stats.vision_score) as avg_vision'
    ).map do |stat|
      {
        role: stat.role,
        games: stat.games,
        avg_kda: {
          kills: stat.avg_kills&.round(1) || 0,
          deaths: stat.avg_deaths&.round(1) || 0,
          assists: stat.avg_assists&.round(1) || 0
        },
        avg_gold: stat.avg_gold&.round(0) || 0,
        avg_damage: stat.avg_damage&.round(0) || 0,
        avg_vision: stat.avg_vision&.round(1) || 0
      }
    end
  end

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

  def calculate_win_rate(matches)
    return 0 if matches.empty?
    ((matches.victories.count.to_f / matches.count) * 100).round(1)
  end

  def calculate_avg_kda(stats)
    return 0 if stats.empty?

    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)

    deaths = total_deaths.zero? ? 1 : total_deaths
    ((total_kills + total_assists).to_f / deaths).round(2)
  end
end
