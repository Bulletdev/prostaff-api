class Api::V1::PlayersController < Api::V1::BaseController
  before_action :set_player, only: [:show, :update, :destroy, :stats, :matches, :sync_from_riot]

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

    # Pagination - order by role (top, jungle, mid, adc, support) then by name
    result = paginate(players.ordered_by_role.order(:summoner_name))

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
    summoner_name = params[:summoner_name]&.strip
    role = params[:role]
    region = params[:region] || 'br1'

    # Validate required params
    unless summoner_name.present? && role.present?
      return render_error(
        message: 'Summoner name and role are required',
        code: 'MISSING_PARAMETERS',
        status: :unprocessable_entity,
        details: {
          hint: 'Format: "GameName#TAG" or "GameName-TAG" (e.g., "Faker#KR1" or "Faker-KR1")'
        }
      )
    end

    # Validate role
    unless %w[top jungle mid adc support].include?(role)
      return render_error(
        message: 'Invalid role',
        code: 'INVALID_ROLE',
        status: :unprocessable_entity
      )
    end

    # Check if player already exists
    existing_player = organization_scoped(Player).find_by(summoner_name: summoner_name)
    if existing_player
      return render_error(
        message: 'Player already exists in your organization',
        code: 'PLAYER_EXISTS',
        status: :unprocessable_entity
      )
    end

    # Get Riot API key
    riot_api_key = ENV['RIOT_API_KEY']
    unless riot_api_key.present?
      return render_error(
        message: 'Riot API key not configured',
        code: 'RIOT_API_NOT_CONFIGURED',
        status: :service_unavailable
      )
    end

    begin
      # Try to fetch summoner data from Riot API with multiple tag variations
      summoner_data = nil
      game_name, tag_line = parse_riot_id(summoner_name, region)

      # Try different tag variations
      tag_variations = [
        tag_line,                    # Original parsed tag (e.g., 'FLP' from 'veigh baby uhh-flp')
        tag_line&.downcase,          # lowercase (e.g., 'flp')
        tag_line&.upcase,            # UPPERCASE (e.g., 'FLP')
        tag_line&.capitalize,        # Capitalized (e.g., 'Flp')
        region.upcase,               # BR1
        region[0..1].upcase,         # BR
        'BR1', 'BRSL', 'BR', 'br1', 'LAS', 'LAN'  # Common tags
      ].compact.uniq

      last_error = nil
      account_data = nil
      tag_variations.each do |tag|
        begin
          Rails.logger.info "Trying Riot ID: #{game_name}##{tag}"
          account_data = fetch_summoner_by_riot_id(game_name, tag, region, riot_api_key)

          puuid = account_data['puuid']
          summoner_data = fetch_summoner_by_puuid(puuid, region, riot_api_key)

          summoner_name = "#{account_data['gameName']}##{account_data['tagLine']}"

          Rails.logger.info "✅ Found player: #{summoner_name}"
          break
        rescue => e
          last_error = e
          Rails.logger.debug "Tag '#{tag}' failed: #{e.message}"
          next
        end
      end

      unless summoner_data
        raise "Player not found. Tried: #{tag_variations.map { |t| "#{game_name}##{t}" }.join(', ')}. Original error: #{last_error&.message}"
      end

      ranked_data = fetch_ranked_stats(summoner_data['puuid'], region, riot_api_key)

      player_data = {
        summoner_name: summoner_name,
        role: role,
        region: region,
        status: 'active',
        riot_puuid: summoner_data['puuid'],
        riot_summoner_id: summoner_data['id'],
        summoner_level: summoner_data['summonerLevel'],
        profile_icon_id: summoner_data['profileIconId'],
        sync_status: 'success',
        last_sync_at: Time.current
      }

      solo_queue = ranked_data.find { |q| q['queueType'] == 'RANKED_SOLO_5x5' }
      if solo_queue
        player_data.merge!({
          solo_queue_tier: solo_queue['tier'],
          solo_queue_rank: solo_queue['rank'],
          solo_queue_lp: solo_queue['leaguePoints'],
          solo_queue_wins: solo_queue['wins'],
          solo_queue_losses: solo_queue['losses']
        })
      end

      flex_queue = ranked_data.find { |q| q['queueType'] == 'RANKED_FLEX_SR' }
      if flex_queue
        player_data.merge!({
          flex_queue_tier: flex_queue['tier'],
          flex_queue_rank: flex_queue['rank'],
          flex_queue_lp: flex_queue['leaguePoints']
        })
      end

      player = organization_scoped(Player).create!(player_data)

      log_user_action(
        action: 'import_riot',
        entity_type: 'Player',
        entity_id: player.id,
        new_values: player_data
      )

      render_created({
        player: PlayerSerializer.render_as_hash(player),
        message: "Player #{summoner_name} imported successfully from Riot API"
      })

    rescue ActiveRecord::RecordInvalid => e
      render_error(
        message: "Failed to create player: #{e.message}",
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity
      )
    rescue StandardError => e
      Rails.logger.error "Riot API import error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render_error(
        message: "Failed to import from Riot API: #{e.message}",
        code: 'RIOT_API_ERROR',
        status: :service_unavailable
      )
    end
  end

  def sync_from_riot
    # Check if player has riot_puuid or summoner_name
    unless @player.riot_puuid.present? || @player.summoner_name.present?
      return render_error(
        message: 'Player must have either Riot PUUID or summoner name to sync',
        code: 'MISSING_RIOT_INFO',
        status: :unprocessable_entity
      )
    end

    # Get Riot API key from environment
    riot_api_key = ENV['RIOT_API_KEY']
    unless riot_api_key.present?
      return render_error(
        message: 'Riot API key not configured',
        code: 'RIOT_API_NOT_CONFIGURED',
        status: :service_unavailable
      )
    end

    begin
      # If we have PUUID, get summoner info by PUUID
      # If not, get summoner by name first to get PUUID
      region = params[:region] || 'br1'

      if @player.riot_puuid.present?
        summoner_data = fetch_summoner_by_puuid(@player.riot_puuid, region, riot_api_key)
      else
        summoner_data = fetch_summoner_by_name(@player.summoner_name, region, riot_api_key)
      end

      # Get ranked stats using PUUID
      ranked_data = fetch_ranked_stats(summoner_data['puuid'], region, riot_api_key)

      # Update player with fresh data
      update_data = {
        riot_puuid: summoner_data['puuid'],
        riot_summoner_id: summoner_data['id']
      }

      # Update ranked stats if available
      solo_queue = ranked_data.find { |q| q['queueType'] == 'RANKED_SOLO_5x5' }
      if solo_queue
        update_data.merge!({
          solo_queue_tier: solo_queue['tier'],
          solo_queue_rank: solo_queue['rank'],
          solo_queue_lp: solo_queue['leaguePoints'],
          solo_queue_wins: solo_queue['wins'],
          solo_queue_losses: solo_queue['losses']
        })
      end

      flex_queue = ranked_data.find { |q| q['queueType'] == 'RANKED_FLEX_SR' }
      if flex_queue
        update_data.merge!({
          flex_queue_tier: flex_queue['tier'],
          flex_queue_rank: flex_queue['rank'],
          flex_queue_lp: flex_queue['leaguePoints']
        })
      end

      update_data[:sync_status] = 'success'
      update_data[:last_sync_at] = Time.current

      @player.update!(update_data)

      log_user_action(
        action: 'sync_riot',
        entity_type: 'Player',
        entity_id: @player.id,
        new_values: update_data
      )

      render_success({
        player: PlayerSerializer.render_as_hash(@player),
        message: 'Player synced successfully from Riot API'
      })

    rescue StandardError => e
      Rails.logger.error "Riot API sync error: #{e.message}"

      # Update sync status to error
      @player.update(sync_status: 'error', last_sync_at: Time.current)

      render_error(
        message: "Failed to sync with Riot API: #{e.message}",
        code: 'RIOT_API_ERROR',
        status: :service_unavailable
      )
    end
  end

  def search_riot_id
    summoner_name = params[:summoner_name]&.strip
    region = params[:region] || 'br1'

    unless summoner_name.present?
      return render_error(
        message: 'Summoner name is required',
        code: 'MISSING_PARAMETERS',
        status: :unprocessable_entity
      )
    end

    riot_api_key = ENV['RIOT_API_KEY']
    unless riot_api_key.present?
      return render_error(
        message: 'Riot API key not configured',
        code: 'RIOT_API_NOT_CONFIGURED',
        status: :service_unavailable
      )
    end

    begin
      # Parse the summoner name
      game_name, tag_line = parse_riot_id(summoner_name, region)

      # If tagline was provided, try exact match first
      if summoner_name.include?('#') || summoner_name.include?('-')
        begin
          summoner_data = fetch_summoner_by_riot_id(game_name, tag_line, region, riot_api_key)
          return render_success({
            found: true,
            game_name: summoner_data['gameName'],
            tag_line: summoner_data['tagLine'],
            puuid: summoner_data['puuid'],
            riot_id: "#{summoner_data['gameName']}##{summoner_data['tagLine']}"
          })
        rescue => e
          Rails.logger.info "Exact match failed: #{e.message}"
        end
      end

      # Try common tagline variations
      common_tags = [
        tag_line,                    # Original parsed tag
        tag_line&.downcase,          # lowercase
        tag_line&.upcase,            # UPPERCASE
        tag_line&.capitalize,        # Capitalized
        region.upcase,               # BR1
        region[0..1].upcase,         # BR
        'BR1', 'BRSL', 'BR', 'br1', 'LAS', 'LAN'  # Common tags
      ].compact.uniq

      results = []
      common_tags.each do |tag|
        begin
          summoner_data = fetch_summoner_by_riot_id(game_name, tag, region, riot_api_key)
          results << {
            game_name: summoner_data['gameName'],
            tag_line: summoner_data['tagLine'],
            puuid: summoner_data['puuid'],
            riot_id: "#{summoner_data['gameName']}##{summoner_data['tagLine']}"
          }
          break
        rescue => e
          Rails.logger.debug "Tag '#{tag}' not found: #{e.message}"
          next
        end
      end

      if results.any?
        render_success({
          found: true,
          **results.first,
          message: "Player found! Use this Riot ID: #{results.first[:riot_id]}"
        })
      else
        render_error(
          message: "Player not found. Tried game name '#{game_name}' with tags: #{common_tags.join(', ')}",
          code: 'PLAYER_NOT_FOUND',
          status: :not_found,
          details: {
            game_name: game_name,
            tried_tags: common_tags,
            hint: 'Please verify the exact Riot ID in the League client (Settings > Account > Riot ID)'
          }
        )
      end

    rescue StandardError => e
      Rails.logger.error "Riot ID search error: #{e.message}"
      render_error(
        message: "Failed to search Riot ID: #{e.message}",
        code: 'SEARCH_ERROR',
        status: :service_unavailable
      )
    end
  end

  def bulk_sync
    status = params[:status] || 'active'

    # Get players to sync
    players = organization_scoped(Player).where(status: status)

    if players.empty?
      return render_error(
        message: "No #{status} players found to sync",
        code: 'NO_PLAYERS_FOUND',
        status: :not_found
      )
    end

    # Check if Riot API is configured
    riot_api_key = ENV['RIOT_API_KEY']
    unless riot_api_key.present?
      return render_error(
        message: 'Riot API key not configured',
        code: 'RIOT_API_NOT_CONFIGURED',
        status: :service_unavailable
      )
    end

    # Queue all players for sync (mark as syncing)
    players.update_all(sync_status: 'syncing')

    # Perform sync in background
    players.each do |player|
      SyncPlayerFromRiotJob.perform_later(player.id)
    end

    render_success({
      message: "#{players.count} players queued for sync",
      players_count: players.count
    })
  end

  private

  def set_player
    @player = organization_scoped(Player).find(params[:id])
  end

  def parse_riot_id(summoner_name, region)
    if summoner_name.include?('#')
      game_name, tag_line = summoner_name.split('#', 2)
    elsif summoner_name.include?('-')
      parts = summoner_name.rpartition('-')
      game_name = parts[0]
      tag_line = parts[2]
    else
      game_name = summoner_name
      tag_line = nil
    end

    tag_line ||= region.upcase
    tag_line = tag_line.strip.upcase if tag_line

    [game_name, tag_line]
  end
  def riot_url_encode(string)
    URI.encode_www_form_component(string).gsub('+', '%20')
  end

  def fetch_summoner_by_riot_id(game_name, tag_line, region, api_key)
    require 'net/http'
    require 'json'

    account_url = "https://americas.api.riotgames.com/riot/account/v1/accounts/by-riot-id/#{riot_url_encode(game_name)}/#{riot_url_encode(tag_line)}"
    account_uri = URI(account_url)
    account_request = Net::HTTP::Get.new(account_uri)
    account_request['X-Riot-Token'] = api_key

    account_response = Net::HTTP.start(account_uri.hostname, account_uri.port, use_ssl: true) do |http|
      http.request(account_request)
    end

    unless account_response.is_a?(Net::HTTPSuccess)
      raise "Not found: #{game_name}##{tag_line}"
    end

    JSON.parse(account_response.body)
  end

  def player_params
    # :role refers to in-game position (top/jungle/mid/adc/support), not user role
    # nosemgrep
    params.require(:player).permit(
      :summoner_name, :real_name, :role, :region, :status, :jersey_number,
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

  def fetch_summoner_by_name(summoner_name, region, api_key)
    require 'net/http'
    require 'json'

    # Parse the Riot ID
    game_name, tag_line = parse_riot_id(summoner_name, region)

    # Try different tag variations (same as create_from_riot)
    tag_variations = [
      tag_line,                    # Original parsed tag
      tag_line&.downcase,          # lowercase
      tag_line&.upcase,            # UPPERCASE
      tag_line&.capitalize,        # Capitalized
      region.upcase,               # BR1
      region[0..1].upcase,         # BR
      'BR1', 'BRSL', 'BR', 'br1', 'LAS', 'LAN'  # Common tags
    ].compact.uniq

    last_error = nil
    account_data = nil

    tag_variations.each do |tag|
      begin
        Rails.logger.info "Trying Riot ID: #{game_name}##{tag}"

        # First, get PUUID from Riot ID
        account_url = "https://americas.api.riotgames.com/riot/account/v1/accounts/by-riot-id/#{riot_url_encode(game_name)}/#{riot_url_encode(tag)}"
        account_uri = URI(account_url)
        account_request = Net::HTTP::Get.new(account_uri)
        account_request['X-Riot-Token'] = api_key

        account_response = Net::HTTP.start(account_uri.hostname, account_uri.port, use_ssl: true) do |http|
          http.request(account_request)
        end

        if account_response.is_a?(Net::HTTPSuccess)
          account_data = JSON.parse(account_response.body)
          Rails.logger.info "✅ Found player: #{game_name}##{tag}"
          break
        else
          Rails.logger.debug "Tag '#{tag}' failed: #{account_response.code}"
          next
        end
      rescue => e
        last_error = e
        Rails.logger.debug "Tag '#{tag}' failed: #{e.message}"
        next
      end
    end

    unless account_data
      # Log the attempted search for debugging
      Rails.logger.error "Failed to find Riot ID after trying all variations"
      Rails.logger.error "Tried tags: #{tag_variations.join(', ')}"

      error_msg = "Player not found with Riot ID '#{game_name}'. Tried tags: #{tag_variations.map { |t| "#{game_name}##{t}" }.join(', ')}. Original error: #{last_error&.message}"
      raise error_msg
    end

    puuid = account_data['puuid']

    # Now get summoner by PUUID
    fetch_summoner_by_puuid(puuid, region, api_key)
  end

  def fetch_summoner_by_puuid(puuid, region, api_key)
    require 'net/http'
    require 'json'

    url = "https://#{region}.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/#{puuid}"
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request['X-Riot-Token'] = api_key

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Riot API Error: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body)
  end

  def fetch_ranked_stats(puuid, region, api_key)
    require 'net/http'
    require 'json'

    # Riot API v4 now uses PUUID instead of summoner ID
    url = "https://#{region}.api.riotgames.com/lol/league/v4/entries/by-puuid/#{puuid}"
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request['X-Riot-Token'] = api_key

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Riot API Error: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body)
  end
end
