# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RiotApiService do
  include ActiveSupport::Testing::TimeHelpers

  let(:service) { described_class.new }
  let(:gateway_url) { ENV.fetch('RIOT_GATEWAY_URL', 'http://riot-gateway:4444') }

  # The service proxies all calls through the prostaff-riot-gateway (Go service).
  # We stub that gateway URL, not the Riot API directly.
  before do
    stub_request(:any, /riot-gateway/).to_return(status: 200, body: '{}',
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  describe '#initialize' do
    it 'reads RIOT_GATEWAY_URL from environment' do
      svc = described_class.new
      expect(svc.instance_variable_get(:@gateway_url)).to eq(gateway_url)
    end

    it 'does not require an api_key argument (gateway handles auth)' do
      expect { described_class.new }.not_to raise_error
    end

    it 'accepts the _api_key keyword argument (underscore prefix means unused)' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe 'region mapping and normalization' do
    it 'resolves BR to platform br1' do
      stub_request(:get, /riot-gateway.*br1/)
        .to_return(status: 200, body: { id: 's1', puuid: 'p1', name: 'Test',
                                        summonerLevel: 100, profileIconId: 1 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.get_summoner_by_name(summoner_name: 'Test', region: 'BR')
      expect(result[:summoner_id]).to eq('s1')
    end

    it 'resolves NA to platform na1' do
      stub_request(:get, /riot-gateway.*na1/)
        .to_return(status: 200, body: { id: 's2', puuid: 'p2', name: 'Test',
                                        summonerLevel: 50, profileIconId: 2 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.get_summoner_by_name(summoner_name: 'Test', region: 'NA')
      expect(result[:summoner_id]).to eq('s2')
    end

    it 'resolves EUW to platform euw1' do
      stub_request(:get, /riot-gateway.*euw1/)
        .to_return(status: 200, body: { id: 's3', puuid: 'p3', name: 'Test',
                                        summonerLevel: 200, profileIconId: 3 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.get_summoner_by_name(summoner_name: 'Test', region: 'EUW')
      expect(result[:summoner_id]).to eq('s3')
    end

    it 'raises RiotApiError for unknown region (SSRF protection)' do
      expect do
        service.get_summoner_by_name(summoner_name: 'Test', region: 'INVALID_REGION')
      end.to raise_error(RiotApiService::RiotApiError, /Unknown region/)
    end

    it 'raises RiotApiError for empty region string' do
      expect do
        service.get_summoner_by_name(summoner_name: 'Test', region: '')
      end.to raise_error(RiotApiService::RiotApiError, /Unknown region/)
    end

    it 'supports KR region' do
      stub_request(:get, /riot-gateway.*\/kr\//)
        .to_return(status: 200, body: { id: 'kr1', puuid: 'pkr', name: 'KRPlayer',
                                        summonerLevel: 300, profileIconId: 9 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { service.get_summoner_by_name(summoner_name: 'KRPlayer', region: 'KR') }.not_to raise_error
    end

    it 'normalizes lowercase region to uppercase' do
      stub_request(:get, /riot-gateway.*br1/)
        .to_return(status: 200, body: { id: 'sx', puuid: 'px', name: 'T',
                                        summonerLevel: 1, profileIconId: 0 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { service.get_summoner_by_name(summoner_name: 'T', region: 'br') }.not_to raise_error
    end
  end

  describe 'HTTP error handling' do
    describe '404 Not Found' do
      before do
        stub_request(:get, /riot-gateway/)
          .to_return(status: 404,
                     body: '{"status":{"message":"Data not found","status_code":404}}',
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises NotFoundError' do
        expect do
          service.get_summoner_by_name(summoner_name: 'Ghost', region: 'BR')
        end.to raise_error(RiotApiService::NotFoundError)
      end

      it 'NotFoundError is a subclass of RiotApiError' do
        expect(RiotApiService::NotFoundError.ancestors).to include(RiotApiService::RiotApiError)
      end
    end

    describe '429 Rate Limited' do
      before do
        stub_request(:get, /riot-gateway/)
          .to_return(status: 429, headers: { 'Retry-After' => '120' })
      end

      it 'raises RateLimitError' do
        expect do
          service.get_summoner_by_name(summoner_name: 'Throttled', region: 'BR')
        end.to raise_error(RiotApiService::RateLimitError)
      end

      it 'RateLimitError is a subclass of RiotApiError' do
        expect(RiotApiService::RateLimitError.ancestors).to include(RiotApiService::RiotApiError)
      end

      it 'includes retry-after in the error message' do
        expect do
          service.get_summoner_by_name(summoner_name: 'Throttled', region: 'BR')
        end.to raise_error(RiotApiService::RateLimitError, /120/)
      end
    end

    describe '401/403 Unauthorized' do
      before do
        stub_request(:get, /riot-gateway/)
          .to_return(status: 401)
      end

      it 'raises UnauthorizedError' do
        expect do
          service.get_summoner_by_name(summoner_name: 'Denied', region: 'BR')
        end.to raise_error(RiotApiService::UnauthorizedError)
      end
    end

    describe '503 Service Unavailable' do
      before do
        stub_request(:get, /riot-gateway/)
          .to_return(status: 503,
                     body: '{"status":{"message":"Service unavailable","status_code":503}}')
      end

      it 'raises RiotApiError' do
        expect do
          service.get_summoner_by_name(summoner_name: 'Down', region: 'BR')
        end.to raise_error(RiotApiService::RiotApiError)
      end
    end

    describe '500 Gateway Error' do
      before do
        stub_request(:get, /riot-gateway/)
          .to_return(status: 500)
      end

      it 'raises RiotApiError' do
        expect do
          service.get_summoner_by_name(summoner_name: 'Error', region: 'BR')
        end.to raise_error(RiotApiService::RiotApiError, /Gateway error/)
      end
    end
  end

  describe '#get_summoner_by_name' do
    let(:summoner_body) do
      { id: 'summoner-id', puuid: 'puuid-abc', name: 'ProPlayer',
        summonerLevel: 500, profileIconId: 4321 }.to_json
    end

    before do
      stub_request(:get, /riot-gateway.*by-name/)
        .to_return(status: 200, body: summoner_body,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a hash with summoner_id, puuid, summoner_name' do
      result = service.get_summoner_by_name(summoner_name: 'ProPlayer', region: 'BR')
      expect(result).to include(
        summoner_id: 'summoner-id',
        puuid: 'puuid-abc',
        summoner_name: 'ProPlayer',
        summoner_level: 500,
        profile_icon_id: 4321
      )
    end
  end

  describe '#get_league_entries' do
    let(:league_body) do
      [
        { 'queueType' => 'RANKED_SOLO_5x5', 'tier' => 'DIAMOND', 'rank' => 'II',
          'leaguePoints' => 75, 'wins' => 120, 'losses' => 80 },
        { 'queueType' => 'RANKED_FLEX_SR', 'tier' => 'PLATINUM', 'rank' => 'I',
          'leaguePoints' => 50, 'wins' => 40, 'losses' => 35 }
      ].to_json
    end

    before do
      stub_request(:get, /riot-gateway.*league.*by-summoner/)
        .to_return(status: 200, body: league_body,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns solo_queue entry' do
      result = service.get_league_entries(summoner_id: 's1', region: 'BR')
      expect(result[:solo_queue]).to include(tier: 'DIAMOND', rank: 'II', lp: 75)
    end

    it 'returns flex_queue entry' do
      result = service.get_league_entries(summoner_id: 's1', region: 'BR')
      expect(result[:flex_queue]).to include(tier: 'PLATINUM', rank: 'I', lp: 50)
    end

    it 'returns nil solo_queue when no ranked entry found' do
      stub_request(:get, /riot-gateway.*league.*by-summoner/)
        .to_return(status: 200, body: '[]',
                   headers: { 'Content-Type' => 'application/json' })

      result = service.get_league_entries(summoner_id: 's_unranked', region: 'BR')
      expect(result[:solo_queue]).to be_nil
    end
  end

  describe '#get_match_history' do
    before do
      stub_request(:get, /riot-gateway.*ids/)
        .to_return(status: 200,
                   body: ['BR1_123', 'BR1_456', 'BR1_789'].to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of match IDs' do
      result = service.get_match_history(puuid: 'puuid-abc', region: 'BR')
      expect(result).to eq(%w[BR1_123 BR1_456 BR1_789])
    end
  end

  describe '#get_champion_mastery' do
    let(:mastery_body) do
      [
        { 'championId' => 99, 'championLevel' => 7, 'championPoints' => 350_000,
          'lastPlayTime' => 1_700_000_000_000 }
      ].to_json
    end

    before do
      stub_request(:get, /riot-gateway.*mastery/)
        .to_return(status: 200, body: mastery_body,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns champion mastery list' do
      result = service.get_champion_mastery(puuid: 'puuid-abc', region: 'BR')
      expect(result.first).to include(champion_id: 99, champion_level: 7, champion_points: 350_000)
    end

    it 'returns last_played as a Time object' do
      result = service.get_champion_mastery(puuid: 'puuid-abc', region: 'BR')
      expect(result.first[:last_played]).to be_a(Time)
    end
  end

  describe '#get_match_details participant parsing' do
    let(:participant) do
      {
        'puuid' => 'p1', 'summonerName' => 'TestPlayer', 'championName' => 'Jinx',
        'championId' => 222, 'teamId' => 100, 'teamPosition' => 'BOTTOM',
        'kills' => 10, 'deaths' => 0, 'assists' => 5,
        'goldEarned' => 15_000, 'totalDamageDealtToChampions' => 30_000,
        'totalDamageTaken' => 20_000, 'totalMinionsKilled' => 200,
        'neutralMinionsKilled' => 10, 'champLevel' => 18, 'win' => true,
        'item0' => 3031, 'item1' => 3094, 'item2' => 0, 'item3' => 0,
        'item4' => 0, 'item5' => 0, 'item6' => 0,
        'visionScore' => 25, 'wardsPlaced' => 10, 'wardsKilled' => 5,
        'visionWardsBoughtInGame' => 3, 'summoner1Id' => 4, 'summoner2Id' => 7,
        'spell1Casts' => 100, 'spell2Casts' => 50, 'spell3Casts' => 75,
        'spell4Casts' => 15, 'summoner1Casts' => 5, 'summoner2Casts' => 3,
        'firstBloodKill' => false, 'firstTowerKill' => false,
        'doubleKills' => 2, 'tripleKills' => 0, 'quadraKills' => 0, 'pentaKills' => 0,
        'objectivesStolen' => 0, 'timeCCingOthers' => 10,
        'totalTimeSpentDead' => 0, 'totalDamageDealtToTurrets' => 5000,
        'totalDamageShieldedOnTeammates' => 0, 'totalHealsOnTeammates' => 0,
        'allInPings' => 0, 'assistMePings' => 0, 'baitPings' => 0, 'basicPings' => 5,
        'commandPings' => 0, 'dangerPings' => 2, 'enemyMissingPings' => 1,
        'enemyVisionPings' => 0, 'getBackPings' => 0, 'holdPings' => 0,
        'needVisionPings' => 0, 'onMyWayPings' => 0, 'pushPings' => 0,
        'retreatPings' => 0, 'visionClearedPings' => 0,
        'challenges' => { 'laneMinionsFirst10Minutes' => 80, 'turretPlatesTaken' => 2 },
        'perks' => { 'styles' => [] }
      }
    end

    let(:match_body) do
      {
        'metadata' => { 'matchId' => 'BR1_9999' },
        'info' => {
          'gameCreation' => 1_700_000_000_000,
          'gameDuration' => 1800,
          'gameMode' => 'CLASSIC',
          'gameVersion' => '13.20.1',
          'participants' => [participant]
        }
      }.to_json
    end

    before do
      stub_request(:get, /riot-gateway.*match\//)
        .to_return(status: 200, body: match_body,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'parses match_id' do
      result = service.get_match_details(match_id: 'BR1_9999', region: 'BR')
      expect(result[:match_id]).to eq('BR1_9999')
    end

    it 'parses participant champion name as returned by Riot (CamelCase)' do
      result = service.get_match_details(match_id: 'BR1_9999', region: 'BR')
      champion = result[:participants].first[:champion_name]
      expect(champion).to eq('Jinx')
    end

    it 'includes kills, deaths, assists for the participant' do
      result = service.get_match_details(match_id: 'BR1_9999', region: 'BR')
      p = result[:participants].first
      expect(p[:kills]).to eq(10)
      expect(p[:deaths]).to eq(0)
      expect(p[:assists]).to eq(5)
    end

    it 'lowercases the teamPosition to match LoL role format' do
      result = service.get_match_details(match_id: 'BR1_9999', region: 'BR')
      expect(result[:participants].first[:role]).to eq('bottom')
    end

    it 'filters zero item IDs from the items array' do
      result = service.get_match_details(match_id: 'BR1_9999', region: 'BR')
      items = result[:participants].first[:items]
      expect(items).not_to include(0)
      expect(items).to include(3031, 3094)
    end
  end

  describe 'error class hierarchy' do
    it 'RateLimitError < RiotApiError < StandardError' do
      expect(RiotApiService::RateLimitError.ancestors).to include(
        RiotApiService::RiotApiError, StandardError
      )
    end

    it 'NotFoundError < RiotApiError < StandardError' do
      expect(RiotApiService::NotFoundError.ancestors).to include(
        RiotApiService::RiotApiError, StandardError
      )
    end

    it 'UnauthorizedError < RiotApiError < StandardError' do
      expect(RiotApiService::UnauthorizedError.ancestors).to include(
        RiotApiService::RiotApiError, StandardError
      )
    end
  end
end
