# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Scrims API', type: :request do
  let(:organization) { create(:organization, tier: 'tier_2_semi_pro') }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }
  let(:opponent)     { create(:opponent_team) }

  describe 'GET /api/v1/scrims/scrims' do
    let!(:upcoming_scrim) { create(:scrim, organization: organization, scheduled_at: 3.days.from_now) }
    let!(:past_scrim)     { create(:scrim, :past, organization: organization) }

    context 'when authenticated' do
      it 'returns 200 with list of scrims' do
        get '/api/v1/scrims/scrims', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:scrims]).to be_an(Array)
      end

      it 'includes pagination metadata' do
        get '/api/v1/scrims/scrims', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:meta]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end

      it 'returns only scrims belonging to current organization' do
        other_org   = create(:organization, tier: 'tier_2_semi_pro')
        other_scrim = create(:scrim, organization: other_org)

        get '/api/v1/scrims/scrims', headers: auth_headers(user)

        returned_ids = json_response[:data][:scrims].map { |s| s[:id] }
        expect(returned_ids).not_to include(other_scrim.id)
      end

      context 'status filter: upcoming' do
        it 'returns only upcoming scrims' do
          get '/api/v1/scrims/scrims', params: { status: 'upcoming' }, headers: auth_headers(user)

          expect(response).to have_http_status(:ok)
          scrims = json_response[:data][:scrims]
          expect(scrims).to all(satisfy { |s| s[:status] == 'upcoming' })
        end
      end

      context 'status filter: completed' do
        it 'returns only completed scrims' do
          create(:scrim, :completed, :past, organization: organization)

          get '/api/v1/scrims/scrims', params: { status: 'completed' }, headers: auth_headers(user)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'pagination' do
        it 'respects per_page parameter' do
          create_list(:scrim, 5, organization: organization)

          get '/api/v1/scrims/scrims', params: { per_page: 2, page: 1 }, headers: auth_headers(user)

          expect(response).to have_http_status(:ok)
          expect(json_response[:data][:scrims].size).to be <= 2
        end
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/scrims/scrims'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization, tier: 'tier_2_semi_pro') }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'does not expose scrims from another organization' do
        get '/api/v1/scrims/scrims', headers: auth_headers(other_user)

        returned_ids = json_response[:data][:scrims].map { |s| s[:id] }
        expect(returned_ids).not_to include(upcoming_scrim.id)
        expect(returned_ids).not_to include(past_scrim.id)
      end
    end
  end

  describe 'GET /api/v1/scrims/scrims/:id' do
    let!(:scrim) { create(:scrim, organization: organization) }

    context 'when authenticated' do
      it 'returns 200 with scrim data' do
        get "/api/v1/scrims/scrims/#{scrim.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to be_present
      end

      it 'returns 404 for a scrim belonging to another organization' do
        other_scrim = create(:scrim, organization: create(:organization, tier: 'tier_2_semi_pro'))

        get "/api/v1/scrims/scrims/#{other_scrim.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/scrims/scrims/#{scrim.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/scrims/scrims' do
    let(:valid_params) do
      {
        scrim: {
          scheduled_at: 2.days.from_now.iso8601,
          games_planned: 3,
          scrim_type: 'practice',
          focus_area: 'draft'
        }
      }
    end

    context 'when authenticated as admin' do
      it 'creates a scrim and returns 201' do
        post '/api/v1/scrims/scrims',
             params: valid_params.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:created)
      end

      it 'persists a new scrim for the organization' do
        expect do
          post '/api/v1/scrims/scrims',
               params: valid_params.to_json,
               headers: auth_headers(user)
        end.to change { Scrim.unscoped.count }.by(1)
      end

      it 'creates an opponent team when opponent_team_name is provided' do
        params = valid_params.deep_merge(scrim: { opponent_team_name: 'Rival Squad' })

        post '/api/v1/scrims/scrims', params: params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:created)
        expect(OpponentTeam.find_by(name: 'Rival Squad')).to be_present
      end

      it 'returns 403 when organization cannot create more scrims' do
        allow_any_instance_of(Organization).to receive(:can_create_scrim?).and_return(false)

        post '/api/v1/scrims/scrims', params: valid_params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 422 for invalid scrim data' do
        invalid_params = { scrim: { games_planned: -1 } }

        post '/api/v1/scrims/scrims', params: invalid_params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/scrims/scrims', params: valid_params.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/scrims/scrims/:id' do
    let!(:scrim) { create(:scrim, organization: organization) }

    context 'when authenticated as admin' do
      it 'updates the scrim and returns 200' do
        patch "/api/v1/scrims/scrims/#{scrim.id}",
              params: { scrim: { focus_area: 'teamfight' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
      end

      it 'returns 404 for scrim from another organization' do
        other_scrim = create(:scrim, organization: create(:organization, tier: 'tier_2_semi_pro'))

        patch "/api/v1/scrims/scrims/#{other_scrim.id}",
              params: { scrim: { focus_area: 'macro' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/scrims/scrims/#{scrim.id}",
              params: { scrim: { focus_area: 'late_game' } }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/scrims/scrims/:id' do
    let!(:scrim) { create(:scrim, organization: organization) }

    context 'when authenticated as admin' do
      it 'destroys the scrim and returns 204' do
        expect do
          delete "/api/v1/scrims/scrims/#{scrim.id}", headers: auth_headers(user)
        end.to change { Scrim.unscoped.count }.by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns 404 for scrim from another organization' do
        other_scrim = create(:scrim, organization: create(:organization, tier: 'tier_2_semi_pro'))

        delete "/api/v1/scrims/scrims/#{other_scrim.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        delete "/api/v1/scrims/scrims/#{scrim.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/scrims/scrims/:id/add_game' do
    let!(:scrim) { create(:scrim, organization: organization, games_planned: 3, games_completed: 0, game_results: []) }

    context 'when authenticated as admin' do
      it 'records a game result and returns 200' do
        post "/api/v1/scrims/scrims/#{scrim.id}/add_game",
             params: { victory: true, duration: 1800, notes: 'Good early game' }.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
      end

      it 'increments games_completed' do
        expect do
          post "/api/v1/scrims/scrims/#{scrim.id}/add_game",
               params: { victory: false }.to_json,
               headers: auth_headers(user)
        end.to change { scrim.reload.games_completed }.by(1)
      end

      it 'returns 404 for scrim from another organization' do
        other_scrim = create(:scrim, organization: create(:organization, tier: 'tier_2_semi_pro'), games_planned: 3, games_completed: 0)

        post "/api/v1/scrims/scrims/#{other_scrim.id}/add_game",
             params: { victory: true }.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/scrims/scrims/#{scrim.id}/add_game",
             params: { victory: true }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/scrims/scrims/calendar' do
    let!(:scrim_this_month) do
      create(:scrim, organization: organization, scheduled_at: Date.current.change(day: 15).to_time)
    end

    context 'when authenticated' do
      it 'returns scrims within the default date range' do
        get '/api/v1/scrims/scrims/calendar', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to include(:scrims, :start_date, :end_date)
      end

      it 'returns scrims within a custom date range' do
        start_date = Date.current.beginning_of_month.to_s
        end_date   = Date.current.end_of_month.to_s

        get '/api/v1/scrims/scrims/calendar',
            params: { start_date: start_date, end_date: end_date },
            headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:scrims]).to be_an(Array)
      end

      it 'does not return scrims from another organization' do
        other_scrim = create(:scrim,
                             organization: create(:organization, tier: 'tier_2_semi_pro'),
                             scheduled_at: Date.current.change(day: 15).to_time)

        get '/api/v1/scrims/scrims/calendar', headers: auth_headers(user)

        returned_ids = json_response[:data][:scrims].map { |s| s[:id] }
        expect(returned_ids).not_to include(other_scrim.id)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/scrims/scrims/calendar'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/scrims/scrims/analytics' do
    context 'when authenticated' do
      it 'returns 200 with analytics data' do
        get '/api/v1/scrims/scrims/analytics', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:overall_stats]).to be_present
      end

      it 'returns overall_stats with expected fields' do
        get '/api/v1/scrims/scrims/analytics', headers: auth_headers(user)

        overall = json_response[:overall_stats]
        expect(overall).to include(:total_scrims, :total_games, :wins, :losses, :win_rate)
      end

      it 'returns win_rate within [0, 100]' do
        create(:scrim, :past, :completed, organization: organization,
               game_results: [{ 'victory' => true }, { 'victory' => false }])

        get '/api/v1/scrims/scrims/analytics', headers: auth_headers(user)

        win_rate = json_response[:overall_stats][:win_rate].to_f
        expect(win_rate).to be_between(0.0, 100.0)
      end

      it 'accepts a custom days parameter' do
        get '/api/v1/scrims/scrims/analytics', params: { days: 7 }, headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/scrims/scrims/analytics'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
