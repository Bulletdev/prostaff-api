# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics::Objectives', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  describe 'GET /api/v1/analytics/objectives' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/analytics/objectives'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when there are no matches' do
      it 'returns 200' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns a message about no matches found' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        expect(json_response[:data][:message]).to be_present
      end

      it 'returns nil control sections when no matches exist' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        data = json_response[:data]
        expect(data[:dragon_control]).to be_nil
        expect(data[:baron_control]).to be_nil
        expect(data[:tower_control]).to be_nil
        expect(data[:inhibitor_control]).to be_nil
      end
    end

    context 'with match data present' do
      before do
        create(:match,
               organization: organization,
               victory: true,
               game_start: 3.days.ago,
               our_dragons: 4, opponent_dragons: 1,
               our_barons: 2,  opponent_barons: 0,
               our_towers: 9,  opponent_towers: 3,
               our_inhibitors: 2, opponent_inhibitors: 0)
        create(:match,
               organization: organization,
               victory: false,
               game_start: 2.days.ago,
               our_dragons: 1, opponent_dragons: 4,
               our_barons: 0,  opponent_barons: 2,
               our_towers: 3,  opponent_towers: 8,
               our_inhibitors: 0, opponent_inhibitors: 2)
      end

      it 'returns 200' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns all four control sections' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        data = json_response[:data]
        expect(data).to have_key(:dragon_control)
        expect(data).to have_key(:baron_control)
        expect(data).to have_key(:tower_control)
        expect(data).to have_key(:inhibitor_control)
        expect(data).to have_key(:objective_score)
      end

      it 'returns dragon_advantage_rate as a ratio within [0, 1]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        rate = json_response[:data][:dragon_control][:dragon_advantage_rate]
        expect(rate).to be_between(0, 1)
      end

      it 'returns baron_advantage_rate as a ratio within [0, 1]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        rate = json_response[:data][:baron_control][:baron_advantage_rate]
        expect(rate).to be_between(0, 1)
      end

      it 'returns tower_advantage_rate as a ratio within [0, 1]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        rate = json_response[:data][:tower_control][:tower_advantage_rate]
        expect(rate).to be_between(0, 1)
      end

      it 'returns inhibitor_advantage_rate as a ratio within [0, 1]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        rate = json_response[:data][:inhibitor_control][:inhibitor_advantage_rate]
        expect(rate).to be_between(0, 1)
      end

      it 'returns objective_score overall within [0, 100]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        score = json_response[:data][:objective_score][:overall]
        expect(score).to be_between(0, 100)
      end

      it 'returns avg_dragons_per_game >= 0' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        avg = json_response[:data][:dragon_control][:avg_dragons_per_game]
        expect(avg.to_f).to be >= 0
      end

      it 'returns avg_barons_per_game >= 0' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        avg = json_response[:data][:baron_control][:avg_barons_per_game]
        expect(avg.to_f).to be >= 0
      end

      it 'returns objective_score breakdown with dragon, baron, tower, inhibitor contributions' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        breakdown = json_response[:data][:objective_score][:breakdown]
        expect(breakdown).to include(:dragon_contribution, :baron_contribution,
                                     :tower_contribution, :inhibitor_contribution)
      end

      it 'returns objective_trend as an array sorted by date ascending' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        trend = json_response[:data][:objective_score][:trend]
        expect(trend).to be_an(Array)
        expect(trend).not_to be_empty
        dates = trend.map { |t| t[:date] }
        expect(dates).to eq(dates.sort)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      before do
        create(:match,
               organization: organization,
               victory: true,
               game_start: 1.day.ago,
               our_dragons: 4, opponent_dragons: 1,
               our_barons: 2,  opponent_barons: 0,
               our_towers: 9,  opponent_towers: 3,
               our_inhibitors: 2, opponent_inhibitors: 0)
      end

      it 'returns no-matches response for other org (data not visible)' do
        get '/api/v1/analytics/objectives', headers: auth_headers(other_user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:message]).to be_present
        expect(json_response[:data][:dragon_control]).to be_nil
      end
    end

    context 'with match_type filter' do
      before do
        create(:match,
               organization: organization,
               match_type: 'official',
               victory: true,
               game_start: 2.days.ago,
               our_dragons: 3, opponent_dragons: 2,
               our_barons: 1,  opponent_barons: 1,
               our_towers: 7,  opponent_towers: 4,
               our_inhibitors: 1, opponent_inhibitors: 0)
        create(:match,
               organization: organization,
               match_type: 'scrim',
               victory: false,
               game_start: 1.day.ago,
               our_dragons: 2, opponent_dragons: 3,
               our_barons: 0,  opponent_barons: 2,
               our_towers: 4,  opponent_towers: 7,
               our_inhibitors: 0, opponent_inhibitors: 1)
      end

      it 'filters by match_type=official and returns only official match data' do
        get '/api/v1/analytics/objectives',
            params: { match_type: 'official' },
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:dragon_control]).not_to be_nil
      end

      it 'returns no-match response when filter matches nothing' do
        get '/api/v1/analytics/objectives',
            params: { match_type: 'tournament' },
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:message]).to be_present
      end
    end

    context 'with date_from and date_to filters' do
      before do
        create(:match,
               organization: organization,
               victory: true,
               game_start: 10.days.ago,
               our_dragons: 4, opponent_dragons: 1,
               our_barons: 2,  opponent_barons: 0,
               our_towers: 8,  opponent_towers: 3,
               our_inhibitors: 2, opponent_inhibitors: 0)
        create(:match,
               organization: organization,
               victory: false,
               game_start: 1.day.ago,
               our_dragons: 1, opponent_dragons: 3,
               our_barons: 0,  opponent_barons: 1,
               our_towers: 3,  opponent_towers: 7,
               our_inhibitors: 0, opponent_inhibitors: 1)
      end

      it 'filters to only matches within date range' do
        get '/api/v1/analytics/objectives',
            params: { date_from: 15.days.ago.to_date.to_s, date_to: 5.days.ago.to_date.to_s },
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:dragon_control]).not_to be_nil
      end
    end
  end
end
