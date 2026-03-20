# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics::Competitive', type: :request do
  let(:org)   { create(:organization) }
  let(:user)  { create(:user, :admin, organization: org) }

  # ---------------------------------------------------------------------------
  # GET /api/v1/analytics/competitive/draft-performance
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/analytics/competitive/draft-performance' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/analytics/competitive/draft-performance'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with no matches' do
      it 'returns 200 with empty state' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:total_matches]).to eq(0)
        expect(data[:pick_performance]).to eq([])
        expect(data[:ban_performance]).to eq([])
      end
    end

    context 'when authenticated with competitive matches' do
      let!(:win)  { create(:competitive_match, organization: org, victory: true,  side: 'blue') }
      let!(:loss) { create(:competitive_match, organization: org, victory: false, side: 'red') }

      it 'returns 200' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct total_matches count' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        expect(json_response[:data][:total_matches]).to eq(2)
      end

      it 'returns side_performance with blue and red keys' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        side = json_response[:data][:side_performance]
        expect(side).to have_key(:blue)
        expect(side).to have_key(:red)
      end

      it 'returns win rates within [0, 100] for each side' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        side = json_response[:data][:side_performance]
        %i[blue red].each do |s|
          expect(side[s][:win_rate]).to be_between(0, 100)
        end
      end

      it 'returns pick_performance with valid LoL roles' do
        valid_roles = %w[top jungle mid adc support unknown]
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        picks = json_response[:data][:pick_performance]
        picks.each do |pick|
          expect(valid_roles).to include(pick[:role])
        end
      end

      it 'returns pick win_rate within [0, 100]' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        picks = json_response[:data][:pick_performance]
        picks.each do |pick|
          expect(pick[:win_rate]).to be_between(0, 100)
        end
      end

      it 'returns pick_rate within [0, 100]' do
        get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user)
        picks = json_response[:data][:pick_performance]
        picks.each do |pick|
          expect(pick[:pick_rate]).to be_between(0, 100)
        end
      end
    end

    context 'with filter params' do
      let!(:cblol_match) do
        create(:competitive_match, organization: org, tournament_name: 'CBLOL', victory: true)
      end
      let!(:lcs_match) do
        create(:competitive_match, organization: org, tournament_name: 'LCS', victory: false)
      end

      it 'filters by tournament name' do
        get '/api/v1/analytics/competitive/draft-performance',
            params: { tournament: 'CBLOL' },
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:total_matches]).to eq(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/analytics/competitive/tournament-stats
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/analytics/competitive/tournament-stats' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/analytics/competitive/tournament-stats'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with no matches' do
      it 'returns 200 with zero totals' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:total_games]).to eq(0)
        expect(data[:total_wins]).to eq(0)
        expect(data[:overall_win_rate]).to eq(0)
      end
    end

    context 'with matches in multiple tournaments' do
      before do
        create_list(:competitive_match, 3, organization: org, tournament_name: 'CBLOL', victory: true)
        create_list(:competitive_match, 2, organization: org, tournament_name: 'CBLOL', victory: false)
        create_list(:competitive_match, 1, organization: org, tournament_name: 'Worlds', victory: true)
      end

      it 'returns 200' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'counts total_games correctly' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        expect(json_response[:data][:total_games]).to eq(6)
      end

      it 'counts total_wins correctly' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        expect(json_response[:data][:total_wins]).to eq(4)
      end

      it 'returns overall_win_rate within [0, 100]' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        expect(json_response[:data][:overall_win_rate]).to be_between(0, 100)
      end

      it 'returns a tournaments array with correct names' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        names = json_response[:data][:tournaments].map { |t| t[:name] }
        expect(names).to include('CBLOL', 'Worlds')
      end

      it 'returns per-tournament win_rate within [0, 100]' do
        get '/api/v1/analytics/competitive/tournament-stats', headers: auth_headers(user)
        json_response[:data][:tournaments].each do |tournament|
          expect(tournament[:win_rate]).to be_between(0, 100)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/analytics/competitive/opponents
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/analytics/competitive/opponents' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/analytics/competitive/opponents'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with no matches' do
      it 'returns empty opponents list' do
        get '/api/v1/analytics/competitive/opponents', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:opponents]).to eq([])
        expect(json_response[:data][:total_unique_opponents]).to eq(0)
      end
    end

    context 'with matches against multiple opponents' do
      before do
        create_list(:competitive_match, 2, organization: org, opponent_team_name: 'paiN Gaming', victory: true)
        create_list(:competitive_match, 1, organization: org, opponent_team_name: 'LOUD', victory: false)
      end

      it 'returns correct number of unique opponents' do
        get '/api/v1/analytics/competitive/opponents', headers: auth_headers(user)
        expect(json_response[:data][:total_unique_opponents]).to eq(2)
      end

      it 'returns opponent win_rate within [0, 100]' do
        get '/api/v1/analytics/competitive/opponents', headers: auth_headers(user)
        json_response[:data][:opponents].each do |opp|
          expect(opp[:win_rate]).to be_between(0, 100)
        end
      end

      it 'returns correct win/loss breakdown per opponent' do
        get '/api/v1/analytics/competitive/opponents', headers: auth_headers(user)
        pain = json_response[:data][:opponents].find { |o| o[:name] == 'paiN Gaming' }
        expect(pain[:matches]).to eq(2)
        expect(pain[:wins]).to eq(2)
        expect(pain[:losses]).to eq(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/analytics/competitive/player-stats
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/analytics/competitive/player-stats' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/analytics/competitive/player-stats', params: { summoner_name: 'brTT' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without summoner_name param' do
      it 'returns 400' do
        get '/api/v1/analytics/competitive/player-stats', headers: auth_headers(user)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with summoner_name that has no data' do
      it 'returns 200 with games_played zero' do
        get '/api/v1/analytics/competitive/player-stats',
            params: { summoner_name: 'UnknownPlayer' },
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:games_played]).to eq(0)
      end
    end

    context 'with a summoner who has picks in competitive matches' do
      let(:summoner) { 'brTT' }
      let(:pick_data) do
        [
          { 'champion' => 'Jinx', 'role' => 'adc', 'summoner_name' => summoner,
            'kills' => 5, 'deaths' => 2, 'assists' => 8, 'cs' => 280, 'gold' => 14000,
            'damage' => 32000, 'win' => true }
        ]
      end

      before do
        create(:competitive_match, organization: org, our_picks: pick_data, victory: true)
      end

      it 'returns 200 with games_played > 0' do
        get '/api/v1/analytics/competitive/player-stats',
            params: { summoner_name: summoner },
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:games_played]).to eq(1)
      end

      it 'returns avg_kda that is never negative' do
        get '/api/v1/analytics/competitive/player-stats',
            params: { summoner_name: summoner },
            headers: auth_headers(user)
        kda = json_response[:data][:overall][:avg_kda]
        expect(kda).to be >= 0 if kda
      end

      it 'returns win_rate within [0, 100]' do
        get '/api/v1/analytics/competitive/player-stats',
            params: { summoner_name: summoner },
            headers: auth_headers(user)
        expect(json_response[:data][:overall][:win_rate]).to be_between(0, 100)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/analytics/objectives
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/analytics/objectives' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/analytics/objectives'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with no matches' do
      it 'returns 200 with message about no matches' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:message]).to be_present
      end
    end

    context 'with match data' do
      before do
        create(:match,
               organization: org,
               victory: true,
               our_dragons: 4, opponent_dragons: 1,
               our_barons: 2, opponent_barons: 1,
               our_towers: 9, opponent_towers: 3,
               our_inhibitors: 2, opponent_inhibitors: 0)
        create(:match,
               organization: org,
               victory: false,
               our_dragons: 1, opponent_dragons: 4,
               our_barons: 0, opponent_barons: 2,
               our_towers: 3, opponent_towers: 8,
               our_inhibitors: 0, opponent_inhibitors: 2)
      end

      it 'returns 200 with all control sections' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data).to have_key(:dragon_control)
        expect(data).to have_key(:baron_control)
        expect(data).to have_key(:tower_control)
        expect(data).to have_key(:inhibitor_control)
        expect(data).to have_key(:objective_score)
      end

      it 'returns objective_score overall within [0, 100]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        score = json_response[:data][:objective_score][:overall]
        expect(score).to be_between(0, 100)
      end

      it 'returns dragon_advantage_rate as a ratio within [0, 1]' do
        get '/api/v1/analytics/objectives', headers: auth_headers(user)
        rate = json_response[:data][:dragon_control][:dragon_advantage_rate]
        expect(rate).to be_between(0, 1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/analytics/players/:player_id/ping-profile
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/analytics/players/:player_id/ping-profile' do
    let(:player) { create(:player, organization: org) }

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/analytics/players/#{player.id}/ping-profile"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a player from another org' do
      let(:other_org)    { create(:organization) }
      let(:other_player) { create(:player, organization: other_org) }

      it 'returns 404 (cross-org isolation)' do
        get "/api/v1/analytics/players/#{other_player.id}/ping-profile",
            headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with a valid player' do
      it 'returns 200 with player and ping_profile keys' do
        get "/api/v1/analytics/players/#{player.id}/ping-profile",
            headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data).to have_key(:player)
        expect(data).to have_key(:ping_profile)
      end
    end

    context 'with non-existent player' do
      it 'returns 404' do
        get '/api/v1/analytics/players/0/ping-profile', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
