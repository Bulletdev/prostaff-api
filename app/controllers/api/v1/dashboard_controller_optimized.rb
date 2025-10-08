# OPTIMIZED VERSION - in validation, dont send to production
class Api::V1::DashboardController < Api::V1::BaseController
  def stats
    cache_key = "dashboard_stats_#{current_organization.id}_#{current_organization.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      calculate_stats
    end
  end

  private

  def calculate_stats
    matches = organization_scoped(Match)
              .recent(30)
              .includes(:player_match_stats)

    matches_array = matches.to_a
    players = organization_scoped(Player).active

    match_stats = matches_array.group_by(&:victory?)
    wins = match_stats[true]&.size || 0
    losses = match_stats[false]&.size || 0

    kda_result = PlayerMatchStat
                 .where(match_id: matches_array.map(&:id))
                 .select('SUM(kills) as total_kills, SUM(deaths) as total_deaths, SUM(assists) as total_assists')
                 .first

    goal_counts = organization_scoped(TeamGoal).group(:status).count

    {
      total_players: players.count,
      active_players: players.where(status: 'active').count,
      total_matches: matches_array.size,
      wins: wins,
      losses: losses,
      win_rate: calculate_win_rate_fast(wins, matches_array.size),
      recent_form: calculate_recent_form(matches_array.first(5)),
      avg_kda: calculate_average_kda_fast(kda_result),
      active_goals: goal_counts['active'] || 0,
      completed_goals: goal_counts['completed'] || 0,
      upcoming_matches: organization_scoped(Schedule)
                        .where('start_time >= ? AND event_type = ?', Time.current, 'match')
                        .count
    }
  end

  def calculate_win_rate_fast(wins, total)
    return 0 if total.zero?
    ((wins.to_f / total) * 100).round(1)
  end

  def calculate_recent_form(matches)
    matches.map { |m| m.victory? ? 'W' : 'L' }.join('')
  end

  def calculate_average_kda_fast(kda_result)
    return 0 unless kda_result

    total_kills = kda_result.total_kills || 0
    total_deaths = kda_result.total_deaths || 0
    total_assists = kda_result.total_assists || 0

    deaths = total_deaths.zero? ? 1 : total_deaths
    ((total_kills + total_assists).to_f / deaths).round(2)
  end

  def roster_status_data
    players = organization_scoped(Player).includes(:champion_pools)

    players_array = players.to_a

    {
      by_role: players_array.group_by(&:role).transform_values(&:count),
      by_status: players_array.group_by(&:status).transform_values(&:count),
      contracts_expiring: players.contracts_expiring_soon.count
    }
  end
end
