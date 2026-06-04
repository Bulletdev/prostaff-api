# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics::KdaTrend', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:player)       { create(:player, organization: organization, role: 'mid') }

  describe 'GET /api/v1/analytics/kda-trend/:player_id' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/analytics/kda-trend/#{player.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when player belongs to another organization' do
      let(:other_org)    { create(:organization) }
      let(:other_player) { create(:player, organization: other_org) }

      it 'returns 404 (cross-org isolation)' do
        get "/api/v1/analytics/kda-trend/#{other_player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player does not exist' do
      it 'returns 404' do
        get '/api/v1/analytics/kda-trend/0', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player has no match history' do
      it 'returns 200 with empty kda_by_match array (not an exception)' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:kda_by_match]).to eq([])
      end

      it 'returns zero averages' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        averages = json_response[:data][:averages]
        expect(averages[:overall]).to eq(0)
        expect(averages[:last_10_games]).to eq(0)
        expect(averages[:last_20_games]).to eq(0)
      end
    end

    context 'when player has match history with normal stats' do
      before do
        3.times do |i|
          match = create(:match, organization: organization,
                                 game_start: (10 - i).days.ago,
                                 victory: i.even?)
          create(:player_match_stat,
                 match: match,
                 player: player,
                 kills: 5,
                 deaths: 2,
                 assists: 8)
        end
      end

      it 'returns 200' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns kda_by_match with one entry per match' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:kda_by_match].size).to eq(3)
      end

      it 'returns kda >= 0 for every match point' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        json_response[:data][:kda_by_match].each do |point|
          expect(point[:kda]).to be >= 0
        end
      end

      it 'returns all required fields in each match point' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        json_response[:data][:kda_by_match].each do |point|
          expect(point).to include(:match_id, :date, :kills, :deaths, :assists, :kda, :champion, :victory)
        end
      end

      it 'returns averages hash with last_10_games, last_20_games, and overall keys' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        averages = json_response[:data][:averages]
        expect(averages).to include(:last_10_games, :last_20_games, :overall)
      end

      it 'returns overall average kda >= 0' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:averages][:overall]).to be >= 0
      end
    end

    context 'when some matches have deaths == 0 (division-by-zero guard)' do
      before do
        match = create(:match, organization: organization, game_start: 1.day.ago, victory: true)
        create(:player_match_stat,
               match: match,
               player: player,
               kills: 7,
               deaths: 0,
               assists: 5)
      end

      it 'returns 200 without raising' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns kda == kills + assists when deaths == 0' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        point = json_response[:data][:kda_by_match].first
        expect(point[:kda]).to eq(12.0)
      end

      it 'returns kda >= 0 for zero-death match' do
        get "/api/v1/analytics/kda-trend/#{player.id}",
            headers: auth_headers(user)
        json_response[:data][:kda_by_match].each do |point|
          expect(point[:kda]).to be >= 0
        end
      end
    end

    context 'with player data from a different organization (user cannot see)' do
      let(:other_org)    { create(:organization) }
      let(:other_user)   { create(:user, :admin, organization: other_org) }
      let(:other_player) { create(:player, organization: other_org) }

      before do
        match = create(:match, organization: other_org, game_start: 1.day.ago, victory: true)
        create(:player_match_stat, match: match, player: other_player, kills: 10, deaths: 1, assists: 5)
      end

      it 'returns 404 for the requesting org' do
        get "/api/v1/analytics/kda-trend/#{other_player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
