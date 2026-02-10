# frozen_string_literal: true

module Competitive
  module Services
    # Pandascore Service\n    # Fetches professional match data from PandaScore API
    class PandascoreService
      include Singleton

      BASE_URL = ENV.fetch('PANDASCORE_BASE_URL', 'https://api.pandascore.co')
      API_KEY = ENV['PANDASCORE_API_KEY']
      CACHE_TTL = ENV.fetch('PANDASCORE_CACHE_TTL', 3600).to_i

      class PandascoreError < StandardError; end
      class RateLimitError < PandascoreError; end
      class NotFoundError < PandascoreError; end

      # Fetch upcoming LoL matches
      # @param league [String] Filter by league (e.g., 'cblol', 'lcs', 'lck')
      # @param per_page [Integer] Number of results per page (default: 10)
      # @return [Array<Hash>] Array of match data
      def fetch_upcoming_matches(league: nil, per_page: 10)
        params = {
          'filter[videogame]': 'lol',
          sort: 'begin_at',
          per_page: per_page
        }

        params['filter[league_id]'] = league if league.present?

        cached_get('matches/upcoming', params)
      end

      # Fetch past LoL matches
      # @param league [String] Filter by league
      # @param per_page [Integer] Number of results per page (default: 20)
      # @return [Array<Hash>] Array of match data
      def fetch_past_matches(league: nil, per_page: 20)
        params = {
          'filter[videogame]': 'lol',
          'filter[finished]': true,
          sort: '-begin_at',
          per_page: per_page
        }

        params['filter[league_id]'] = league if league.present?

        cached_get('matches/past', params)
      end

      # Fetch detailed information about a specific match
      # @param match_id [String, Integer] PandaScore match ID
      # @return [Hash] Match details including games, teams, players
      def fetch_match_details(match_id)
        raise ArgumentError, 'Match ID cannot be blank' if match_id.blank?

        cached_get("lol/matches/#{match_id}")
      end

      # Fetch active LoL tournaments
      # @param active [Boolean] Only active tournaments (default: true)
      # @return [Array<Hash>] Array of tournament data
      def fetch_tournaments(active: true)
        params = {
          'filter[videogame]': 'lol'
        }

        params['filter[live_supported]'] = true if active

        cached_get('lol/tournaments', params)
      end

      # Search for a professional team by name
      # @param team_name [String] Team name to search
      # @return [Hash, nil] Team data or nil if not found
      def search_team(team_name)
        raise ArgumentError, 'Team name cannot be blank' if team_name.blank?

        params = {
          'filter[videogame]': 'lol',
          'search[name]': team_name
        }

        results = cached_get('lol/teams', params)
        results.first
      rescue NotFoundError
        nil
      end

      # Fetch champion statistics for a given patch
      # @param patch [String] Patch version (e.g., '14.20')
      # @return [Hash] Champion pick/ban statistics
      def fetch_champions_stats(patch: nil)
        params = { 'filter[videogame]': 'lol' }
        params['filter[videogame_version]'] = patch if patch.present?

        cached_get('lol/champions', params)
      end

      # Clear cache for PandaScore data
      # @param pattern [String] Cache key pattern to clear (default: all)
      def clear_cache(pattern: 'pandascore:*')
        Rails.cache.delete_matched(pattern)
        Rails.logger.info "[PandaScore] Cache cleared: #{pattern}"
      end

      private

      # Make HTTP request to PandaScore API
      # @param endpoint [String] API endpoint (without base URL)
      # @param params [Hash] Query parameters
      # @return [Hash, Array] Parsed JSON response
      def make_request(endpoint, params = {})
        raise PandascoreError, 'PANDASCORE_API_KEY not configured' if API_KEY.blank?

        url = "#{BASE_URL}/#{endpoint}"
        params[:token] = API_KEY

        Rails.logger.info "[PandaScore] GET #{endpoint} - Params: #{params.inspect}"

        response = Faraday.get(url, params) do |req|
          req.options.timeout = 10
          req.options.open_timeout = 5
        end

        handle_response(response)
      rescue Faraday::TimeoutError => e
        Rails.logger.error "[PandaScore] Timeout: #{e.message}"
        raise PandascoreError, 'Request timed out'
      rescue Faraday::Error => e
        Rails.logger.error "[PandaScore] Connection error: #{e.message}"
        raise PandascoreError, 'Failed to connect to PandaScore API'
      end

      # Handle API response and errors
      # @param response [Faraday::Response] HTTP response
      # @return [Hash, Array] Parsed JSON data
      def handle_response(response)
        case response.status
        when 200
          JSON.parse(response.body)
        when 404
          raise NotFoundError, 'Resource not found'
        when 429
          raise RateLimitError, 'Rate limit exceeded. Try again later.'
        when 401, 403
          raise PandascoreError, 'API key invalid or unauthorized'
        else
          Rails.logger.error "[PandaScore] Error #{response.status}: #{response.body}"
          raise PandascoreError, "API error: #{response.status}"
        end
      end

      # Generate cache key for an endpoint
      # @param endpoint [String] API endpoint
      # @param params [Hash] Query parameters
      # @return [String] Cache key
      def cache_key(endpoint, params)
        normalized_endpoint = endpoint.gsub('/', ':')
        param_hash = Digest::SHA256.hexdigest(params.to_json)
        "pandascore:#{normalized_endpoint}:#{param_hash}"
      end

      # Cached GET request with TTL
      # @param endpoint [String] API endpoint
      # @param params [Hash] Query parameters
      # @param ttl [Integer] Cache time-to-live in seconds
      # @return [Hash, Array] API response data
      def cached_get(endpoint, params = {}, ttl: CACHE_TTL)
        key = cache_key(endpoint, params)

        Rails.cache.fetch(key, expires_in: ttl) do
          Rails.logger.info "[PandaScore] Cache miss: #{key}"
          make_request(endpoint, params)
        end
      end
    end
  end
end
