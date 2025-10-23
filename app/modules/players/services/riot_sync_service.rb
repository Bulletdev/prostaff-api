# frozen_string_literal: true

module Players
  module Services
    class RiotSyncService
      VALID_REGIONS = %w[br1 na1 euw1 kr eune1 lan las1 oce1 ru tr1 jp1].freeze
      AMERICAS = %w[br1 na1 lan las1].freeze
      EUROPE = %w[euw1 eune1 ru tr1].freeze
      ASIA = %w[kr jp1 oce1].freeze

      # Whitelist of allowed Riot API hostnames to prevent SSRF
      REGION_HOSTS = {
        'br1' => 'br1.api.riotgames.com',
        'na1' => 'na1.api.riotgames.com',
        'euw1' => 'euw1.api.riotgames.com',
        'kr' => 'kr.api.riotgames.com',
        'eune1' => 'eune1.api.riotgames.com',
        'lan' => 'lan.api.riotgames.com',
        'las1' => 'las1.api.riotgames.com',
        'oce1' => 'oce1.api.riotgames.com',
        'ru' => 'ru.api.riotgames.com',
        'tr1' => 'tr1.api.riotgames.com',
        'jp1' => 'jp1.api.riotgames.com'
      }.freeze

      # Whitelist of allowed regional endpoints for match/account APIs
      REGIONAL_ENDPOINT_HOSTS = {
        'americas' => 'americas.api.riotgames.com',
        'europe' => 'europe.api.riotgames.com',
        'asia' => 'asia.api.riotgames.com'
      }.freeze

      attr_reader :organization, :api_key, :region

      def initialize(organization, region = nil)
        @organization = organization
        @api_key = ENV['RIOT_API_KEY']
        @region = sanitize_region(region || organization.region || 'br1')

        raise 'Riot API key not configured' if @api_key.blank?
      end

      # Main sync method
      def sync_player(player, import_matches: true)
        return { success: false, error: 'Player missing PUUID' } if player.puuid.blank?

        begin
          # 1. Fetch current rank and profile
          summoner_data = fetch_summoner_by_puuid(player.puuid)
          rank_data = fetch_rank_data(summoner_data['id'])

          # 2. Update player with fresh data
          update_player_from_riot(player, summoner_data, rank_data)

          # 3. Optionally fetch recent matches
          matches_imported = 0
          matches_imported = import_player_matches(player, count: 20) if import_matches

          {
            success: true,
            player: player,
            matches_imported: matches_imported,
            message: 'Player synchronized successfully'
          }
        rescue StandardError => e
          Rails.logger.error("RiotSync Error for #{player.summoner_name}: #{e.message}")
          {
            success: false,
            error: e.message,
            player: player
          }
        end
      end

      # Fetch summoner by PUUID
      def fetch_summoner_by_puuid(puuid)
        # Use whitelisted host to prevent SSRF
        uri = URI::HTTPS.build(
          host: riot_api_host,
          path: "/lol/summoner/v4/summoners/by-puuid/#{CGI.escape(puuid)}"
        )
        response = make_request(uri.to_s)
        JSON.parse(response.body)
      end

      # Fetch rank data for a summoner
      def fetch_rank_data(summoner_id)
        # Use whitelisted host to prevent SSRF
        uri = URI::HTTPS.build(
          host: riot_api_host,
          path: "/lol/league/v4/entries/by-summoner/#{CGI.escape(summoner_id)}"
        )
        response = make_request(uri.to_s)
        data = JSON.parse(response.body)

        # Find RANKED_SOLO_5x5 queue
        solo_queue = data.find { |entry| entry['queueType'] == 'RANKED_SOLO_5x5' }
        solo_queue || {}
      end

      # Import recent matches for a player
      def import_player_matches(player, count: 20)
        return 0 if player.puuid.blank?

        # 1. Get match IDs
        match_ids = fetch_match_ids(player.puuid, count)
        return 0 if match_ids.empty?

        # 2. Import each match
        imported = 0
        match_ids.each do |match_id|
          next if organization.matches.exists?(riot_match_id: match_id)

          match_details = fetch_match_details(match_id)
          imported += 1 if import_match(match_details, player)
        rescue StandardError => e
          Rails.logger.error("Failed to import match #{match_id}: #{e.message}")
        end

        imported
      end

      # Search for a player by Riot ID (GameName#TagLine)
      def search_riot_id(game_name, tag_line)
        regional_endpoint = get_regional_endpoint(region)

        # Use whitelisted host to prevent SSRF
        uri = URI::HTTPS.build(
          host: regional_api_host(regional_endpoint),
          path: "/riot/account/v1/accounts/by-riot-id/#{CGI.escape(game_name)}/#{CGI.escape(tag_line)}"
        )
        response = make_request(uri.to_s)
        account_data = JSON.parse(response.body)

        # Now fetch summoner data using PUUID
        summoner_data = fetch_summoner_by_puuid(account_data['puuid'])
        rank_data = fetch_rank_data(summoner_data['id'])

        {
          puuid: account_data['puuid'],
          game_name: account_data['gameName'],
          tag_line: account_data['tagLine'],
          summoner_name: summoner_data['name'],
          summoner_level: summoner_data['summonerLevel'],
          profile_icon_id: summoner_data['profileIconId'],
          rank_data: rank_data
        }
      rescue StandardError => e
        Rails.logger.error("Failed to search Riot ID #{game_name}##{tag_line}: #{e.message}")
        nil
      end

      private

      # Fetch match IDs
      def fetch_match_ids(puuid, count = 20)
        regional_endpoint = get_regional_endpoint(region)

        # Use whitelisted host to prevent SSRF
        uri = URI::HTTPS.build(
          host: regional_api_host(regional_endpoint),
          path: "/lol/match/v5/matches/by-puuid/#{CGI.escape(puuid)}/ids",
          query: URI.encode_www_form(count: count)
        )
        response = make_request(uri.to_s)
        JSON.parse(response.body)
      end

      # Fetch match details
      def fetch_match_details(match_id)
        regional_endpoint = get_regional_endpoint(region)

        # Use whitelisted host to prevent SSRF
        uri = URI::HTTPS.build(
          host: regional_api_host(regional_endpoint),
          path: "/lol/match/v5/matches/#{CGI.escape(match_id)}"
        )
        response = make_request(uri.to_s)
        JSON.parse(response.body)
      end

      # Make HTTP request to Riot API
      def make_request(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        request['X-Riot-Token'] = api_key

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        raise "Riot API Error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        response
      end

      # Update player with Riot data
      def update_player_from_riot(player, summoner_data, rank_data)
        player.update!(
          summoner_level: summoner_data['summonerLevel'],
          profile_icon_id: summoner_data['profileIconId'],
          solo_queue_tier: rank_data['tier'],
          solo_queue_rank: rank_data['rank'],
          solo_queue_lp: rank_data['leaguePoints'],
          wins: rank_data['wins'],
          losses: rank_data['losses'],
          last_sync_at: Time.current,
          sync_status: 'success'
        )
      end

      # Import a match from Riot data
      def import_match(match_data, player)
        info = match_data['info']
        metadata = match_data['metadata']

        # Find player's participant
        participant = info['participants'].find do |p|
          p['puuid'] == player.puuid
        end

        return false unless participant

        # Determine if it was a victory
        victory = participant['win']

        # Create match
        match = organization.matches.create!(
          riot_match_id: metadata['matchId'],
          match_type: 'official',
          game_start: Time.zone.at(info['gameStartTimestamp'] / 1000),
          game_end: Time.zone.at(info['gameEndTimestamp'] / 1000),
          game_duration: info['gameDuration'],
          victory: victory,
          patch_version: info['gameVersion'],
          our_side: participant['teamId'] == 100 ? 'blue' : 'red'
        )

        # Create player stats
        create_player_stats(match, player, participant)

        true
      end

      # Create player match stats
      def create_player_stats(match, player, participant)
        match.player_match_stats.create!(
          player: player,
          champion: participant['championName'],
          role: participant['teamPosition']&.downcase || player.role,
          kills: participant['kills'],
          deaths: participant['deaths'],
          assists: participant['assists'],
          total_damage_dealt: participant['totalDamageDealtToChampions'],
          total_damage_taken: participant['totalDamageTaken'],
          gold_earned: participant['goldEarned'],
          total_cs: participant['totalMinionsKilled'] + participant['neutralMinionsKilled'],
          vision_score: participant['visionScore'],
          wards_placed: participant['wardsPlaced'],
          wards_killed: participant['wardsKilled'],
          first_blood: participant['firstBloodKill'],
          double_kills: participant['doubleKills'],
          triple_kills: participant['tripleKills'],
          quadra_kills: participant['quadraKills'],
          penta_kills: participant['pentaKills']
        )
      end

      # Validate and normalize region
      def sanitize_region(region)
        normalized = region.to_s.downcase.strip

        unless VALID_REGIONS.include?(normalized)
          raise ArgumentError, "Invalid region: #{region}. Must be one of: #{VALID_REGIONS.join(', ')}"
        end

        normalized
      end

      # Get safe Riot API hostname from whitelist (prevents SSRF)
      def riot_api_host
        host = REGION_HOSTS[@region]
        raise SecurityError, "Region #{@region} not in whitelist" if host.nil?

        host
      end

      # Get safe regional API hostname from whitelist (prevents SSRF)
      def regional_api_host(endpoint_name)
        host = REGIONAL_ENDPOINT_HOSTS[endpoint_name]
        raise SecurityError, "Regional endpoint #{endpoint_name} not in whitelist" if host.nil?

        host
      end

      # Get regional endpoint for match/account APIs
      def get_regional_endpoint(platform_region)
        if AMERICAS.include?(platform_region)
          'americas'
        elsif EUROPE.include?(platform_region)
          'europe'
        elsif ASIA.include?(platform_region)
          'asia'
        else
          'americas' # Default fallback
        end
      end
    end
  end
end
