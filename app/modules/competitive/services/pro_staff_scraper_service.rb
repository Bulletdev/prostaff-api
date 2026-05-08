# frozen_string_literal: true

# HTTP client for the ProStaff Scraper microservice.
#
# The scraper collects professional LoL match data from two sources:
#   - LoL Esports API (Phase 1 sync): schedules, team names, VOD IDs
#   - Leaguepedia Cargo API (Phase 2 enrichment): per-player stats
#     (champion, KDA, items, runes, summoner spells)
#
# Competitive games run on Riot's internal tournament servers and are NOT
# accessible via the public Match-V5 API. The scraper is the authoritative
# source for this data.
#
# Configuration (environment variables):
#   SCRAPER_API_URL  — base URL, e.g. https://scraper.prostaff.gg
#   SCRAPER_API_KEY  — key sent in X-API-Key header for write/status endpoints
#
# @example Fetch enriched CBLOL matches
#   service = ProStaffScraperService.new
#   result  = service.fetch_matches(league: 'CBLOL', limit: 20)
#   result[:matches] # => Array of match hashes
#
class ProStaffScraperService
  class ScraperError < StandardError; end
  class NotFoundError < ScraperError; end
  class UnauthorizedError < ScraperError; end
  class UnavailableError < ScraperError; end

  CACHE_TTL_MATCHES = 5.minutes
  CACHE_TTL_STATUS  = 1.minute
  REQUEST_TIMEOUT   = 15

  def initialize
    @base_url = ENV.fetch('SCRAPER_API_URL', 'https://scraper.prostaff.gg')
    @api_key  = ENV['SCRAPER_API_KEY']
  end

  # Fetch paginated list of matches for a given league.
  #
  # @param league [String] e.g. 'CBLOL', 'LCS', 'LEC'
  # @param limit  [Integer] number of matches to return (1-500)
  # @param skip   [Integer] pagination offset
  # @return [Hash] with keys :total, :league, :count, :matches
  def fetch_matches(league:, limit: 50, skip: 0)
    cache_key = "scraper:matches:#{league}:#{limit}:#{skip}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    response = get('/api/v1/matches', { league: league, limit: limit, skip: skip })
    result = parse_json(response)
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL_MATCHES)
    result
  end

  # Fetch a single match by its composite ID (e.g. "115565621821672075_2").
  #
  # @param match_id [String]
  # @return [Hash] match document
  def fetch_match(match_id)
    response = get("/api/v1/matches/#{ERB::Util.url_encode(match_id)}")
    parse_json(response)
  end

  # Fetch enrichment progress (pending vs enriched counts).
  # Requires SCRAPER_API_KEY to be configured.
  #
  # @return [Hash] with keys :total, :enriched, :pending, :max_attempts_reached
  def enrichment_status
    cache_key = 'scraper:enrichment_status'
    cached = Rails.cache.read(cache_key)
    return cached if cached

    response = get('/api/v1/enrich/status', {}, authenticated: true)
    result = parse_json(response)
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL_STATUS)
    result
  end

  # Health check against the scraper service.
  #
  # @return [Boolean] true if the scraper and its Elasticsearch are healthy
  def healthy?
    response = get('/health')
    parse_json(response)['status'] == 'healthy'
  rescue ScraperError
    false
  end

  # Trigger the Leaguepedia native pipeline on the scraper for a full tournament import.
  #
  # Queries Leaguepedia ScoreboardGames by OverviewPage to import ALL historical
  # games (including regular season), bypassing the LoL Esports API rolling window.
  # The pipeline runs in the background on the scraper side; this call returns
  # immediately once the job is accepted.
  #
  # Requires SCRAPER_API_KEY to be configured on both sides.
  #
  # @param tournament [String] Leaguepedia OverviewPage, e.g. 'CBLOL/2026 Season/Cup'
  # @return [Hash] scraper response with message and status
  def trigger_leaguepedia_sync(tournament:)
    response = post('/api/v1/sync-leaguepedia', { tournament: tournament }, authenticated: true)
    parse_json(response)
  end

  # List all main-event tournament OverviewPages for a league from Leaguepedia.
  #
  # Queries Leaguepedia Tournaments table live. Useful to preview which
  # editions exist before triggering the historical backfill.
  #
  # @param league   [String]  e.g. 'CBLOL', 'LCS', 'LEC'
  # @param min_year [Integer] ignore tournaments before this year (default 2013)
  # @return [Hash] with keys :league, :total_main_events, :tournaments
  def list_tournaments(league: 'CBLOL', min_year: 2013)
    response = get(
      '/api/v1/tournaments',
      { league: league, min_year: min_year },
      authenticated: true
    )
    parse_json(response)
  end

  # Trigger the full historical backfill for a league on the scraper.
  #
  # Discovers all tournament editions on Leaguepedia and imports every game
  # into Elasticsearch. The pipeline is resumable — re-calling this method
  # skips already-completed tournaments.
  #
  # A full CBLOL history (~30 tournaments × ~60 games) takes ~6 hours.
  # The scraper runs this in the background and returns immediately.
  #
  # @param league   [String]  e.g. 'CBLOL', 'LCS'
  # @param min_year [Integer] ignore tournaments before this year (default 2013)
  # @return [Hash] scraper response with message and progress_file
  def trigger_historical_backfill(league: 'CBLOL', min_year: 2013)
    response = post(
      '/api/v1/historical-backfill',
      { league: league, min_year: min_year },
      authenticated: true
    )
    parse_json(response)
  end

  # Fetch current progress of the historical backfill for a league.
  #
  # Returns a breakdown of how many tournaments are completed, pending or errored,
  # plus per-tournament details and total games indexed.
  #
  # @param league [String] e.g. 'CBLOL', 'LCS'
  # @return [Hash] progress state from the scraper's progress JSON file
  def historical_backfill_status(league: 'CBLOL')
    cache_key = "scraper:backfill_status:#{league}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    response = get(
      '/api/v1/historical-backfill/status',
      { league: league },
      authenticated: true
    )
    result = parse_json(response)
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL_STATUS)
    result
  end

  private

  def connection
    Faraday.new(@base_url) do |f|
      f.request :retry, max: 2, interval: 1, backoff_factor: 2,
                        exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
      f.adapter Faraday.default_adapter
    end
  end

  def get(path, params = {}, authenticated: false)
    conn = connection
    response = conn.get(path) do |req|
      req.params.merge!(params) if params.any?
      req.headers['Accept'] = 'application/json'
      req.headers['X-API-Key'] = @api_key if authenticated && @api_key.present?
      req.options.timeout = REQUEST_TIMEOUT
    end
    handle_response(response)
  rescue Faraday::TimeoutError => e
    raise UnavailableError, "Scraper request timeout: #{e.message}"
  rescue Faraday::ConnectionFailed => e
    raise UnavailableError, "Scraper connection failed: #{e.message}"
  rescue Faraday::Error => e
    raise ScraperError, "Scraper network error: #{e.message}"
  end

  # The scraper accepts POST params as query strings (FastAPI Query() convention).
  def post(path, params = {}, authenticated: false)
    conn = connection
    response = conn.post(path) do |req|
      req.params.merge!(params) if params.any?
      req.headers['Accept'] = 'application/json'
      req.headers['X-API-Key'] = @api_key if authenticated && @api_key.present?
      req.options.timeout = REQUEST_TIMEOUT
    end
    handle_response(response)
  rescue Faraday::TimeoutError => e
    raise UnavailableError, "Scraper request timeout: #{e.message}"
  rescue Faraday::ConnectionFailed => e
    raise UnavailableError, "Scraper connection failed: #{e.message}"
  rescue Faraday::Error => e
    raise ScraperError, "Scraper network error: #{e.message}"
  end

  def handle_response(response)
    case response.status
    when 200
      response
    when 404
      raise NotFoundError, 'Match not found in scraper'
    when 401, 403
      raise UnauthorizedError, 'Invalid or missing SCRAPER_API_KEY'
    when 503
      raise UnavailableError, 'Scraper or Elasticsearch unavailable'
    else
      raise ScraperError, "Scraper returned unexpected status #{response.status}"
    end
  end

  def parse_json(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise ScraperError, "Invalid JSON from scraper: #{e.message}"
  end
end
