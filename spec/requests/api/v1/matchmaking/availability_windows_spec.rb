# frozen_string_literal: true

require 'rails_helper'

# NOTE: AvailabilityWindow includes OrganizationScoped which applies a default_scope
# via Current.organization_id. Outside request context, Current.organization_id is nil,
# so count/query helpers use unscoped to avoid the empty-scope false negative.

RSpec.describe 'Matchmaking AvailabilityWindows', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  # -----------------------------------------------------------------------
  # GET /api/v1/matchmaking/availability-windows
  # -----------------------------------------------------------------------
  describe 'GET /api/v1/matchmaking/availability-windows' do
    let!(:windows) { create_list(:availability_window, 3, organization: organization) }

    context 'when authenticated' do
      it 'returns 200 with the org windows' do
        get '/api/v1/matchmaking/availability-windows', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:availability_windows].size).to eq(3)
      end

      it 'does not return windows from other organizations' do
        other_org = create(:organization)
        create(:availability_window, organization: other_org)

        get '/api/v1/matchmaking/availability-windows', headers: auth_headers(user)

        window_ids = json_response[:data][:availability_windows].map { |w| w[:id] }
        expect(window_ids.size).to eq(3)
      end

      it 'filters by game when param is provided' do
        create(:availability_window, organization: organization, game: 'valorant')

        get '/api/v1/matchmaking/availability-windows',
            params: { game: 'league_of_legends' },
            headers: auth_headers(user)

        games = json_response[:data][:availability_windows].map { |w| w[:game] }.uniq
        expect(games).to eq(['league_of_legends'])
      end

      it 'filters by active when param is true' do
        create(:availability_window, :inactive, organization: organization)

        get '/api/v1/matchmaking/availability-windows',
            params: { active: 'true' },
            headers: auth_headers(user)

        expect(json_response[:data][:availability_windows].size).to eq(3)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/matchmaking/availability-windows'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'does not expose first org windows to second org' do
        get '/api/v1/matchmaking/availability-windows', headers: auth_headers(other_user)

        window_ids = json_response[:data][:availability_windows].map { |w| w[:id] }
        windows.each { |w| expect(window_ids).not_to include(w.id) }
      end
    end
  end

  # -----------------------------------------------------------------------
  # GET /api/v1/matchmaking/availability-windows/:id
  # -----------------------------------------------------------------------
  describe 'GET /api/v1/matchmaking/availability-windows/:id' do
    let!(:window) { create(:availability_window, organization: organization) }

    context 'when the window belongs to the user org' do
      it 'returns 200 with the window data' do
        get "/api/v1/matchmaking/availability-windows/#{window.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:availability_window][:id]).to eq(window.id)
      end
    end

    context 'when the window belongs to another org' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'returns 404 (no data leakage)' do
        get "/api/v1/matchmaking/availability-windows/#{window.id}", headers: auth_headers(other_user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # -----------------------------------------------------------------------
  # POST /api/v1/matchmaking/availability-windows
  # -----------------------------------------------------------------------
  describe 'POST /api/v1/matchmaking/availability-windows' do
    let(:valid_params) do
      {
        availability_window: {
          day_of_week: 1,
          start_hour: 18,
          end_hour: 22,
          timezone: 'America/Sao_Paulo',
          game: 'league_of_legends',
          region: 'BR',
          tier_preference: 'any',
          active: true
        }
      }
    end

    context 'with valid params' do
      it 'creates a window and returns 201' do
        # Use unscoped because OrganizationScoped default_scope returns empty set
        # when Current.organization_id is nil (outside request context).
        expect do
          post '/api/v1/matchmaking/availability-windows',
               params: valid_params.to_json,
               headers: auth_headers(user)
        end.to change { AvailabilityWindow.unscoped.count }.by(1)

        expect(response).to have_http_status(:created)
      end

      it 'associates the window with the current organization' do
        post '/api/v1/matchmaking/availability-windows',
             params: valid_params.to_json,
             headers: auth_headers(user)

        expect(AvailabilityWindow.unscoped.last.organization_id).to eq(organization.id)
      end
    end

    context 'when end_hour is before start_hour' do
      it 'returns 422' do
        bad_params = valid_params.deep_merge(availability_window: { start_hour: 22, end_hour: 18 })

        post '/api/v1/matchmaking/availability-windows',
             params: bad_params.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when game is invalid' do
      it 'returns 422' do
        bad_params = valid_params.deep_merge(availability_window: { game: 'invalid_game' })

        post '/api/v1/matchmaking/availability-windows',
             params: bad_params.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/matchmaking/availability-windows', params: valid_params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # -----------------------------------------------------------------------
  # PATCH /api/v1/matchmaking/availability-windows/:id
  # -----------------------------------------------------------------------
  describe 'PATCH /api/v1/matchmaking/availability-windows/:id' do
    let!(:window) { create(:availability_window, organization: organization, start_hour: 18, end_hour: 22) }

    context 'with valid params' do
      it 'updates the window and returns 200' do
        patch "/api/v1/matchmaking/availability-windows/#{window.id}",
              params: { availability_window: { start_hour: 19 } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(window.reload.start_hour).to eq(19)
      end
    end

    context 'when window belongs to another org' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'returns 404' do
        patch "/api/v1/matchmaking/availability-windows/#{window.id}",
              params: { availability_window: { start_hour: 20 } }.to_json,
              headers: auth_headers(other_user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # -----------------------------------------------------------------------
  # DELETE /api/v1/matchmaking/availability-windows/:id
  # -----------------------------------------------------------------------
  describe 'DELETE /api/v1/matchmaking/availability-windows/:id' do
    let!(:window) { create(:availability_window, organization: organization) }

    context 'when the window belongs to the user org' do
      it 'deletes the window and returns 200' do
        expect do
          delete "/api/v1/matchmaking/availability-windows/#{window.id}",
                 headers: auth_headers(user)
        end.to change { AvailabilityWindow.unscoped.count }.by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the window belongs to another org' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'returns 404 (no data leakage)' do
        delete "/api/v1/matchmaking/availability-windows/#{window.id}",
               headers: auth_headers(other_user)

        expect(response).to have_http_status(:not_found)
        expect(AvailabilityWindow.unscoped.exists?(window.id)).to be true
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        delete "/api/v1/matchmaking/availability-windows/#{window.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
