require 'rails_helper'

RSpec.describe 'Players API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:other_organization) { create(:organization) }
  let(:other_user) { create(:user, organization: other_organization) }

  describe 'GET /api/v1/players' do
    let!(:players) { create_list(:player, 5, organization: organization) }

    context 'when authenticated' do
      it 'returns all players for the organization' do
        get '/api/v1/players', headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:players].size).to eq(5)
      end

      it 'filters by role' do
        top_player = create(:player, role: 'top', organization: organization)

        get '/api/v1/players', params: { role: 'top' }, headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:players].size).to eq(1)
        expect(json_response[:data][:players][0][:summoner_name]).to eq(top_player.summoner_name)
      end

      it 'includes pagination metadata' do
        get '/api/v1/players', headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:pagination]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/players'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/players' do
    let(:valid_attributes) do
      {
        player: {
          summoner_name: 'TestPlayer',
          real_name: 'Test User',
          role: 'mid',
          status: 'active'
        }
      }
    end

    context 'when authenticated as admin' do
      it 'creates a new player' do
        expect {
          post '/api/v1/players',
               params: valid_attributes.to_json,
               headers: auth_headers(user)
        }.to change(Player, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:player][:summoner_name]).to eq('TestPlayer')
      end

      it 'returns validation errors for invalid data' do
        invalid_attributes = { player: { summoner_name: '' } }

        post '/api/v1/players',
             params: invalid_attributes.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('VALIDATION_ERROR')
      end
    end

    context 'when authenticated as viewer' do
      let(:viewer) { create(:user, :viewer, organization: organization) }

      it 'returns forbidden' do
        post '/api/v1/players',
             params: valid_attributes.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/players/:id' do
    let(:player) { create(:player, organization: organization) }

    it 'returns the player' do
      get "/api/v1/players/#{player.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:success)
      expect(json_response[:data][:player][:id]).to eq(player.id)
    end

    it 'returns not found for non-existent player' do
      get '/api/v1/players/99999', headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/players/:id' do
    let(:player) { create(:player, organization: organization) }

    it 'updates the player' do
      patch "/api/v1/players/#{player.id}",
            params: { player: { summoner_name: 'UpdatedName' } }.to_json,
            headers: auth_headers(user)

      expect(response).to have_http_status(:success)
      expect(json_response[:data][:player][:summoner_name]).to eq('UpdatedName')
    end
  end

  describe 'DELETE /api/v1/players/:id' do
    let(:player) { create(:player, organization: organization) }
    let(:owner) { create(:user, :owner, organization: organization) }

    it 'deletes the player' do
      player_id = player.id

      expect {
        delete "/api/v1/players/#{player_id}", headers: auth_headers(owner)
      }.to change(Player, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /api/v1/players/:id/stats' do
    let(:player) { create(:player, organization: organization) }

    it 'returns player statistics' do
      get "/api/v1/players/#{player.id}/stats", headers: auth_headers(user)

      expect(response).to have_http_status(:success)
      expect(json_response[:data]).to include(:player, :overall, :recent_form)
    end
  end
end
