class Api::V1::DashboardController < Api::V1::BaseController
  def index
    dashboard_data = {
      stats: calculate_stats,
      recent_matches: recent_matches_data,
      upcoming_events: upcoming_events_data,
      active_goals: active_goals_data,
      roster_status: roster_status_data
    }

    render_success(dashboard_data)
  end

  def stats
    render_success(calculate_stats)
  end

  def activities
    recent_activities = fetch_recent_activities

    render_success({
      activities: recent_activities,
      count: recent_activities.size
    })
  end

  def schedule
    events = organization_scoped(Schedule)
             .where('start_time >= ?', Time.current)
             .order(start_time: :asc)
             .limit(10)

    render_success({
      events: ScheduleSerializer.render_as_hash(events),
      count: events.size
    })
  end

  private

  def calculate_stats
    matches = organization_scoped(Match).recent(30)
    players = organization_scoped(Player).active

    {
      total_players: players.count,
      active_players: players.where(status: 'active').count,
      total_matches: matches.count,
      wins: matches.victories.count,
      losses: matches.defeats.count,
      win_rate: calculate_win_rate(matches),
      recent_form: calculate_recent_form(matches.order(game_start: :desc).limit(5)),
      avg_kda: calculate_average_kda(matches),
      active_goals: organization_scoped(TeamGoal).active.count,
      completed_goals: organization_scoped(TeamGoal).where(status: 'completed').count,
      upcoming_matches: organization_scoped(Schedule).where('start_time >= ? AND event_type = ?', Time.current, 'match').count
    }
  end

  def calculate_win_rate(matches)
    return 0 if matches.empty?
    ((matches.victories.count.to_f / matches.count) * 100).round(1)
  end

  def calculate_recent_form(matches)
    matches.map { |m| m.victory? ? 'W' : 'L' }.join('')
  end

  def calculate_average_kda(matches)
    stats = PlayerMatchStat.where(match: matches)
    return 0 if stats.empty?

    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)

    deaths = total_deaths.zero? ? 1 : total_deaths
    ((total_kills + total_assists).to_f / deaths).round(2)
  end

  def recent_matches_data
    matches = organization_scoped(Match)
              .order(game_start: :desc)
              .limit(5)

    MatchSerializer.render_as_hash(matches)
  end

  def upcoming_events_data
    events = organization_scoped(Schedule)
             .where('start_time >= ?', Time.current)
             .order(start_time: :asc)
             .limit(5)

    ScheduleSerializer.render_as_hash(events)
  end

  def active_goals_data
    goals = organization_scoped(TeamGoal)
            .active
            .order(end_date: :asc)
            .limit(5)

    TeamGoalSerializer.render_as_hash(goals)
  end

  def roster_status_data
    players = organization_scoped(Player).includes(:champion_pools)

    {
      by_role: players.group(:role).count,
      by_status: players.group(:status).count,
      contracts_expiring: players.contracts_expiring_soon.count
    }
  end

  def fetch_recent_activities
    # Fetch recent audit logs and format them
    activities = AuditLog
                 .where(organization: current_organization)
                 .order(created_at: :desc)
                 .limit(20)

    activities.map do |log|
      {
        id: log.id,
        action: log.action,
        entity_type: log.entity_type,
        entity_id: log.entity_id,
        user: log.user&.email,
        timestamp: log.created_at,
        changes: summarize_changes(log)
      }
    end
  end

  def summarize_changes(log)
    return nil unless log.new_values.present?

    # Only show important field changes
    important_fields = %w[status role summoner_name title victory]
    changes = log.new_values.slice(*important_fields)

    return nil if changes.empty?
    changes
  end
end
