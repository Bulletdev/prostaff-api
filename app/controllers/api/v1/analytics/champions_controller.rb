class Api::V1::Analytics::ChampionsController < Api::V1::BaseController
  def show
    player = organization_scoped(Player).find(params[:player_id])

    stats = PlayerMatchStat.where(player: player)
                          .group(:champion)
                          .select(
                            'champion',
                            'COUNT(*) as games_played',
                            'SUM(CASE WHEN matches.victory THEN 1 ELSE 0 END) as wins',
                            'AVG((kills + assists)::float / NULLIF(deaths, 0)) as avg_kda'
                          )
                          .joins(:match)
                          .order('games_played DESC')

    champion_stats = stats.map do |stat|
      win_rate = stat.games_played.zero? ? 0 : (stat.wins.to_f / stat.games_played)
      {
        champion: stat.champion,
        games_played: stat.games_played,
        win_rate: win_rate,
        avg_kda: stat.avg_kda&.round(2) || 0,
        mastery_grade: calculate_mastery_grade(win_rate, stat.avg_kda)
      }
    end

    champion_data = {
      player: PlayerSerializer.render_as_hash(player),
      champion_stats: champion_stats,
      top_champions: champion_stats.take(5),
      champion_diversity: {
        total_champions: champion_stats.count,
        highly_played: champion_stats.count { |c| c[:games_played] >= 10 },
        average_games: champion_stats.empty? ? 0 : (champion_stats.sum { |c| c[:games_played] } / champion_stats.count.to_f).round(1)
      }
    }

    render_success(champion_data)
  end

  private

  def calculate_mastery_grade(win_rate, avg_kda)
    score = (win_rate * 100 * 0.6) + ((avg_kda || 0) * 10 * 0.4)

    case score
    when 80..Float::INFINITY then 'S'
    when 70...80 then 'A'
    when 60...70 then 'B'
    when 50...60 then 'C'
    else 'D'
    end
  end
end
