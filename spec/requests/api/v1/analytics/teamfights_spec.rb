# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics::Teamfights', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:player)       { create(:player, organization: organization, role: 'adc') }

  describe 'GET /api/v1/analytics/teamfights/:player_id' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/analytics/teamfights/#{player.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when player belongs to another organization' do
      let(:other_org)    { create(:organization) }
      let(:other_player) { create(:player, organization: other_org) }

      it 'returns 404 (cross-org isolation)' do
        get "/api/v1/analytics/teamfights/#{other_player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player does not exist' do
      it 'returns 404' do
        get '/api/v1/analytics/teamfights/0', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player has no matches' do
      it 'returns 200 without raising an exception' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns nil for avg_damage_dealt when no data exists' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        data = json_response[:data][:damage_performance]
        expect(data[:avg_damage_dealt]).to be_nil
        expect(data[:avg_damage_taken]).to be_nil
      end

      it 'returns zero for multikill sums when no data exists' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        multikills = json_response[:data][:participation][:multikill_stats]
        expect(multikills[:double_kills]).to eq(0)
        expect(multikills[:triple_kills]).to eq(0)
        expect(multikills[:quadra_kills]).to eq(0)
        expect(multikills[:penta_kills]).to eq(0)
      end

      it 'returns empty by_match array' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:by_match]).to eq([])
      end
    end

    context 'when player has match data' do
      before do
        3.times do |i|
          match = create(:match,
                         organization: organization,
                         game_start: (5 - i).days.ago,
                         game_duration: 1800,
                         victory: i.zero?)
          create(:player_match_stat,
                 match: match,
                 player: player,
                 kills: 6,
                 deaths: 2,
                 assists: 9,
                 damage_dealt_total: 28_000,
                 damage_taken: 15_000,
                 damage_mitigated: 5_000,
                 double_kills: 1,
                 triple_kills: 0,
                 quadra_kills: 0,
                 penta_kills: 0)
        end
      end

      it 'returns 200' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns player key in response' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:player]).to be_present
      end

      it 'returns damage_performance section with required fields' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        dmg = json_response[:data][:damage_performance]
        expect(dmg).to include(:avg_damage_dealt, :avg_damage_taken, :avg_damage_per_min)
      end

      it 'returns avg_damage_per_min >= 0' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        dpm = json_response[:data][:damage_performance][:avg_damage_per_min]
        expect(dpm.to_f).to be >= 0
      end

      it 'returns participation section with avg_kills, avg_deaths, avg_assists' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        part = json_response[:data][:participation]
        expect(part).to include(:avg_kills, :avg_deaths, :avg_assists)
      end

      it 'returns all participation averages >= 0' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        part = json_response[:data][:participation]
        expect(part[:avg_kills].to_f).to be >= 0
        expect(part[:avg_deaths].to_f).to be >= 0
        expect(part[:avg_assists].to_f).to be >= 0
      end

      it 'returns multikill_stats with non-negative counts' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        mk = json_response[:data][:participation][:multikill_stats]
        expect(mk[:double_kills]).to be >= 0
        expect(mk[:triple_kills]).to be >= 0
        expect(mk[:quadra_kills]).to be >= 0
        expect(mk[:penta_kills]).to be >= 0
      end

      it 'returns by_match array with one entry per match' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:by_match].size).to eq(3)
      end

      it 'returns each by_match entry with required fields' do
        get "/api/v1/analytics/teamfights/#{player.id}",
            headers: auth_headers(user)
        json_response[:data][:by_match].each do |entry|
          expect(entry).to include(:match_id, :date, :kills, :deaths, :assists,
                                   :damage_dealt, :damage_taken, :champion, :victory)
        end
      end
    end
  end
end
