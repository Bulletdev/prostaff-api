class Api::V1::Analytics::TeamComparisonController < Api::V1::BaseController
  def index
    players = organization_scoped(Player).active.includes(:player_match_stats)

    # Get matches in date range
    matches = organization_scoped(Match)
    if params[:start_date].present? && params[:end_date].present?
      matches = matches.in_date_range(params[:start_date], params[:end_date])
    else
      matches = matches.recent(30)
    end

    comparison_data = {
      players: players.map do |player|
        stats = PlayerMatchStat.where(player: player, match: matches)
        next if stats.empty?

        {
          player: PlayerSerializer.render_as_hash(player),
          games_played: stats.count,
          kda: calculate_kda(stats),
          avg_damage: stats.average(:total_damage_dealt)&.round(0) || 0,
          avg_gold: stats.average(:gold_earned)&.round(0) || 0,
          avg_cs: stats.average('minions_killed + jungle_minions_killed')&.round(1) || 0,
          avg_vision_score: stats.average(:vision_score)&.round(1) || 0,
          avg_performance_score: stats.average(:performance_score)&.round(1) || 0,
          multikills: {
            double: stats.sum(:double_kills),
            triple: stats.sum(:triple_kills),
            quadra: stats.sum(:quadra_kills),
            penta: stats.sum(:penta_kills)
          }
        }
      end.compact.sort_by { |p| -p[:avg_performance_score] },
      team_averages: calculate_team_averages(matches),
      role_rankings: calculate_role_rankings(players, matches)
    }

    render_success(comparison_data)
  end

  private

  def calculate_kda(stats)
    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)

    deaths = total_deaths.zero? ? 1 : total_deaths
    ((total_kills + total_assists).to_f / deaths).round(2)
  end

  def calculate_team_averages(matches)
    all_stats = PlayerMatchStat.where(match: matches)

    {
      avg_kda: calculate_kda(all_stats),
      avg_damage: all_stats.average(:total_damage_dealt)&.round(0) || 0,
      avg_gold: all_stats.average(:gold_earned)&.round(0) || 0,
      avg_cs: all_stats.average('minions_killed + jungle_minions_killed')&.round(1) || 0,
      avg_vision_score: all_stats.average(:vision_score)&.round(1) || 0
    }
  end

  def calculate_role_rankings(players, matches)
    rankings = {}

    %w[top jungle mid adc support].each do |role|
      role_players = players.where(role: role)
      role_data = role_players.map do |player|
        stats = PlayerMatchStat.where(player: player, match: matches)
        next if stats.empty?

        {
          player_id: player.id,
          summoner_name: player.summoner_name,
          avg_performance: stats.average(:performance_score)&.round(1) || 0,
          games: stats.count
        }
      end.compact.sort_by { |p| -p[:avg_performance] }

      rankings[role] = role_data
    end

    rankings
  end
end
