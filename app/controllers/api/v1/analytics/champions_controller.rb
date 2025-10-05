class Api::V1::Analytics::ChampionsController < Api::V1::BaseController
  def show
    player = organization_scoped(Player).find(params[:player_id])
    champion_pools = player.champion_pools.order(games_played: :desc)

    champion_data = {
      player: PlayerSerializer.render_as_hash(player),
      champion_pool: ChampionPoolSerializer.render_as_hash(champion_pools),
      top_champions: champion_pools.limit(5).map do |pool|
        {
          champion: pool.champion,
          games: pool.games_played,
          win_rate: pool.wins.to_f / pool.games_played * 100,
          avg_kda: pool.average_kda,
          mastery: pool.mastery_level
        }
      end,
      champion_diversity: {
        total_champions: champion_pools.count,
        highly_played: champion_pools.where('games_played >= ?', 10).count,
        mastery_points: champion_pools.sum(:mastery_points)
      }
    }

    render_success(champion_data)
  end
end
