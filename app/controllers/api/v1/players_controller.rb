class Api::V1::PlayersController < Api::V1::BaseController
  before_action :set_player, only: [:show, :update, :destroy, :stats, :matches]

  def index
    players = organization_scoped(Player).includes(:champion_pools)

    # Apply filters
    players = players.by_role(params[:role]) if params[:role].present?
    players = players.by_status(params[:status]) if params[:status].present?

    # Apply search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      players = players.where('summoner_name ILIKE ? OR real_name ILIKE ?', search_term, search_term)
    end

    # Pagination
    result = paginate(players.order(:role, :summoner_name))

    render_success({
      players: PlayerSerializer.render_as_hash(result[:data]),
      pagination: result[:pagination]
    })
  end

  def show
    render_success({
      player: PlayerSerializer.render_as_hash(@player)
    })
  end

  def create
    player = organization_scoped(Player).new(player_params)
    player.organization = current_organization

    if player.save
      log_user_action(
        action: 'create',
        entity_type: 'Player',
        entity_id: player.id,
        new_values: player.attributes
      )

      render_created({
        player: PlayerSerializer.render_as_hash(player)
      }, message: 'Player created successfully')
    else
      render_error(
        message: 'Failed to create player',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: player.errors.as_json
      )
    end
  end

  def update
    old_values = @player.attributes.dup

    if @player.update(player_params)
      log_user_action(
        action: 'update',
        entity_type: 'Player',
        entity_id: @player.id,
        old_values: old_values,
        new_values: @player.attributes
      )

      render_updated({
        player: PlayerSerializer.render_as_hash(@player)
      })
    else
      render_error(
        message: 'Failed to update player',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: @player.errors.as_json
      )
    end
  end

  def destroy
    if @player.destroy
      log_user_action(
        action: 'delete',
        entity_type: 'Player',
        entity_id: @player.id,
        old_values: @player.attributes
      )

      render_deleted(message: 'Player deleted successfully')
    else
      render_error(
        message: 'Failed to delete player',
        code: 'DELETE_ERROR',
        status: :unprocessable_entity
      )
    end
  end

  def stats
    # Get player statistics
    matches = @player.matches.order(game_start: :desc)
    recent_matches = matches.limit(20)
    player_stats = PlayerMatchStat.where(player: @player, match: matches)

    stats_data = {
      player: PlayerSerializer.render_as_hash(@player),
      overall: {
        total_matches: matches.count,
        wins: matches.victories.count,
        losses: matches.defeats.count,
        win_rate: calculate_player_win_rate(matches),
        avg_kda: calculate_player_avg_kda(player_stats),
        avg_cs: player_stats.average(:minions_killed)&.round(1) || 0,
        avg_vision_score: player_stats.average(:vision_score)&.round(1) || 0,
        avg_damage: player_stats.average(:total_damage_dealt)&.round(0) || 0
      },
      recent_form: {
        last_5_matches: calculate_recent_form(recent_matches.limit(5)),
        last_10_matches: calculate_recent_form(recent_matches.limit(10))
      },
      champion_pool: ChampionPoolSerializer.render_as_hash(
        @player.champion_pools.order(games_played: :desc).limit(5)
      ),
      performance_by_role: calculate_performance_by_role(player_stats)
    }

    render_success(stats_data)
  end

  def matches
    matches = @player.matches
              .includes(:player_match_stats)
              .order(game_start: :desc)

    # Filter by date range if provided
    if params[:start_date].present? && params[:end_date].present?
      matches = matches.in_date_range(params[:start_date], params[:end_date])
    end

    result = paginate(matches)

    # Include player stats for each match
    matches_with_stats = result[:data].map do |match|
      player_stat = match.player_match_stats.find_by(player: @player)
      {
        match: MatchSerializer.render_as_hash(match),
        player_stats: player_stat ? PlayerMatchStatSerializer.render_as_hash(player_stat) : nil
      }
    end

    render_success({
      matches: matches_with_stats,
      pagination: result[:pagination]
    })
  end

  def import
    # This will be implemented when Riot API is ready
    render_error(
      message: 'Import functionality not yet implemented',
      code: 'NOT_IMPLEMENTED',
      status: :not_implemented
    )
  end

  private

  def set_player
    @player = organization_scoped(Player).find(params[:id])
  end

  def player_params
    params.require(:player).permit(
      :summoner_name, :real_name, :role, :status, :jersey_number,
      :birth_date, :country, :nationality,
      :contract_start_date, :contract_end_date,
      :solo_queue_tier, :solo_queue_rank, :solo_queue_lp,
      :solo_queue_wins, :solo_queue_losses,
      :flex_queue_tier, :flex_queue_rank, :flex_queue_lp,
      :peak_tier, :peak_rank, :peak_season,
      :riot_puuid, :riot_summoner_id,
      :twitter_handle, :twitch_channel, :instagram_handle,
      :notes
    )
  end

  def calculate_player_win_rate(matches)
    return 0 if matches.empty?
    ((matches.victories.count.to_f / matches.count) * 100).round(1)
  end

  def calculate_player_avg_kda(stats)
    return 0 if stats.empty?

    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)

    deaths = total_deaths.zero? ? 1 : total_deaths
    ((total_kills + total_assists).to_f / deaths).round(2)
  end

  def calculate_recent_form(matches)
    matches.map { |m| m.victory? ? 'W' : 'L' }
  end

  def calculate_performance_by_role(stats)
    stats.group(:role).select(
      'role',
      'COUNT(*) as games',
      'AVG(kills) as avg_kills',
      'AVG(deaths) as avg_deaths',
      'AVG(assists) as avg_assists',
      'AVG(performance_score) as avg_performance'
    ).map do |stat|
      {
        role: stat.role,
        games: stat.games,
        avg_kda: {
          kills: stat.avg_kills&.round(1) || 0,
          deaths: stat.avg_deaths&.round(1) || 0,
          assists: stat.avg_assists&.round(1) || 0
        },
        avg_performance: stat.avg_performance&.round(1) || 0
      }
    end
  end
end
