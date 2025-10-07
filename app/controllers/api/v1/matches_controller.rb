class Api::V1::MatchesController < Api::V1::BaseController
  before_action :set_match, only: [:show, :update, :destroy, :stats]

  def index
    matches = organization_scoped(Match).includes(:player_match_stats, :players)

    # Apply filters
    matches = matches.by_type(params[:match_type]) if params[:match_type].present?
    matches = matches.victories if params[:result] == 'victory'
    matches = matches.defeats if params[:result] == 'defeat'

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      matches = matches.in_date_range(params[:start_date], params[:end_date])
    elsif params[:days].present?
      matches = matches.recent(params[:days].to_i)
    end

    # Opponent filter
    matches = matches.with_opponent(params[:opponent]) if params[:opponent].present?

    # Tournament filter
    if params[:tournament].present?
      matches = matches.where('tournament_name ILIKE ?', "%#{params[:tournament]}%")
    end

    # Sorting
    sort_by = params[:sort_by] || 'game_start'
    sort_order = params[:sort_order] || 'desc'
    matches = matches.order("#{sort_by} #{sort_order}")

    # Pagination
    result = paginate(matches)

    render_success({
      matches: MatchSerializer.render_as_hash(result[:data]),
      pagination: result[:pagination],
      summary: calculate_matches_summary(matches)
    })
  end

  def show
    match_data = MatchSerializer.render_as_hash(@match)
    player_stats = PlayerMatchStatSerializer.render_as_hash(
      @match.player_match_stats.includes(:player)
    )

    render_success({
      match: match_data,
      player_stats: player_stats,
      team_composition: @match.team_composition,
      mvp: @match.mvp_player ? PlayerSerializer.render_as_hash(@match.mvp_player) : nil
    })
  end

  def create
    match = organization_scoped(Match).new(match_params)
    match.organization = current_organization

    if match.save
      log_user_action(
        action: 'create',
        entity_type: 'Match',
        entity_id: match.id,
        new_values: match.attributes
      )

      render_created({
        match: MatchSerializer.render_as_hash(match)
      }, message: 'Match created successfully')
    else
      render_error(
        message: 'Failed to create match',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: match.errors.as_json
      )
    end
  end

  def update
    old_values = @match.attributes.dup

    if @match.update(match_params)
      log_user_action(
        action: 'update',
        entity_type: 'Match',
        entity_id: @match.id,
        old_values: old_values,
        new_values: @match.attributes
      )

      render_updated({
        match: MatchSerializer.render_as_hash(@match)
      })
    else
      render_error(
        message: 'Failed to update match',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: @match.errors.as_json
      )
    end
  end

  def destroy
    if @match.destroy
      log_user_action(
        action: 'delete',
        entity_type: 'Match',
        entity_id: @match.id,
        old_values: @match.attributes
      )

      render_deleted(message: 'Match deleted successfully')
    else
      render_error(
        message: 'Failed to delete match',
        code: 'DELETE_ERROR',
        status: :unprocessable_entity
      )
    end
  end

  def stats
    # Detailed statistics for a single match
    stats = @match.player_match_stats.includes(:player)

    stats_data = {
      match: MatchSerializer.render_as_hash(@match),
      team_stats: calculate_team_stats(stats),
      player_stats: stats.map do |stat|
        player_data = PlayerMatchStatSerializer.render_as_hash(stat)
        player_data[:player] = PlayerSerializer.render_as_hash(stat.player)
        player_data
      end,
      comparison: {
        total_gold: stats.sum(:gold_earned),
        total_damage: stats.sum(:total_damage_dealt),
        total_vision_score: stats.sum(:vision_score),
        avg_kda: calculate_avg_kda(stats)
      }
    }

    render_success(stats_data)
  end

  def import
    player_id = params[:player_id]
    count = params[:count]&.to_i || 20

    unless player_id.present?
      return render_error(
        message: 'player_id is required',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity
      )
    end

    player = organization_scoped(Player).find(player_id)

    unless player.riot_puuid.present?
      return render_error(
        message: 'Player does not have a Riot PUUID. Please sync player from Riot first.',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity
      )
    end

    begin
      riot_service = RiotApiService.new
      region = player.region || 'BR'

      match_ids = riot_service.get_match_history(
        puuid: player.riot_puuid,
        region: region,
        count: count
      )

      imported_count = 0
      match_ids.each do |match_id|
        # Check if match already exists
        next if Match.exists?(riot_match_id: match_id)

        SyncMatchJob.perform_later(match_id, current_organization.id, region)
        imported_count += 1
      end

      render_success({
        message: "Queued #{imported_count} matches for import",
        total_matches_found: match_ids.count,
        already_imported: match_ids.count - imported_count,
        player: PlayerSerializer.render_as_hash(player)
      })

    rescue RiotApiService::RiotApiError => e
      render_error(
        message: "Failed to fetch matches from Riot API: #{e.message}",
        code: 'RIOT_API_ERROR',
        status: :bad_gateway
      )
    rescue StandardError => e
      render_error(
        message: "Failed to import matches: #{e.message}",
        code: 'IMPORT_ERROR',
        status: :internal_server_error
      )
    end
  end

  private

  def set_match
    @match = organization_scoped(Match).find(params[:id])
  end

  def match_params
    params.require(:match).permit(
      :match_type, :game_start, :game_end, :game_duration,
      :riot_match_id, :patch_version, :tournament_name, :stage,
      :opponent_name, :opponent_tag, :victory,
      :our_side, :our_score, :opponent_score,
      :first_blood, :first_tower, :first_baron, :first_dragon,
      :total_kills, :total_deaths, :total_assists, :total_gold,
      :vod_url, :replay_file_url, :notes
    )
  end

  def calculate_matches_summary(matches)
    {
      total: matches.count,
      victories: matches.victories.count,
      defeats: matches.defeats.count,
      win_rate: calculate_win_rate(matches),
      by_type: matches.group(:match_type).count,
      avg_duration: matches.average(:game_duration)&.round(0)
    }
  end

  def calculate_win_rate(matches)
    return 0 if matches.empty?
    ((matches.victories.count.to_f / matches.count) * 100).round(1)
  end

  def calculate_team_stats(stats)
    {
      total_kills: stats.sum(:kills),
      total_deaths: stats.sum(:deaths),
      total_assists: stats.sum(:assists),
      total_gold: stats.sum(:gold_earned),
      total_damage: stats.sum(:total_damage_dealt),
      total_cs: stats.sum(:minions_killed),
      total_vision_score: stats.sum(:vision_score)
    }
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
