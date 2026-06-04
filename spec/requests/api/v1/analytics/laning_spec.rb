# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics::Laning', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:player)       { create(:player, organization: organization, role: 'mid') }

  describe 'GET /api/v1/analytics/laning/:player_id' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/analytics/laning/#{player.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when player belongs to another organization' do
      let(:other_org)    { create(:organization) }
      let(:other_player) { create(:player, organization: other_org) }

      it 'returns 404 (cross-org isolation)' do
        get "/api/v1/analytics/laning/#{other_player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player does not exist' do
      it 'returns 404' do
        get '/api/v1/analytics/laning/0', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player has no matches' do
      it 'returns 200 without raising an exception' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns nil for rate fields when no games exist' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        data = json_response[:data]
        expect(data[:lane_win_rate]).to be_nil
        expect(data[:first_blood_rate]).to be_nil
        expect(data[:first_tower_rate]).to be_nil
      end

      it 'returns zero for numeric aggregates when no games exist' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        data = json_response[:data]
        expect(data[:avg_cs_total]).to eq(0).or be_nil
        expect(data[:avg_gold]).to eq(0).or be_nil
      end

      it 'returns empty laning_trend array' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:laning_trend]).to eq([])
      end

      it 'returns nil for timeline fields (not available from data source)' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        data = json_response[:data]
        expect(data[:gold_diff_10]).to be_nil
        expect(data[:gold_diff_15]).to be_nil
        expect(data[:cs_diff_10]).to be_nil
        expect(data[:cs_diff_15]).to be_nil
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
                 cs: 230,
                 gold_earned: 13_500,
                 first_blood: i.zero?,
                 first_tower: i.zero?)
        end
      end

      it 'returns 200' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns player key in response' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:player]).to be_present
      end

      it 'returns lane_win_rate within [0, 100]' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        rate = json_response[:data][:lane_win_rate]
        expect(rate).to be_between(0, 100) if rate
      end

      it 'returns first_blood_rate within [0, 100]' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        rate = json_response[:data][:first_blood_rate]
        expect(rate).to be_between(0, 100) if rate
      end

      it 'returns first_tower_rate within [0, 100]' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        rate = json_response[:data][:first_tower_rate]
        expect(rate).to be_between(0, 100) if rate
      end

      it 'returns avg_gold >= 0' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:avg_gold].to_f).to be >= 0
      end

      it 'returns non-empty laning_trend sorted by date ascending' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        trend = json_response[:data][:laning_trend]
        expect(trend).not_to be_empty
        dates = trend.map { |d| d[:date] }
        expect(dates).to eq(dates.sort)
      end

      it 'returns timeline fields as nil (unavailable from data source)' do
        get "/api/v1/analytics/laning/#{player.id}",
            headers: auth_headers(user)
        data = json_response[:data]
        expect(data[:gold_diff_10]).to be_nil
        expect(data[:cs_diff_10]).to be_nil
      end
    end
  end
end
