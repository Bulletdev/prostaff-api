# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Competitive Pro Matches API', type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }
  let(:owner)        { create(:user, :owner, organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }

  let(:pandascore_upcoming_response) do
    {
      data: [
        { 'id' => 1, 'name' => 'T1 vs Gen.G', 'begin_at' => 1.day.from_now.iso8601, 'league' => { 'name' => 'LCK' } }
      ],
      total: 1,
      page: 1,
      per_page: 20
    }
  end

  let(:pandascore_past_response) do
    {
      data: [
        { 'id' => 10, 'name' => 'LOUD vs paiN', 'begin_at' => 3.days.ago.iso8601, 'league' => { 'name' => 'CBLOL' } }
      ],
      total: 1,
      page: 1,
      per_page: 20
    }
  end

  describe 'GET /api/v1/competitive/pro-matches' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/competitive/pro-matches'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      let!(:matches) do
        create_list(:competitive_match, 3, organization: organization,
                                          match_date: 5.days.ago)
      end

      it 'returns 200 with matches list' do
        get '/api/v1/competitive/pro-matches', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:matches]).to be_a(Array)
      end

      it 'includes pagination metadata' do
        get '/api/v1/competitive/pro-matches', headers: auth_headers(admin)
        expect(json_response[:data][:pagination]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end

      it 'returns only matches for the current organization' do
        get '/api/v1/competitive/pro-matches', headers: auth_headers(admin)
        expect(json_response[:data][:matches].size).to eq(3)
      end

      it 'allows filtering by tournament' do
        create(:competitive_match, organization: organization,
                                   tournament_name: 'CBLOL 2025',
                                   match_date: 2.days.ago)

        get '/api/v1/competitive/pro-matches',
            params: { tournament: 'CBLOL 2025' },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        tournament_matches = json_response[:data][:matches]
        expect(tournament_matches).to all(include(tournament_name: 'CBLOL 2025'))
      end

      it 'allows filtering by date range' do
        create(:competitive_match, organization: organization, match_date: 10.days.ago)

        get '/api/v1/competitive/pro-matches',
            params: { start_date: 7.days.ago.to_date.to_s, end_date: Date.today.to_s },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }
      let!(:org_match) { create(:competitive_match, organization: organization) }

      it 'does not expose matches from another organization' do
        get '/api/v1/competitive/pro-matches', headers: auth_headers(other_user)

        expect(response).to have_http_status(:ok)
        returned_ids = json_response[:data][:matches].map { |m| m[:id] }
        expect(returned_ids).not_to include(org_match.id)
      end
    end
  end

  describe 'GET /api/v1/competitive/pro-matches/:id' do
    let!(:match) { create(:competitive_match, organization: organization) }

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/competitive/pro-matches/#{match.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns the match details' do
        get "/api/v1/competitive/pro-matches/#{match.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:match][:id]).to eq(match.id)
      end
    end

    context 'when the match does not exist' do
      it 'returns 404' do
        get '/api/v1/competitive/pro-matches/99999999', headers: auth_headers(admin)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'returns 404 when trying to access another org match' do
        get "/api/v1/competitive/pro-matches/#{match.id}", headers: auth_headers(other_user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/competitive/pro-matches/upcoming' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/competitive/pro-matches/upcoming'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated and PandaScore succeeds' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(
            status: 200,
            body: [{ 'id' => 1, 'name' => 'T1 vs Gen.G', 'begin_at' => 1.day.from_now.iso8601 }].to_json,
            headers: { 'Content-Type' => 'application/json', 'X-Total' => '1' }
          )
        Rails.cache.clear
      end

      it 'returns 200 with matches from PandaScore' do
        get '/api/v1/competitive/pro-matches/upcoming', headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:matches]).to be_a(Array)
        expect(json_response[:data][:source]).to eq('pandascore')
      end

      it 'includes pagination metadata' do
        get '/api/v1/competitive/pro-matches/upcoming', headers: auth_headers(admin)

        expect(json_response[:data][:pagination]).to include(
          :current_page, :per_page, :total_count, :total_pages
        )
      end
    end

    context 'when PandaScore returns 429 rate limited' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(status: 429, headers: { 'X-RateLimit-Reset' => '60' })
        Rails.cache.clear
      end

      it 'returns 429' do
        get '/api/v1/competitive/pro-matches/upcoming', headers: auth_headers(admin)
        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context 'when PandaScore returns 401 unauthorized' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/upcoming/)
          .to_return(status: 401, body: '{"error":"Unauthorized"}')
        Rails.cache.clear
      end

      it 'returns 503 service unavailable' do
        get '/api/v1/competitive/pro-matches/upcoming', headers: auth_headers(admin)
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  describe 'GET /api/v1/competitive/pro-matches/past' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/competitive/pro-matches/past'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated and PandaScore succeeds' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/past/)
          .to_return(
            status: 200,
            body: [{ 'id' => 10, 'name' => 'LOUD vs paiN', 'begin_at' => 3.days.ago.iso8601 }].to_json,
            headers: { 'Content-Type' => 'application/json', 'X-Total' => '1' }
          )
        Rails.cache.clear
      end

      it 'returns 200' do
        get '/api/v1/competitive/pro-matches/past', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:matches]).to be_a(Array)
      end
    end

    context 'when PandaScore returns 429' do
      before do
        stub_request(:get, /api\.pandascore\.co\/matches\/past/)
          .to_return(status: 429)
        Rails.cache.clear
      end

      it 'returns 429' do
        get '/api/v1/competitive/pro-matches/past', headers: auth_headers(admin)
        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'POST /api/v1/competitive/pro-matches/refresh' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/competitive/pro-matches/refresh'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as owner' do
      it 'returns 200 and clears cache' do
        post '/api/v1/competitive/pro-matches/refresh', headers: auth_headers(owner)
        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to match(/cache cleared/i)
      end
    end

    context 'when authenticated as admin (not owner)' do
      it 'returns 403 forbidden' do
        post '/api/v1/competitive/pro-matches/refresh', headers: auth_headers(admin)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403 forbidden' do
        post '/api/v1/competitive/pro-matches/refresh', headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/competitive/pro-matches/sync-from-scraper' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/competitive/pro-matches/sync-from-scraper',
             params: { league: 'CBLOL', our_team: 'paiN Gaming' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      before do
        allow(Competitive::SyncScraperMatchesJob).to receive(:perform_later).and_return(
          double('job', job_id: 'test-job-id-123')
        )
      end

      it 'enqueues the job and returns 202 accepted' do
        post '/api/v1/competitive/pro-matches/sync-from-scraper',
             params: { league: 'CBLOL', our_team: 'paiN Gaming' }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:accepted)
        expect(json_response[:data][:league]).to eq('CBLOL')
        expect(json_response[:data][:our_team]).to eq('paiN Gaming')
      end

      it 'returns 422 when league is missing' do
        post '/api/v1/competitive/pro-matches/sync-from-scraper',
             params: { our_team: 'paiN Gaming' }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 422 when our_team is missing' do
        post '/api/v1/competitive/pro-matches/sync-from-scraper',
             params: { league: 'CBLOL' }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'filtering by match_date (no status column)' do
    let!(:past_match) do
      create(:competitive_match, organization: organization,
                                 match_date: 10.days.ago,
                                 tournament_name: 'Past Tournament')
    end
    let!(:future_match) do
      create(:competitive_match, organization: organization,
                                 match_date: 5.days.from_now,
                                 tournament_name: 'Future Tournament')
    end

    it 'retrieves all matches without status filter' do
      get '/api/v1/competitive/pro-matches', headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:matches].size).to eq(2)
    end

    it 'can filter by date range to get only past matches' do
      get '/api/v1/competitive/pro-matches',
          params: { start_date: 30.days.ago.to_date.to_s, end_date: Date.yesterday.to_s },
          headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:matches].size).to eq(1)
      expect(json_response[:data][:matches].first[:tournament_name]).to eq('Past Tournament')
    end
  end
end
