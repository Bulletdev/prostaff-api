# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PandascoreService, type: :model do
  subject(:service) { described_class.instance }

  before do
    # Clear any cached responses between examples
    Rails.cache.clear
    stub_const('ENV', ENV.to_h.merge('PANDASCORE_API_KEY' => 'test-api-key'))
  end

  describe '#fetch_upcoming_matches' do
    context 'when the API responds successfully' do
      let(:matches_payload) do
        [
          { 'id' => 1, 'name' => 'T1 vs Gen.G', 'begin_at' => 1.day.from_now.iso8601, 'league' => { 'name' => 'LCK' } },
          { 'id' => 2, 'name' => 'Cloud9 vs Team Liquid', 'begin_at' => 2.days.from_now.iso8601, 'league' => { 'name' => 'LCS' } }
        ]
      end

      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(
            status: 200,
            body: matches_payload.to_json,
            headers: { 'Content-Type' => 'application/json', 'X-Total' => '2' }
          )
      end

      it 'returns a hash with data array and pagination metadata' do
        result = service.fetch_upcoming_matches
        expect(result).to be_a(Hash)
        expect(result[:data]).to be_a(Array)
        expect(result[:total]).to be_a(Integer)
        expect(result[:page]).to be_present
        expect(result[:per_page]).to be_present
      end

      it 'returns match data from the API' do
        result = service.fetch_upcoming_matches
        expect(result[:data].size).to eq(2)
        expect(result[:data].first['id']).to eq(1)
      end

      it 'filters by league when league param is provided' do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .with(query: hash_including('filter[league_id]' => 'lck'))
          .to_return(
            status: 200,
            body: [matches_payload.first].to_json,
            headers: { 'Content-Type' => 'application/json', 'X-Total' => '1' }
          )

        result = service.fetch_upcoming_matches(league: 'lck')
        expect(result[:data]).to be_a(Array)
      end

      it 'accepts pagination parameters' do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(
            status: 200,
            body: [].to_json,
            headers: { 'Content-Type' => 'application/json', 'X-Total' => '0' }
          )

        result = service.fetch_upcoming_matches(per_page: 5, page: 2)
        expect(result[:page]).to eq(2)
        expect(result[:per_page]).to eq(5)
      end
    end

    context 'when the API returns 401 unauthorized' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(status: 401, body: '{"error":"Unauthorized"}')
      end

      it 'raises PandascoreError' do
        expect { service.fetch_upcoming_matches }
          .to raise_error(PandascoreService::PandascoreError, /unauthorized/i)
      end
    end

    context 'when the API returns 429 rate limited' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(status: 429, headers: { 'X-RateLimit-Reset' => '60' })
      end

      it 'raises RateLimitError' do
        expect { service.fetch_upcoming_matches }
          .to raise_error(PandascoreService::RateLimitError, /rate limit/i)
      end
    end

    context 'when the API returns 404' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(status: 503)
      end

      it 'raises PandascoreError' do
        expect { service.fetch_upcoming_matches }
          .to raise_error(PandascoreService::PandascoreError)
      end
    end

    context 'when PANDASCORE_API_KEY is not configured' do
      before do
        stub_const('ENV', ENV.to_h.merge('PANDASCORE_API_KEY' => nil))
        allow(service).to receive(:api_key).and_return(nil)
      end

      it 'raises PandascoreError about missing API key' do
        expect { service.fetch_upcoming_matches }
          .to raise_error(PandascoreService::PandascoreError, /api_key not configured/i)
      end
    end
  end

  describe '#fetch_past_matches' do
    let(:past_payload) do
      [
        { 'id' => 10, 'name' => 'LOUD vs paiN', 'begin_at' => 3.days.ago.iso8601, 'league' => { 'name' => 'CBLOL' } }
      ]
    end

    context 'when the API responds successfully' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/past/)
          .to_return(
            status: 200,
            body: past_payload.to_json,
            headers: { 'Content-Type' => 'application/json', 'X-Total' => '1' }
          )
      end

      it 'returns a hash with data array' do
        result = service.fetch_past_matches
        expect(result).to be_a(Hash)
        expect(result[:data]).to be_a(Array)
        expect(result[:total]).to be_a(Integer)
      end
    end

    context 'when rate limited' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/past/)
          .to_return(status: 429, headers: { 'X-RateLimit-Reset' => '60' })
      end

      it 'raises RateLimitError' do
        expect { service.fetch_past_matches }
          .to raise_error(PandascoreService::RateLimitError)
      end
    end
  end

  describe '#fetch_match_details' do
    context 'when match_id is blank' do
      it 'raises ArgumentError' do
        expect { service.fetch_match_details(nil) }.to raise_error(ArgumentError, /blank/i)
        expect { service.fetch_match_details('') }.to raise_error(ArgumentError, /blank/i)
      end
    end

    context 'when the match is found' do
      let(:match_data) { { 'id' => 42, 'name' => 'Worlds Final', 'videogame' => { 'name' => 'LoL' } } }

      before do
        stub_request(:get, /api\.pandascore\.co\/lol\/matches\/42/)
          .to_return(
            status: 200,
            body: match_data.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the match hash' do
        result = service.fetch_match_details(42)
        expect(result).to be_a(Hash)
        expect(result['id']).to eq(42)
      end
    end

    context 'when the match is not found' do
      before do
        stub_request(:get, /api\.pandascore\.co\/lol\/matches\/99999/)
          .to_return(status: 404, body: '{"error":"Not Found"}')
      end

      it 'raises NotFoundError' do
        expect { service.fetch_match_details(99999) }
          .to raise_error(PandascoreService::NotFoundError)
      end
    end
  end

  describe '#search_team' do
    context 'when team_name is blank' do
      it 'raises ArgumentError' do
        expect { service.search_team('') }.to raise_error(ArgumentError)
        expect { service.search_team(nil) }.to raise_error(ArgumentError)
      end
    end

    context 'when a team is found' do
      let(:team_data) { [{ 'id' => 1, 'name' => 'T1', 'videogame' => { 'name' => 'LoL' } }] }

      before do
        stub_request(:get, /api\.pandascore\.co\/lol\/teams/)
          .to_return(
            status: 200,
            body: team_data.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the first matching team' do
        result = service.search_team('T1')
        expect(result).to be_a(Hash)
        expect(result['name']).to eq('T1')
      end
    end

    context 'when no team is found (404)' do
      before do
        stub_request(:get, /api\.pandascore\.co\/lol\/teams/)
          .to_return(status: 404, body: '{"error":"Not Found"}')
      end

      it 'returns nil instead of raising' do
        result = service.search_team('NonExistentTeam')
        expect(result).to be_nil
      end
    end
  end

  describe '#clear_cache' do
    it 'clears the pandascore cache without raising' do
      expect { service.clear_cache }.not_to raise_error
    end
  end
end
