class Api::V1::Analytics::TeamfightsController < Api::V1::BaseController
  def show
    player = organization_scoped(Player).find(params[:player_id])

    stats = PlayerMatchStat.joins(:match)
                          .where(player: player, match: { organization: current_organization })
                          .order('matches.game_start DESC')
                          .limit(20)

    teamfight_data = {
      player: PlayerSerializer.render_as_hash(player),
      damage_performance: {
        avg_damage_dealt: stats.average(:total_damage_dealt)&.round(0),
        avg_damage_taken: stats.average(:total_damage_taken)&.round(0),
        best_damage_game: stats.maximum(:total_damage_dealt),
        avg_damage_per_min: calculate_avg_damage_per_min(stats)
      },
      participation: {
        avg_kills: stats.average(:kills)&.round(1),
        avg_assists: stats.average(:assists)&.round(1),
        avg_deaths: stats.average(:deaths)&.round(1),
        multikill_stats: {
          double_kills: stats.sum(:double_kills),
          triple_kills: stats.sum(:triple_kills),
          quadra_kills: stats.sum(:quadra_kills),
          penta_kills: stats.sum(:penta_kills)
        }
      },
      by_match: stats.map do |stat|
        {
          match_id: stat.match.id,
          date: stat.match.game_start,
          kills: stat.kills,
          deaths: stat.deaths,
          assists: stat.assists,
          damage_dealt: stat.total_damage_dealt,
          damage_taken: stat.total_damage_taken,
          multikills: stat.double_kills + stat.triple_kills + stat.quadra_kills + stat.penta_kills,
          champion: stat.champion,
          victory: stat.match.victory
        }
      end
    }

    render_success(teamfight_data)
  end

  private

  def calculate_avg_damage_per_min(stats)
    total_damage = 0
    total_minutes = 0

    stats.each do |stat|
      if stat.match.game_duration && stat.total_damage_dealt
        total_damage += stat.total_damage_dealt
        total_minutes += stat.match.game_duration / 60.0
      end
    end

    return 0 if total_minutes.zero?
    (total_damage / total_minutes).round(0)
  end
end
