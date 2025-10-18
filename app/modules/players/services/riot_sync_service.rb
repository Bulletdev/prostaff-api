# frozen_string_literal: true

module Players
  module Services
    # Service for syncing player data with Riot Games API
    #
    # Handles importing new players and updating existing player data from
    # the Riot API. Manages the complexity of Riot ID format changes and
    # tag variations across different regions.
    #
    # Key features:
    # - Auto-detect and try multiple tag variations (e.g., BR, BR1, BRSL)
    # - Import new players by summoner name
    # - Sync existing players to update rank and stats
    # - Search for players with fuzzy tag matching
    #
    # @example Import a new player
    #   result = RiotSyncService.import(
    #     summoner_name: "PlayerName#BR1",
    #     role: "mid",
    #     region: "br1",
    #     organization: org
    #   )
    #
    # @example Sync existing player
    #   service = RiotSyncService.new(player)
    #   result = service.sync
    #
    # @example Search for a player
    #   result = RiotSyncService.search_riot_id("PlayerName", region: "br1")
    #
    class RiotSyncService
      require 'net/http'
      require 'json'

      attr_reader :player, :region, :api_key

      def initialize(player, region: nil, api_key: nil)
        @player = player
        @region = region || player.region.presence&.downcase || 'br1'
        @api_key = api_key || ENV['RIOT_API_KEY']
      end

      def self.import(summoner_name:, role:, region:, organization:, api_key: nil)
        new(nil, region: region, api_key: api_key)
          .import_player(summoner_name, role, organization)
      end

      def sync
        validate_player!
        validate_api_key!

        summoner_data = fetch_summoner_data
        ranked_data = fetch_ranked_stats(summoner_data['puuid'])

        update_player_data(summoner_data, ranked_data)

        { success: true, player: player }
      rescue StandardError => e
        handle_sync_error(e)
      end

      def import_player(summoner_name, role, organization)
        validate_api_key!

        summoner_data, account_data = fetch_summoner_by_name(summoner_name)
        ranked_data = fetch_ranked_stats(summoner_data['puuid'])

        player_data = build_player_data(summoner_data, ranked_data, account_data, role)
        player = organization.players.create!(player_data)

        { success: true, player: player, summoner_name: "#{account_data['gameName']}##{account_data['tagLine']}" }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.message, code: 'VALIDATION_ERROR' }
      rescue StandardError => e
        { success: false, error: e.message, code: 'RIOT_API_ERROR' }
      end

      def self.search_riot_id(summoner_name, region: 'br1', api_key: nil)
        service = new(nil, region: region, api_key: api_key || ENV['RIOT_API_KEY'])
        service.search_player(summoner_name)
      end

      # Searches for a player on Riot's servers with fuzzy tag matching
      #
      # @param summoner_name [String] Summoner name with optional tag (e.g., "Player#BR1" or "Player")
      # @return [Hash] Search result with success status and player data if found
      def search_player(summoner_name)
        validate_api_key!

        game_name, tag_line = parse_riot_id(summoner_name)

        # Try exact match first if tag is provided
        exact_match = try_exact_match(summoner_name, game_name, tag_line)
        return exact_match if exact_match

        # Fall back to tag variations
        try_fuzzy_search(game_name, tag_line)
      rescue StandardError => e
        { success: false, error: e.message, code: 'SEARCH_ERROR' }
      end

      # Attempts to find player with exact tag match
      #
      # @return [Hash, nil] Player data if found, nil otherwise
      def try_exact_match(summoner_name, game_name, tag_line)
        return nil unless summoner_name.include?('#') || summoner_name.include?('-')

        account_data = fetch_account_by_riot_id(game_name, tag_line)
        build_success_response(account_data)
      rescue StandardError => e
        Rails.logger.info "Exact match failed: #{e.message}"
        nil
      end

      # Attempts to find player using tag variations
      #
      # @return [Hash] Search result with success status
      def try_fuzzy_search(game_name, tag_line)
        tag_variations = build_tag_variations(tag_line)
        result = try_tag_variations(game_name, tag_variations)

        if result
          build_success_response_with_message(result)
        else
          build_not_found_response(game_name, tag_variations)
        end
      end

      # Builds a successful search response
      def build_success_response(account_data)
        {
          success: true,
          found: true,
          game_name: account_data['gameName'],
          tag_line: account_data['tagLine'],
          puuid: account_data['puuid'],
          riot_id: "#{account_data['gameName']}##{account_data['tagLine']}"
        }
      end

      # Builds a successful fuzzy search response with message
      def build_success_response_with_message(result)
        {
          success: true,
          found: true,
          **result,
          message: "Player found! Use this Riot ID: #{result[:riot_id]}"
        }
      end

      # Builds a not found response
      def build_not_found_response(game_name, tag_variations)
        {
          success: false,
          found: false,
          error: "Player not found. Tried game name '#{game_name}' with tags: #{tag_variations.join(', ')}",
          game_name: game_name,
          tried_tags: tag_variations
        }
      end

      private

      def validate_player!
        return if player.riot_puuid.present? || player.summoner_name.present?

        raise 'Player must have either Riot PUUID or summoner name to sync'
      end

      def validate_api_key!
        return if api_key.present?

        raise 'Riot API key not configured'
      end

      def fetch_summoner_data
        if player.riot_puuid.present?
          fetch_summoner_by_puuid(player.riot_puuid)
        else
          fetch_summoner_by_name(player.summoner_name).first
        end
      end

      def fetch_summoner_by_name(summoner_name)
        game_name, tag_line = parse_riot_id(summoner_name)

        tag_variations = build_tag_variations(tag_line)

        account_data = nil
        tag_variations.each do |tag|
          begin
            Rails.logger.info "Trying Riot ID: #{game_name}##{tag}"
            account_data = fetch_account_by_riot_id(game_name, tag)
            Rails.logger.info "✅ Found player: #{game_name}##{tag}"
            break
          rescue StandardError => e
            Rails.logger.debug "Tag '#{tag}' failed: #{e.message}"
            next
          end
        end

        unless account_data
          raise "Player not found. Tried: #{tag_variations.map { |t| "#{game_name}##{t}" }.join(', ')}"
        end

        puuid = account_data['puuid']
        summoner_data = fetch_summoner_by_puuid(puuid)

        [summoner_data, account_data]
      end

      def fetch_account_by_riot_id(game_name, tag_line)
        url = "https://americas.api.riotgames.com/riot/account/v1/accounts/by-riot-id/#{riot_url_encode(game_name)}/#{riot_url_encode(tag_line)}"
        response = make_request(url)

        JSON.parse(response.body)
      end

      def fetch_summoner_by_puuid(puuid)
        url = "https://#{region}.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/#{puuid}"
        response = make_request(url)

        JSON.parse(response.body)
      end

      def fetch_ranked_stats(puuid)
        url = "https://#{region}.api.riotgames.com/lol/league/v4/entries/by-puuid/#{puuid}"
        response = make_request(url)

        JSON.parse(response.body)
      end

      def make_request(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        request['X-Riot-Token'] = api_key

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise "Riot API Error: #{response.code} - #{response.body}"
        end

        response
      end

      def update_player_data(summoner_data, ranked_data)
        update_data = {
          riot_puuid: summoner_data['puuid'],
          riot_summoner_id: summoner_data['id'],
          sync_status: 'success',
          last_sync_at: Time.current
        }

        update_data.merge!(extract_ranked_stats(ranked_data))

        player.update!(update_data)
      end

      def build_player_data(summoner_data, ranked_data, account_data, role)
        player_data = {
          summoner_name: "#{account_data['gameName']}##{account_data['tagLine']}",
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

        player_data.merge!(extract_ranked_stats(ranked_data))
      end

      def extract_ranked_stats(ranked_data)
        stats = {}

        solo_queue = ranked_data.find { |q| q['queueType'] == 'RANKED_SOLO_5x5' }
        if solo_queue
          stats.merge!({
            solo_queue_tier: solo_queue['tier'],
            solo_queue_rank: solo_queue['rank'],
            solo_queue_lp: solo_queue['leaguePoints'],
            solo_queue_wins: solo_queue['wins'],
            solo_queue_losses: solo_queue['losses']
          })
        end

        flex_queue = ranked_data.find { |q| q['queueType'] == 'RANKED_FLEX_SR' }
        if flex_queue
          stats.merge!({
            flex_queue_tier: flex_queue['tier'],
            flex_queue_rank: flex_queue['rank'],
            flex_queue_lp: flex_queue['leaguePoints']
          })
        end

        stats
      end

      def handle_sync_error(error)
        Rails.logger.error "Riot API sync error: #{error.message}"
        player&.update(sync_status: 'error', last_sync_at: Time.current)

        { success: false, error: error.message, code: 'RIOT_API_ERROR' }
      end

      def parse_riot_id(summoner_name)
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

      def build_tag_variations(tag_line)
        [
          tag_line,                    # Original parsed tag
          tag_line&.downcase,          # lowercase
          tag_line&.upcase,            # UPPERCASE
          tag_line&.capitalize,        # Capitalized
          region.upcase,               # BR1
          region[0..1].upcase,         # BR
          'BR1', 'BRSL', 'BR', 'br1', 'LAS', 'LAN'  # Common tags
        ].compact.uniq
      end

      def try_tag_variations(game_name, tag_variations)
        tag_variations.each do |tag|
          begin
            account_data = fetch_account_by_riot_id(game_name, tag)
            return {
              game_name: account_data['gameName'],
              tag_line: account_data['tagLine'],
              puuid: account_data['puuid'],
              riot_id: "#{account_data['gameName']}##{account_data['tagLine']}"
            }
          rescue StandardError => e
            Rails.logger.debug "Tag '#{tag}' not found: #{e.message}"
            next
          end
        end

        nil
      end

      def riot_url_encode(string)
        URI.encode_www_form_component(string).gsub('+', '%20')
      end
    end
  end
end
