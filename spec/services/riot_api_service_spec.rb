require 'rails_helper'

RSpec.describe RiotApiService do
  let(:api_key) { 'test-api-key' }
  let(:service) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    it 'requires an API key' do
      expect { described_class.new }.not_to raise_error
    end

    it 'accepts custom API key' do
      expect(service.instance_variable_get(:@api_key)).to eq(api_key)
    end
  end

  describe '#get_summoner_by_name' do
    let(:summoner_name) { 'TestPlayer' }
    let(:region) { 'BR' }

    it 'fetches summoner data' do
      stub_request(:get, /br1.api.riotgames.com/)
        .to_return(
          status: 200,
          body: {
            id: 'summoner-id',
            puuid: 'puuid-123',
            name: 'TestPlayer',
            summonerLevel: 150,
            profileIconId: 4567
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = service.get_summoner_by_name(summoner_name: summoner_name, region: region)

      expect(result).to include(
        summoner_id: 'summoner-id',
        puuid: 'puuid-123',
        summoner_name: 'TestPlayer'
      )
    end

    it 'raises NotFoundError for non-existent summoner' do
      stub_request(:get, /br1.api.riotgames.com/)
        .to_return(status: 404)

      expect {
        service.get_summoner_by_name(summoner_name: summoner_name, region: region)
      }.to raise_error(RiotApiService::NotFoundError)
    end

    it 'raises RateLimitError when rate limited' do
      stub_request(:get, /br1.api.riotgames.com/)
        .to_return(status: 429, headers: { 'Retry-After' => '120' })

      expect {
        service.get_summoner_by_name(summoner_name: summoner_name, region: region)
      }.to raise_error(RiotApiService::RateLimitError)
    end
  end

  describe 'region mapping' do
    it 'maps BR to correct platform' do
      expect(service.send(:platform_for_region, 'BR')).to eq('BR1')
    end

    it 'raises error for unknown region' do
      expect {
        service.send(:platform_for_region, 'INVALID')
      }.to raise_error(RiotApiService::RiotApiError, /Unknown region/)
    end
  end
end
