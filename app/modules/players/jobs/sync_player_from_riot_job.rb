# frozen_string_literal: true

module Players
  # Syncs a player's Riot account data (summoner name, level, ranked stats)
  # by calling the Riot API. Enqueued after player creation or manual sync.
  class SyncPlayerFromRiotJob < ApplicationJob
    queue_as :default

    def perform(player_id, organization_id)
      # Set organization context for multi-tenant scoping
      Current.organization_id = organization_id

      player = Player.find(player_id)
      riot_api_key = ENV['RIOT_API_KEY']

      return mark_error!(player, "Player #{player_id} missing Riot info") unless riot_info_present?(player)
      return mark_error!(player, 'Riot API key not configured') unless riot_api_key.present?

      sync_player_from_riot!(player, riot_api_key)
    ensure
      # Clean up context
      Current.organization_id = nil
    end

    private

    def sync_player_from_riot!(player, riot_api_key)
      region = player.region.presence&.downcase || 'br1'
      summoner_data = fetch_summoner_data(player, region, riot_api_key)
      account_data  = fetch_account_by_puuid(player.riot_puuid, region, riot_api_key)
      ranked_data   = fetch_ranked_stats_by_puuid(player.riot_puuid, region, riot_api_key)

      update_data = build_update_data(summoner_data)
      update_summoner_name!(player, update_data, account_data)
      apply_ranked_data!(update_data, ranked_data)
      player.update!(update_data)
      Rails.logger.info "Successfully synced player #{player.id} from Riot API"
      record_job_heartbeat
    rescue StandardError => e
      Rails.logger.error "Failed to sync player #{player.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      player.update(sync_status: 'error', last_sync_at: Time.current)
    end

    def riot_info_present?(player)
      player.riot_puuid.present? || player.summoner_name.present?
    end

    def mark_error!(player, message)
      player.update(sync_status: 'error', last_sync_at: Time.current)
      Rails.logger.error message
    end

    def fetch_summoner_data(player, region, api_key)
      if player.riot_puuid.present?
        fetch_summoner_by_puuid(player.riot_puuid, region, api_key)
      else
        fetch_summoner_by_name(player.summoner_name, region, api_key)
      end
    end

    def build_update_data(summoner_data)
      {
        riot_puuid: summoner_data['puuid'],
        riot_summoner_id: summoner_data['id'],
        summoner_level: summoner_data['summonerLevel'],
        profile_icon_id: summoner_data['profileIconId'],
        sync_status: 'success',
        last_sync_at: Time.current
      }
    end

    def update_summoner_name!(player, update_data, account_data)
      return unless account_data['gameName'].present? && account_data['tagLine'].present?

      new_name = "#{account_data['gameName']}##{account_data['tagLine']}"
      return if player.summoner_name == new_name

      Rails.logger.info("Player #{player.id} name changed: #{player.summoner_name} → #{new_name}")
      update_data[:summoner_name] = new_name
    end

    # Merge solo and flex queue ranked data into update_data hash
    def apply_ranked_data!(update_data, ranked_data)
      apply_solo_queue_data!(update_data, ranked_data)
      apply_flex_queue_data!(update_data, ranked_data)
    end

    def apply_solo_queue_data!(update_data, ranked_data)
      solo = ranked_data.find { |q| q['queueType'] == 'RANKED_SOLO_5x5' }
      return unless solo

      update_data.merge!(
        solo_queue_tier: solo['tier'],
        solo_queue_rank: solo['rank'],
        solo_queue_lp: solo['leaguePoints'],
        solo_queue_wins: solo['wins'],
        solo_queue_losses: solo['losses']
      )
    end

    def apply_flex_queue_data!(update_data, ranked_data)
      flex = ranked_data.find { |q| q['queueType'] == 'RANKED_FLEX_SR' }
      return unless flex

      update_data.merge!(
        flex_queue_tier: flex['tier'],
        flex_queue_rank: flex['rank'],
        flex_queue_lp: flex['leaguePoints']
      )
    end

    def fetch_account_by_puuid(puuid, region, api_key)
      require 'net/http'
      require 'json'

      # Determine regional endpoint
      # br1, na1, lan, las1 and any unknown regions default to americas
      regional_endpoint = case region.downcase
                          when 'euw1', 'eune1', 'ru', 'tr1' then 'europe'
                          when 'kr', 'jp1', 'oce1' then 'asia'
                          else 'americas'
                          end

      url = "https://#{regional_endpoint}.api.riotgames.com/riot/account/v1/accounts/by-puuid/#{puuid}"
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request['X-Riot-Token'] = api_key

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      raise "Riot API Error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def fetch_summoner_by_name(summoner_name, region, api_key)
      require 'net/http'
      require 'json'

      game_name, tag_line = summoner_name.split('#')
      tag_line ||= region.upcase

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

      raise "Riot API Error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

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

      raise "Riot API Error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def fetch_ranked_stats_by_puuid(puuid, region, api_key)
      require 'net/http'
      require 'json'

      url = "https://#{region}.api.riotgames.com/lol/league/v4/entries/by-puuid/#{puuid}"
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request['X-Riot-Token'] = api_key

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      raise "Riot API Error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
