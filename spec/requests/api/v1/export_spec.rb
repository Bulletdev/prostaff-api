# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Export endpoints', type: :request do
  let(:org)    { create(:organization) }
  let(:user)   { create(:user, :admin, organization: org) }
  let(:player) { create(:player, organization: org) }
  let(:match)  { create(:match, organization: org) }

  # ---------------------------------------------------------------------------
  # GET /api/v1/players/:id/stats/export
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players/:id/stats/export (JSON)' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/players/#{player.id}/stats/export"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a player from another org' do
      let(:other_player) { create(:player, organization: create(:organization)) }

      it 'returns 404' do
        get "/api/v1/players/#{other_player.id}/stats/export", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with valid player (no stats)' do
      it 'returns 200' do
        get "/api/v1/players/#{player.id}/stats/export", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns player, total_games and stats keys' do
        get "/api/v1/players/#{player.id}/stats/export", headers: auth_headers(user)
        data = json_response[:data]
        expect(data).to have_key(:player)
        expect(data).to have_key(:total_games)
        expect(data).to have_key(:stats)
      end

      it 'returns zero total_games when no stats exist' do
        get "/api/v1/players/#{player.id}/stats/export", headers: auth_headers(user)
        expect(json_response[:data][:total_games]).to eq(0)
      end
    end

    context 'with non-existent player' do
      it 'returns 404' do
        get '/api/v1/players/0/stats/export', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/players/:id/stats/export (CSV)' do
    context 'when authenticated' do
      it 'returns 200 with text/csv content-type' do
        get "/api/v1/players/#{player.id}/stats/export.csv", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
      end

      it 'includes CSV headers in response body' do
        get "/api/v1/players/#{player.id}/stats/export.csv", headers: auth_headers(user)
        first_line = response.body.lines.first.strip
        expect(first_line).to include('kills', 'deaths', 'assists', 'champion', 'role')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/matches/:id/export
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/matches/:id/export (JSON)' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/matches/#{match.id}/export"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a match from another org' do
      let(:other_match) { create(:match, organization: create(:organization)) }

      it 'returns 404' do
        get "/api/v1/matches/#{other_match.id}/export", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with valid match' do
      it 'returns 200' do
        get "/api/v1/matches/#{match.id}/export", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns match_id and players keys' do
        get "/api/v1/matches/#{match.id}/export", headers: auth_headers(user)
        data = json_response[:data]
        expect(data).to have_key(:match_id)
        expect(data).to have_key(:players)
        expect(data[:players]).to be_an(Array)
      end
    end

    context 'with non-existent match' do
      it 'returns 404' do
        get '/api/v1/matches/0/export', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/matches/:id/export (CSV)' do
    context 'when authenticated' do
      it 'returns 200 with text/csv content-type' do
        get "/api/v1/matches/#{match.id}/export.csv", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
      end
    end
  end
end
