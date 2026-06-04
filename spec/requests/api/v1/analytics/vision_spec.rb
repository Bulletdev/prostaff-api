# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics::Vision', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:player)       { create(:player, organization: organization, role: 'support') }

  describe 'GET /api/v1/analytics/vision/:player_id' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/analytics/vision/#{player.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when player belongs to another organization' do
      let(:other_org)    { create(:organization) }
      let(:other_player) { create(:player, organization: other_org) }

      it 'returns 404 (cross-org isolation)' do
        get "/api/v1/analytics/vision/#{other_player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player does not exist' do
      it 'returns 404' do
        get '/api/v1/analytics/vision/0', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when player has no matches' do
      it 'returns 200 without raising an exception' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns all vision metrics as zero (not nil errors)' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        data = json_response[:data]
        expect(data[:avg_vision_score]).to eq(0)
        expect(data[:avg_wards_placed]).to eq(0)
        expect(data[:avg_wards_destroyed]).to eq(0)
        expect(data[:avg_control_wards]).to eq(0)
        expect(data[:best_vision_game]).to eq(0)
        expect(data[:total_wards_placed]).to eq(0)
        expect(data[:total_wards_destroyed]).to eq(0)
        expect(data[:vision_per_min]).to eq(0)
      end

      it 'returns empty vision_trend array' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:vision_trend]).to eq([])
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
                 vision_score: 45 + i,
                 wards_placed: 20 + i,
                 wards_destroyed: 8 + i,
                 control_wards_purchased: 4)
        end
      end

      it 'returns 200' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns avg_vision_score >= 0' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:avg_vision_score].to_f).to be >= 0
      end

      it 'returns avg_wards_placed >= 0' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:avg_wards_placed].to_f).to be >= 0
      end

      it 'returns avg_wards_destroyed >= 0' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:avg_wards_destroyed].to_f).to be >= 0
      end

      it 'returns avg_control_wards >= 0' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:avg_control_wards].to_f).to be >= 0
      end

      it 'returns total_wards_placed >= 0' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:total_wards_placed].to_i).to be >= 0
      end

      it 'returns vision_per_min >= 0' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:vision_per_min].to_f).to be >= 0
      end

      it 'returns player key in response' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        expect(json_response[:data][:player]).to be_present
      end

      it 'returns role_comparison hash with player_avg, role_avg, and percentile' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        comparison = json_response[:data][:role_comparison]
        expect(comparison).to include(:player_avg, :role_avg, :percentile)
      end

      it 'returns vision_trend sorted by date ascending' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        trend = json_response[:data][:vision_trend]
        expect(trend).not_to be_empty
        dates = trend.map { |d| d[:date] }
        expect(dates).to eq(dates.sort)
      end

      it 'returns each trend entry with required fields' do
        get "/api/v1/analytics/vision/#{player.id}",
            headers: auth_headers(user)
        json_response[:data][:vision_trend].each do |entry|
          expect(entry).to include(:date, :vision_score, :wards_placed, :wards_destroyed, :champion, :victory)
        end
      end
    end
  end
end
