# frozen_string_literal: true

# Proxy to the prostaff-riot-gateway Go service.
# Rate limiting, caching and circuit breaking are handled by the gateway.
class RiotApiService
  REGIONS = {
    'BR' => { platform: 'br1',  region: 'americas' },
    'NA' => { platform: 'na1',  region: 'americas' },
    'EUW' => { platform: 'euw1', region: 'europe' },
    'EUNE' => { platform: 'eun1', region: 'europe' },
    'KR' => { platform: 'kr',   region: 'asia'     },
    'JP' => { platform: 'jp1',  region: 'asia'     },
    'OCE' => { platform: 'oc1',  region: 'sea'      },
    'LAN' => { platform: 'la1',  region: 'americas' },
    'LAS' => { platform: 'la2',  region: 'americas' },
    'RU' => { platform: 'ru',   region: 'europe'   },
    'TR' => { platform: 'tr1',  region: 'europe'   }
  }.freeze

  class RiotApiError < StandardError; end
  class RateLimitError < RiotApiError; end
  class NotFoundError < RiotApiError; end
  class UnauthorizedError < RiotApiError; end

  def initialize(_api_key: nil)
    @gateway_url = ENV.fetch('RIOT_GATEWAY_URL', 'http://riot-gateway:4444')
  end

  def get_summoner_by_name(summoner_name:, region:)
    platform = platform_for(region)
    response = get("/riot/summoner/#{platform}/by-name/#{ERB::Util.url_encode(summoner_name)}")
    parse_summoner_response(response)
  end

  def get_summoner_by_puuid(puuid:, region:)
    platform = platform_for(region)
    response = get("/riot/summoner/#{platform}/by-puuid/#{puuid}")
    parse_summoner_response(response)
  end

  def get_account_by_puuid(puuid:, region:)
    routing = routing_for(region)
    response = get("/riot/account/#{routing}/by-puuid/#{puuid}")
    parse_account_response(response)
  end

  def get_league_entries(summoner_id:, region:)
    platform = platform_for(region)
    response = get("/riot/league/#{platform}/by-summoner/#{summoner_id}")
    parse_league_entries(response)
  end

  def get_league_entries_by_puuid(puuid:, region:)
    platform = platform_for(region)
    response = get("/riot/league/#{platform}/by-puuid/#{puuid}")
    parse_league_entries(response)
  end

  def get_match_history(puuid:, region:, count: 20, start: 0)
    platform = platform_for(region)
    response = get("/riot/matches/#{platform}/#{puuid}/ids?count=#{count}&start=#{start}")
    JSON.parse(response.body)
  end

  def get_match_details(match_id:, region:)
    platform = platform_for(region)
    response = get("/riot/match/#{platform}/#{match_id}")
    parse_match_details(response)
  end

  def get_champion_mastery(puuid:, region:)
    platform = platform_for(region)
    response = get("/riot/mastery/#{platform}/#{puuid}/top?count=50")
    parse_champion_mastery(response)
  end

  private

  def get(path)
    conn = Faraday.new(@gateway_url) do |f|
      f.request :retry, max: 2, interval: 0.5, backoff_factor: 2
      f.adapter Faraday.default_adapter
    end

    response = conn.get(path) do |req|
      req.headers['Authorization'] = "Bearer #{internal_jwt}"
      req.options.timeout = 10
    end

    handle_response(response)
  rescue Faraday::TimeoutError => e
    raise RiotApiError, "Gateway timeout: #{e.message}"
  rescue Faraday::Error => e
    raise RiotApiError, "Gateway error: #{e.message}"
  end

  def internal_jwt
    payload = { service: 'prostaff-api', aud: ['prostaff-riot-gateway'], exp: 1.hour.from_now.to_i }
    JWT.encode(payload, ENV.fetch('INTERNAL_JWT_SECRET'), 'HS256')
  end

  def handle_response(response)
    case response.status
    when 200 then response
    when 404 then raise NotFoundError, 'Resource not found'
    when 401, 403 then raise UnauthorizedError, 'Gateway auth failed'
    when 429
      retry_after = response.headers['Retry-After']&.to_i || 60
      raise RateLimitError, "Rate limit exceeded. Retry after #{retry_after} seconds"
    when 503 then raise RiotApiError, 'Riot API circuit breaker open'
    when 500..599 then raise RiotApiError, "Gateway error: #{response.status}"
    else raise RiotApiError, "Unexpected response: #{response.status}"
    end
  end

  def platform_for(region)
    normalized = normalize_region(region)
    REGIONS.dig(normalized, :platform) || raise(RiotApiError, "Unknown region: #{region}")
  end

  def routing_for(region)
    normalized = normalize_region(region)
    REGIONS.dig(normalized, :region) || raise(RiotApiError, "Unknown region: #{region}")
  end

  def normalize_region(region)
    return nil if region.nil?

    upper = region.to_s.upcase
    return 'LAN' if upper == 'LA1'
    return 'LAS' if upper == 'LA2'

    stripped = upper.sub(/\d+$/, '')
    {
      'BR' => 'BR', 'NA' => 'NA', 'EUW' => 'EUW', 'EUN' => 'EUNE',
      'KR' => 'KR', 'JP' => 'JP', 'OC' => 'OCE', 'LA' => 'LAN',
      'RU' => 'RU', 'TR' => 'TR'
    }.fetch(stripped, stripped)
  end

  def parse_account_response(response)
    data = JSON.parse(response.body)
    { puuid: data['puuid'], game_name: data['gameName'], tag_line: data['tagLine'] }
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
    data     = JSON.parse(response.body)
    info     = data['info']
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
    challenges = participant['challenges'] || {}

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
      win: participant['win'],
      items: extract_items(participant),
      item_build_order: extract_item_build_order(participant),
      trinket: participant['item6'],
      summoner_spell_1: participant['summoner1Id'],
      summoner_spell_2: participant['summoner2Id'],
      runes: extract_runes(participant),
      objectives_stolen: participant['objectivesStolen'],
      crowd_control_score: participant['timeCCingOthers'],
      total_time_dead: participant['totalTimeSpentDead'],
      damage_to_turrets: participant['totalDamageDealtToTurrets'],
      damage_shielded_teammates: participant['totalDamageShieldedOnTeammates'],
      healing_to_teammates: participant['totalHealsOnTeammates'],
      spell_q_casts: participant['spell1Casts'],
      spell_w_casts: participant['spell2Casts'],
      spell_e_casts: participant['spell3Casts'],
      spell_r_casts: participant['spell4Casts'],
      summoner_spell_1_casts: participant['summoner1Casts'],
      summoner_spell_2_casts: participant['summoner2Casts'],
      cs_at_10: challenges['laneMinionsFirst10Minutes'],
      turret_plates_destroyed: challenges['turretPlatesTaken'],
      first_tower_kill: participant['firstTowerKill'],
      control_wards_purchased: participant['visionWardsBoughtInGame'],
      pings: extract_pings(participant)
    }
  end

  def extract_items(participant)
    [
      participant['item0'], participant['item1'], participant['item2'],
      participant['item3'], participant['item4'], participant['item5'],
      participant['item6']
    ].compact.reject(&:zero?)
  end

  def extract_item_build_order(participant)
    [
      participant['item0'], participant['item1'], participant['item2'],
      participant['item3'], participant['item4'], participant['item5']
    ].compact.reject(&:zero?)
  end

  def extract_runes(participant)
    perks = participant.dig('perks', 'styles')
    return [] unless perks

    perks.flat_map { |style| style['selections'].map { |s| s['perk'] } }
  end

  def extract_pings(participant)
    {
      all_in: participant['allInPings'].to_i,
      assist_me: participant['assistMePings'].to_i,
      bait: participant['baitPings'].to_i,
      basic: participant['basicPings'].to_i,
      command: participant['commandPings'].to_i,
      danger: participant['dangerPings'].to_i,
      enemy_missing: participant['enemyMissingPings'].to_i,
      enemy_vision: participant['enemyVisionPings'].to_i,
      get_back: participant['getBackPings'].to_i,
      hold: participant['holdPings'].to_i,
      need_vision: participant['needVisionPings'].to_i,
      on_my_way: participant['onMyWayPings'].to_i,
      push: participant['pushPings'].to_i,
      retreat: participant['retreatPings'].to_i,
      vision_cleared: participant['visionClearedPings'].to_i
    }
  end

  def parse_champion_mastery(response)
    JSON.parse(response.body).map do |mastery|
      {
        champion_id: mastery['championId'],
        champion_level: mastery['championLevel'],
        champion_points: mastery['championPoints'],
        last_played: Time.at(mastery['lastPlayTime'] / 1000)
      }
    end
  end
end
