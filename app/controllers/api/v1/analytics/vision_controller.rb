class Api::V1::Analytics::VisionController < Api::V1::BaseController
  def show
    player = organization_scoped(Player).find(params[:player_id])

    stats = PlayerMatchStat.joins(:match)
                          .where(player: player, match: { organization: current_organization })
                          .order('matches.game_start DESC')
                          .limit(20)

    vision_data = {
      player: PlayerSerializer.render_as_hash(player),
      vision_stats: {
        avg_vision_score: stats.average(:vision_score)&.round(1),
        avg_wards_placed: stats.average(:wards_placed)&.round(1),
        avg_wards_killed: stats.average(:wards_killed)&.round(1),
        best_vision_game: stats.maximum(:vision_score),
        total_wards_placed: stats.sum(:wards_placed),
        total_wards_killed: stats.sum(:wards_killed)
      },
      vision_per_min: calculate_avg_vision_per_min(stats),
      by_match: stats.map do |stat|
        {
          match_id: stat.match.id,
          date: stat.match.game_start,
          vision_score: stat.vision_score,
          wards_placed: stat.wards_placed,
          wards_killed: stat.wards_killed,
          champion: stat.champion,
          role: stat.role,
          victory: stat.match.victory
        }
      end,
      role_comparison: calculate_role_comparison(player)
    }

    render_success(vision_data)
  end

  private

  def calculate_avg_vision_per_min(stats)
    total_vision = 0
    total_minutes = 0

    stats.each do |stat|
      if stat.match.game_duration && stat.vision_score
        total_vision += stat.vision_score
        total_minutes += stat.match.game_duration / 60.0
      end
    end

    return 0 if total_minutes.zero?
    (total_vision / total_minutes).round(2)
  end

  def calculate_role_comparison(player)
    # Compare player's vision score to team average for same role
    team_stats = PlayerMatchStat.joins(:player)
                                .where(players: { organization: current_organization, role: player.role })
                                .where.not(players: { id: player.id })

    player_stats = PlayerMatchStat.where(player: player)

    {
      player_avg: player_stats.average(:vision_score)&.round(1) || 0,
      role_avg: team_stats.average(:vision_score)&.round(1) || 0,
      percentile: calculate_percentile(player_stats.average(:vision_score), team_stats)
    }
  end

  def calculate_percentile(player_avg, team_stats)
    return 0 if player_avg.nil? || team_stats.empty?

    all_averages = team_stats.group(:player_id).average(:vision_score).values
    all_averages << player_avg
    all_averages.sort!

    rank = all_averages.index(player_avg) + 1
    ((rank.to_f / all_averages.size) * 100).round(0)
  end
end
