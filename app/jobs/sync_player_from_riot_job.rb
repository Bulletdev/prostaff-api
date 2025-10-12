class SyncPlayerFromRiotJob < ApplicationJob
  queue_as :default

  def perform(player_id)
    player = Player.find(player_id)

    # Check if player has necessary data
    unless player.riot_puuid.present? || player.summoner_name.present?
      player.update(sync_status: 'error', last_sync_at: Time.current)
      Rails.logger.error "Player #{player_id} missing Riot info"
      return
    end

    # Get Riot API key
    riot_api_key = ENV['RIOT_API_KEY']
    unless riot_api_key.present?
      player.update(sync_status: 'error', last_sync_at: Time.current)
      Rails.logger.error "Riot API key not configured"
      return
    end

    begin
      region = 'br1' # TODO: Make this configurable per player

      # Fetch summoner data
      if player.riot_puuid.present?
        summoner_data = fetch_summoner_by_puuid(player.riot_puuid, region, riot_api_key)
      else
        summoner_data = fetch_summoner_by_name(player.summoner_name, region, riot_api_key)
      end

      # Fetch ranked stats
      ranked_data = fetch_ranked_stats(summoner_data['id'], region, riot_api_key)

      # Update player data
      update_data = {
        riot_puuid: summoner_data['puuid'],
        riot_summoner_id: summoner_data['id'],
        summoner_level: summoner_data['summonerLevel'],
        profile_icon_id: summoner_data['profileIconId'],
        sync_status: 'success',
        last_sync_at: Time.current
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

      player.update!(update_data)

      Rails.logger.info "Successfully synced player #{player_id} from Riot API"

    rescue StandardError => e
      Rails.logger.error "Failed to sync player #{player_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      player.update(sync_status: 'error', last_sync_at: Time.current)
    end
  end

  private

  def fetch_summoner_by_name(summoner_name, region, api_key)
    require 'net/http'
    require 'json'

    game_name, tag_line = summoner_name.split('#')
    tag_line ||= region.upcase

    # Get PUUID from Riot ID
    account_url = "https://americas.api.riotgames.com/riot/account/v1/accounts/by-riot-id/#{URI.encode_www_form_component(game_name)}/#{URI.encode_www_form_component(tag_line)}"
    account_uri = URI(account_url)
    account_request = Net::HTTP::Get.new(account_uri)
    account_request['X-Riot-Token'] = api_key

    account_response = Net::HTTP.start(account_uri.hostname, account_uri.port, use_ssl: true) do |http|
      http.request(account_request)
    end

    unless account_response.is_a?(Net::HTTPSuccess)
      raise "Riot API Error: #{account_response.code} - #{account_response.body}"
    end

    account_data = JSON.parse(account_response.body)
    puuid = account_data['puuid']

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

  def fetch_ranked_stats(summoner_id, region, api_key)
    require 'net/http'
    require 'json'

    url = "https://#{region}.api.riotgames.com/lol/league/v4/entries/by-summoner/#{summoner_id}"
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
