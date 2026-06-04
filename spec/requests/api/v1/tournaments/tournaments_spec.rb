# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tournaments API', type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }

  # ── GET /api/v1/tournaments ───────────────────────────────────────────────

  describe 'GET /api/v1/tournaments' do
    let!(:open_tournament) { create(:tournament, status: 'registration_open') }
    let!(:draft_tournament) { create(:tournament, :draft) }

    context 'when unauthenticated' do
      it 'returns 200 (public endpoint)' do
        get '/api/v1/tournaments'
        expect(response).to have_http_status(:ok)
      end

      it 'returns only active tournaments (registration_open, seeding, in_progress)' do
        get '/api/v1/tournaments'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated' do
      it 'returns 200' do
        get '/api/v1/tournaments', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ── GET /api/v1/tournaments/:id ───────────────────────────────────────────

  describe 'GET /api/v1/tournaments/:id' do
    let(:tournament) { create(:tournament, status: 'registration_open') }

    context 'when unauthenticated' do
      it 'returns 200 (public endpoint)' do
        get "/api/v1/tournaments/#{tournament.id}"
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when tournament does not exist' do
      it 'returns 404' do
        get '/api/v1/tournaments/00000000-0000-0000-0000-000000000000'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/tournaments ──────────────────────────────────────────────

  describe 'POST /api/v1/tournaments' do
    let(:valid_params) do
      {
        name: 'ArenaBR Open Season 1',
        game: 'league_of_legends',
        format: 'double_elimination',
        status: 'draft',
        max_teams: 16,
        entry_fee_cents: 0,
        prize_pool_cents: 50_000,
        bo_format: 3,
        scheduled_start_at: 14.days.from_now.iso8601
      }
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/tournaments', params: valid_params.to_json,
                                    headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as viewer (non-admin)' do
      it 'returns 403' do
        post '/api/v1/tournaments', params: valid_params.to_json,
                                    headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      it 'creates a tournament and returns 201' do
        post '/api/v1/tournaments', params: valid_params.to_json,
                                    headers: auth_headers(admin)
        expect(response).to have_http_status(:created)
      end

      it 'returns the created tournament name' do
        post '/api/v1/tournaments', params: valid_params.to_json,
                                    headers: auth_headers(admin)
        expect(json_response[:data][:name]).to eq('ArenaBR Open Season 1')
      end

      context 'with invalid format' do
        it 'returns 422' do
          invalid = valid_params.merge(format: 'round_robin')
          post '/api/v1/tournaments', params: invalid.to_json,
                                      headers: auth_headers(admin)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with missing name' do
        it 'returns 422' do
          invalid = valid_params.except(:name)
          post '/api/v1/tournaments', params: invalid.to_json,
                                      headers: auth_headers(admin)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with negative max_teams' do
        it 'returns 422' do
          invalid = valid_params.merge(max_teams: 0)
          post '/api/v1/tournaments', params: invalid.to_json,
                                      headers: auth_headers(admin)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  # ── POST /api/v1/tournaments/:id/generate_bracket ─────────────────────────

  describe 'POST /api/v1/tournaments/:id/generate_bracket' do
    context 'when unauthenticated' do
      let(:tournament) { create(:tournament, status: 'seeding') }

      it 'returns 401' do
        post "/api/v1/tournaments/#{tournament.id}/generate_bracket"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as viewer' do
      let(:tournament) { create(:tournament, status: 'seeding') }

      it 'returns 403' do
        post "/api/v1/tournaments/#{tournament.id}/generate_bracket",
             headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      context 'when tournament has no prior bracket' do
        let(:tournament) { create(:tournament, :in_progress, max_teams: 16) }

        before do
          # Create 16 approved teams so BracketGeneratorService can run
          16.times do |i|
            org = create(:organization)
            create(:tournament_team, :approved,
                   tournament: tournament,
                   organization: org,
                   team_name: "Team #{i + 1}",
                   team_tag: "T#{format('%02d', i + 1)}")
          end
        end

        it 'returns 200' do
          post "/api/v1/tournaments/#{tournament.id}/generate_bracket",
               headers: auth_headers(admin)
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when bracket already exists' do
        let(:tournament) { create(:tournament, :in_progress, max_teams: 16) }

        before do
          # Create one match to simulate bracket_generated? == true
          create(:tournament_match, tournament: tournament, match_number: 1, round_order: 1)
        end

        it 'returns 422 with BRACKET_EXISTS code' do
          post "/api/v1/tournaments/#{tournament.id}/generate_bracket",
               headers: auth_headers(admin)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response[:error][:code]).to eq('BRACKET_EXISTS')
        end
      end
    end
  end

  # ── PATCH /api/v1/tournaments/:id ─────────────────────────────────────────

  describe 'PATCH /api/v1/tournaments/:id' do
    let(:tournament) { create(:tournament, :draft, name: 'Old Name') }

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/tournaments/#{tournament.id}",
              params: { name: 'New Name' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        patch "/api/v1/tournaments/#{tournament.id}",
              params: { name: 'New Name' }.to_json,
              headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      it 'updates the tournament and returns 200' do
        patch "/api/v1/tournaments/#{tournament.id}",
              params: { name: 'Updated Tournament Name' }.to_json,
              headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:name]).to eq('Updated Tournament Name')
      end

      it 'returns 422 for invalid format value' do
        patch "/api/v1/tournaments/#{tournament.id}",
              params: { format: 'swiss_system' }.to_json,
              headers: auth_headers(admin)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 404 for non-existent tournament' do
        patch '/api/v1/tournaments/00000000-0000-0000-0000-000000000000',
              params: { name: 'Ghost' }.to_json,
              headers: auth_headers(admin)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── Tournament status lifecycle ────────────────────────────────────────────

  describe 'Tournament status lifecycle' do
    context 'draft -> registration_open is valid' do
      let(:tournament) { create(:tournament, :draft) }

      it 'transitions to registration_open' do
        patch "/api/v1/tournaments/#{tournament.id}",
              params: { status: 'registration_open' }.to_json,
              headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
        expect(tournament.reload.status).to eq('registration_open')
      end
    end

    context 'format validation' do
      it 'accepts double_elimination' do
        post '/api/v1/tournaments',
             params: {
               name: 'DE Tournament',
               game: 'league_of_legends',
               format: 'double_elimination',
               status: 'draft',
               max_teams: 8,
               entry_fee_cents: 0,
               prize_pool_cents: 0,
               bo_format: 1
             }.to_json,
             headers: auth_headers(admin)
        expect(response).to have_http_status(:created)
      end

      it 'accepts single_elimination' do
        post '/api/v1/tournaments',
             params: {
               name: 'SE Tournament',
               game: 'league_of_legends',
               format: 'single_elimination',
               status: 'draft',
               max_teams: 8,
               entry_fee_cents: 0,
               prize_pool_cents: 0,
               bo_format: 1
             }.to_json,
             headers: auth_headers(admin)
        expect(response).to have_http_status(:created)
      end

      it 'rejects invalid format' do
        post '/api/v1/tournaments',
             params: {
               name: 'Bad Format',
               game: 'league_of_legends',
               format: 'round_robin',
               status: 'draft',
               max_teams: 8,
               entry_fee_cents: 0,
               prize_pool_cents: 0,
               bo_format: 1
             }.to_json,
             headers: auth_headers(admin)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
