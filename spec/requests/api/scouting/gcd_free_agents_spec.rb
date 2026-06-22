# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/scouting/gcd-free-agents', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, role: 'coach') }
  let(:headers) { auth_headers(user) }

  describe 'authentication' do
    it 'returns 401 without a token' do
      get '/api/v1/scouting/gcd-free-agents'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'with valid auth' do
    let!(:free_agent) do
      create(:market_registration, :free_agent,
             player_external_name: 'Broxah',
             region: 'Korea',
             role: 'Jng',
             solo_queue_id: 'Broxah#KR1',
             snapshot_date: Date.current)
    end

    let!(:contracted) do
      create(:market_registration,
             player_external_name: 'Faker',
             team_name: 'T1',
             region: 'Korea',
             contract_end_date: 6.months.from_now.to_date,
             snapshot_date: Date.current)
    end

    let!(:old_snapshot) do
      create(:market_registration, :free_agent,
             player_external_name: 'OldPlayer',
             snapshot_date: 10.days.ago.to_date)
    end

    it 'returns only free agents from recent snapshots' do
      get '/api/v1/scouting/gcd-free-agents', headers: headers
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      names = body.dig('data', 'free_agents').map { |r| r['player_external_name'] }
      expect(names).to include('Broxah')
      expect(names).not_to include('Faker')
      expect(names).not_to include('OldPlayer')
    end

    it 'includes solo_queue_id and contract_status in response' do
      get '/api/v1/scouting/gcd-free-agents', headers: headers
      body = JSON.parse(response.body)
      agent = body.dig('data', 'free_agents').find { |r| r['player_external_name'] == 'Broxah' }
      expect(agent['solo_queue_id']).to eq('Broxah#KR1')
      expect(agent['contract_status']).to eq('expired')
      expect(agent['already_watching']).to be(false)
    end

    it 'filters by region' do
      create(:market_registration, :free_agent,
             player_external_name: 'Guma',
             region: 'Brazil',
             snapshot_date: Date.current)

      get '/api/v1/scouting/gcd-free-agents', params: { region: 'Korea' }, headers: headers
      body = JSON.parse(response.body)
      names = body.dig('data', 'free_agents').map { |r| r['player_external_name'] }
      expect(names).to include('Broxah')
      expect(names).not_to include('Guma')
    end

    it 'filters by role' do
      create(:market_registration, :free_agent,
             player_external_name: 'TopLaner',
             role: 'Top',
             snapshot_date: Date.current)

      get '/api/v1/scouting/gcd-free-agents', params: { role: 'Jng' }, headers: headers
      body = JSON.parse(response.body)
      names = body.dig('data', 'free_agents').map { |r| r['player_external_name'] }
      expect(names).to include('Broxah')
      expect(names).not_to include('TopLaner')
    end

    it 'filters by with_soloqueue=true' do
      create(:market_registration, :free_agent,
             player_external_name: 'NoSoloQ',
             solo_queue_id: nil,
             snapshot_date: Date.current)

      get '/api/v1/scouting/gcd-free-agents', params: { with_soloqueue: 'true' }, headers: headers
      body = JSON.parse(response.body)
      names = body.dig('data', 'free_agents').map { |r| r['player_external_name'] }
      expect(names).to include('Broxah')
      expect(names).not_to include('NoSoloQ')
    end

    it 'returns correct pagination' do
      get '/api/v1/scouting/gcd-free-agents', headers: headers
      body = JSON.parse(response.body)
      pagination = body.dig('data', 'pagination')
      expect(pagination['total_count']).to eq(1)
      expect(pagination['total_pages']).to eq(1)
      expect(pagination['current_page']).to eq(1)
    end

    context 'already_watching' do
      let!(:target) do
        create(:scouting_target, professional_name: 'Broxah', summoner_name: 'Broxah#KR1', region: 'KR', role: 'jungle')
      end
      let!(:watchlist_entry) do
        create(:scouting_watchlist, organization: organization, scouting_target: target, added_by: user)
      end

      it 'marks players on org watchlist as already_watching' do
        get '/api/v1/scouting/gcd-free-agents', headers: headers
        body = JSON.parse(response.body)
        agent = body.dig('data', 'free_agents').find { |r| r['player_external_name'] == 'Broxah' }
        expect(agent['already_watching']).to be(true)
      end

      it 'cross-org isolation: another org watchlist does not affect already_watching' do
        other_org = create(:organization)
        other_user = create(:user, organization: other_org, role: 'coach')

        get '/api/v1/scouting/gcd-free-agents', headers: auth_headers(other_user)
        body = JSON.parse(response.body)
        agent = body.dig('data', 'free_agents').find { |r| r['player_external_name'] == 'Broxah' }
        expect(agent['already_watching']).to be(false)
      end
    end
  end
end
