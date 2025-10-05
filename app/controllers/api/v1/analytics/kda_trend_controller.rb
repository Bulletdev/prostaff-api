class Api::V1::Analytics::KdaTrendController < Api::V1::BaseController
  def show
    player = organization_scoped(Player).find(params[:player_id])

    # Get recent matches for the player
    stats = PlayerMatchStat.joins(:match)
                          .where(player: player, match: { organization: current_organization })
                          .order('matches.game_start DESC')
                          .limit(50)
                          .includes(:match)

    trend_data = {
      player: PlayerSerializer.render_as_hash(player),
      kda_by_match: stats.map do |stat|
        kda = stat.deaths.zero? ? (stat.kills + stat.assists).to_f : ((stat.kills + stat.assists).to_f / stat.deaths)
        {
          match_id: stat.match.id,
          date: stat.match.game_start,
          kills: stat.kills,
          deaths: stat.deaths,
          assists: stat.assists,
          kda: kda.round(2),
          champion: stat.champion,
          victory: stat.match.victory
        }
      end,
      averages: {
        last_10_games: calculate_kda_average(stats.limit(10)),
        last_20_games: calculate_kda_average(stats.limit(20)),
        overall: calculate_kda_average(stats)
      }
    }

    render_success(trend_data)
  end

  private

  def calculate_kda_average(stats)
    return 0 if stats.empty?

    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)

    deaths = total_deaths.zero? ? 1 : total_deaths
    ((total_kills + total_assists).to_f / deaths).round(2)
  end
end
