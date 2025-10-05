class RiotApiService
  RATE_LIMITS = {
    per_second: 20,
    per_two_minutes: 100
  }.freeze

  REGIONS = {
    'BR' => { platform: 'BR1', region: 'americas' },
    'NA' => { platform: 'NA1', region: 'americas' },
    'EUW' => { platform: 'EUW1', region: 'europe' },
    'EUNE' => { platform: 'EUN1', region: 'europe' },
    'KR' => { platform: 'KR', region: 'asia' },
    'JP' => { platform: 'JP1', region: 'asia' },
    'OCE' => { platform: 'OC1', region: 'sea' },
    'LAN' => { platform: 'LA1', region: 'americas' },
    'LAS' => { platform: 'LA2', region: 'americas' },
    'RU' => { platform: 'RU', region: 'europe' },
    'TR' => { platform: 'TR1', region: 'europe' }
  }.freeze

  class RiotApiError < StandardError; end
  class RateLimitError < RiotApiError; end
  class NotFoundError < RiotApiError; end
  class UnauthorizedError < RiotApiError; end

  def initialize(api_key: nil)
    @api_key = api_key || ENV['RIOT_API_KEY']
    raise RiotApiError, 'Riot API key not configured' if @api_key.blank?
  end

  # Summoner endpoints
  def get_summoner_by_name(summoner_name:, region:)
    platform = platform_for_region(region)
    url = "https://#{platform}.api.riotgames.com/lol/summoner/v4/summoners/by-name/#{ERB::Util.url_encode(summoner_name)}"

    response = make_request(url)
    parse_summoner_response(response)
  end

  def get_summoner_by_puuid(puuid:, region:)
    platform = platform_for_region(region)
    url = "https://#{platform}.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/#{puuid}"

    response = make_request(url)
    parse_summoner_response(response)
  end

  # League (Rank) endpoints
  def get_league_entries(summoner_id:, region:)
    platform = platform_for_region(region)
    url = "https://#{platform}.api.riotgames.com/lol/league/v4/entries/by-summoner/#{summoner_id}"

    response = make_request(url)
    parse_league_entries(response)
  end

  # Match endpoints
  def get_match_history(puuid:, region:, count: 20, start: 0)
    regional_route = regional_route_for_region(region)
    url = "https://#{regional_route}.api.riotgames.com/lol/match/v5/matches/by-puuid/#{puuid}/ids?start=#{start}&count=#{count}"

    response = make_request(url)
    JSON.parse(response.body)
  end

  def get_match_details(match_id:, region:)
    regional_route = regional_route_for_region(region)
    url = "https://#{regional_route}.api.riotgames.com/lol/match/v5/matches/#{match_id}"

    response = make_request(url)
    parse_match_details(response)
  end

  # Champion Mastery endpoints
  def get_champion_mastery(puuid:, region:)
    platform = platform_for_region(region)
    url = "https://#{platform}.api.riotgames.com/lol/champion-mastery/v4/champion-masteries/by-puuid/#{puuid}"

    response = make_request(url)
    parse_champion_mastery(response)
  end

  private

  def make_request(url)
    check_rate_limit!

    conn = Faraday.new do |f|
      f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
      f.adapter Faraday.default_adapter
    end

    response = conn.get(url) do |req|
      req.headers['X-Riot-Token'] = @api_key
      req.options.timeout = 10
    end

    handle_response(response)
  rescue Faraday::TimeoutError => e
    raise RiotApiError, "Request timeout: #{e.message}"
  rescue Faraday::Error => e
    raise RiotApiError, "Network error: #{e.message}"
  end

  def handle_response(response)
    case response.status
    when 200
      response
    when 404
      raise NotFoundError, 'Resource not found'
    when 401, 403
      raise UnauthorizedError, 'Invalid API key or unauthorized'
    when 429
      retry_after = response.headers['Retry-After']&.to_i || 120
      raise RateLimitError, "Rate limit exceeded. Retry after #{retry_after} seconds"
    when 500..599
      raise RiotApiError, "Riot API server error: #{response.status}"
    else
      raise RiotApiError, "Unexpected response: #{response.status}"
    end
  end

  def check_rate_limit!
    # Simple rate limiting using Redis
    return unless Rails.cache

    current_second = Time.current.to_i
    key_second = "riot_api:rate_limit:second:#{current_second}"
    key_two_min = "riot_api:rate_limit:two_minutes:#{current_second / 120}"

    count_second = Rails.cache.increment(key_second, 1, expires_in: 1.second) || 0
    count_two_min = Rails.cache.increment(key_two_min, 1, expires_in: 2.minutes) || 0

    if count_second > RATE_LIMITS[:per_second]
      sleep(1 - (Time.current.to_f % 1)) # Sleep until next second
    end

    if count_two_min > RATE_LIMITS[:per_two_minutes]
      raise RateLimitError, 'Rate limit exceeded for 2-minute window'
    end
  end

  def platform_for_region(region)
    REGIONS.dig(region.upcase, :platform) || raise(RiotApiError, "Unknown region: #{region}")
  end

  def regional_route_for_region(region)
    REGIONS.dig(region.upcase, :region) || raise(RiotApiError, "Unknown region: #{region}")
  end

  def parse_summoner_response(response)
    data = JSON.parse(response.body)
    {
      summoner_id: data['id'],
      puuid: data['puuid'],
      summoner_name: data['name'],
      summoner_level: data['summonerLevel'],
      profile_icon_id: data['profileIconId']
    }
  end

  def parse_league_entries(response)
    entries = JSON.parse(response.body)

    {
      solo_queue: find_queue_entry(entries, 'RANKED_SOLO_5x5'),
      flex_queue: find_queue_entry(entries, 'RANKED_FLEX_SR')
    }
  end

  def find_queue_entry(entries, queue_type)
    entry = entries.find { |e| e['queueType'] == queue_type }
    return nil unless entry

    {
      tier: entry['tier'],
      rank: entry['rank'],
      lp: entry['leaguePoints'],
      wins: entry['wins'],
      losses: entry['losses']
    }
  end

  def parse_match_details(response)
    data = JSON.parse(response.body)
    info = data['info']
    metadata = data['metadata']

    {
      match_id: metadata['matchId'],
      game_creation: Time.at(info['gameCreation'] / 1000),
      game_duration: info['gameDuration'],
      game_mode: info['gameMode'],
      game_version: info['gameVersion'],
      participants: info['participants'].map { |p| parse_participant(p) }
    }
  end

  def parse_participant(participant)
    {
      puuid: participant['puuid'],
      summoner_name: participant['summonerName'],
      champion_name: participant['championName'],
      champion_id: participant['championId'],
      team_id: participant['teamId'],
      role: participant['teamPosition']&.downcase,
      kills: participant['kills'],
      deaths: participant['deaths'],
      assists: participant['assists'],
      gold_earned: participant['goldEarned'],
      total_damage_dealt: participant['totalDamageDealtToChampions'],
      total_damage_taken: participant['totalDamageTaken'],
      minions_killed: participant['totalMinionsKilled'],
      neutral_minions_killed: participant['neutralMinionsKilled'],
      vision_score: participant['visionScore'],
      wards_placed: participant['wardsPlaced'],
      wards_killed: participant['wardsKilled'],
      champion_level: participant['champLevel'],
      first_blood_kill: participant['firstBloodKill'],
      double_kills: participant['doubleKills'],
      triple_kills: participant['tripleKills'],
      quadra_kills: participant['quadraKills'],
      penta_kills: participant['pentaKills'],
      win: participant['win']
    }
  end

  def parse_champion_mastery(response)
    masteries = JSON.parse(response.body)

    masteries.map do |mastery|
      {
        champion_id: mastery['championId'],
        champion_level: mastery['championLevel'],
        champion_points: mastery['championPoints'],
        last_played: Time.at(mastery['lastPlayTime'] / 1000)
      }
    end
  end
end
