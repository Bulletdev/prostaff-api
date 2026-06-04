# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Competitive Draft Comparison API', type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }

  # Valid 5-champion compositions using CamelCase Riot Data Dragon names
  let(:team_a_picks) { %w[Garen LeeSin Orianna Jinx Thresh] }
  let(:team_b_picks) { %w[Renekton Graves Azir Caitlyn Nautilus] }

  describe 'POST /api/v1/competitive/draft-comparison' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/competitive/draft-comparison',
             params: { our_picks: team_a_picks, opponent_picks: team_b_picks }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with valid 5-champion compositions' do
      let(:payload) do
        {
          our_picks: team_a_picks,
          opponent_picks: team_b_picks
        }.to_json
      end

      before do
        post '/api/v1/competitive/draft-comparison',
             params: payload,
             headers: auth_headers(admin)
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a success message' do
        expect(json_response[:message]).to match(/draft comparison completed/i)
      end

      it 'includes similarity_score in the response' do
        expect(json_response[:data]).to have_key(:similarity_score)
      end

      it 'includes composition_winrate in the response' do
        expect(json_response[:data]).to have_key(:composition_winrate)
      end

      it 'includes meta_score in the response' do
        expect(json_response[:data]).to have_key(:meta_score)
      end

      it 'includes insights in the response' do
        expect(json_response[:data]).to have_key(:insights)
        expect(json_response[:data][:insights]).to be_a(Array)
        expect(json_response[:data][:insights]).not_to be_empty
      end

      it 'includes similar_matches in the response' do
        expect(json_response[:data]).to have_key(:similar_matches)
        expect(json_response[:data][:similar_matches]).to be_a(Array)
      end

      it 'returns composition_winrate in [0, 100]' do
        winrate = json_response[:data][:composition_winrate].to_f
        expect(winrate).to be >= 0.0
        expect(winrate).to be <= 100.0
      end

      it 'returns meta_score in [0, 100]' do
        meta = json_response[:data][:meta_score].to_f
        expect(meta).to be >= 0.0
        expect(meta).to be <= 100.0
      end

      it 'returns similarity_score >= 0' do
        expect(json_response[:data][:similarity_score].to_f).to be >= 0
      end

      it 'includes analyzed_at timestamp' do
        expect(json_response[:data][:analyzed_at]).to be_present
      end
    end

    context 'when authenticated with 1 champion (valid minimum)' do
      it 'returns 200' do
        post '/api/v1/competitive/draft-comparison',
             params: { our_picks: ['Jinx'] }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when bans are provided' do
      it 'returns 200 and processes bans without error' do
        post '/api/v1/competitive/draft-comparison',
             params: {
               our_picks: team_a_picks,
               opponent_picks: team_b_picks,
               our_bans: %w[Akali Zed Lucian],
               opponent_bans: %w[Yasuo Leblanc]
             }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when patch is provided' do
      it 'returns 200 and includes patch in the response' do
        post '/api/v1/competitive/draft-comparison',
             params: {
               our_picks: team_a_picks,
               opponent_picks: team_b_picks,
               patch: '14.20'
             }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:patch]).to eq('14.20')
      end
    end

    context 'when our_picks is missing' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/competitive/draft-comparison',
             params: { opponent_picks: team_b_picks }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_PARAMS')
      end
    end

    context 'when our_picks has 0 champions (empty array)' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/competitive/draft-comparison',
             params: { our_picks: [] }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_PARAMS')
      end
    end

    context 'when our_picks has 6 champions (exceeds maximum)' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/competitive/draft-comparison',
             params: { our_picks: %w[Garen LeeSin Orianna Jinx Thresh Azir] }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_PARAMS')
      end
    end

    context 'when our_picks is not an array' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/competitive/draft-comparison',
             params: { our_picks: 'Jinx,Lulu' }.to_json,
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_PARAMS')
      end
    end
  end

  describe 'GET /api/v1/competitive/meta/:role' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/competitive/meta/mid'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with a valid role' do
      %w[top jungle mid adc support].each do |role|
        it "returns 200 for role '#{role}'" do
          get "/api/v1/competitive/meta/#{role}", headers: auth_headers(admin)
          expect(response).to have_http_status(:ok)
        end
      end

      it 'returns meta analysis with required fields' do
        get '/api/v1/competitive/meta/mid', headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to include(:role, :top_picks, :top_bans, :total_matches)
      end

      it 'returns role matching the request' do
        get '/api/v1/competitive/meta/adc', headers: auth_headers(admin)
        expect(json_response[:data][:role]).to eq('adc')
      end

      it 'returns top_picks as an array' do
        get '/api/v1/competitive/meta/support', headers: auth_headers(admin)
        expect(json_response[:data][:top_picks]).to be_a(Array)
      end
    end
  end

  describe 'GET /api/v1/competitive/composition-winrate' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/competitive/composition-winrate',
            params: { champions: %w[Jinx Lulu Thresh Orianna Garen] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with valid champions' do
      it 'returns 200' do
        get '/api/v1/competitive/composition-winrate',
            params: { champions: %w[Jinx Lulu Thresh Orianna Garen] },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'returns winrate in [0, 100]' do
        get '/api/v1/competitive/composition-winrate',
            params: { champions: %w[Jinx Lulu Thresh Orianna Garen] },
            headers: auth_headers(admin)

        winrate = json_response[:data][:winrate].to_f
        expect(winrate).to be >= 0.0
        expect(winrate).to be <= 100.0
      end

      it 'returns the champions list in the response' do
        get '/api/v1/competitive/composition-winrate',
            params: { champions: %w[Jinx Lulu] },
            headers: auth_headers(admin)

        expect(json_response[:data][:champions]).to be_present
      end
    end

    context 'when champions param is missing' do
      it 'returns 422' do
        get '/api/v1/competitive/composition-winrate', headers: auth_headers(admin)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/competitive/counters' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/competitive/counters',
            params: { opponent_pick: 'Azir', role: 'mid' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with valid params' do
      it 'returns 200' do
        get '/api/v1/competitive/counters',
            params: { opponent_pick: 'Azir', role: 'mid' },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'returns suggested_counters as an array' do
        get '/api/v1/competitive/counters',
            params: { opponent_pick: 'Azir', role: 'mid' },
            headers: auth_headers(admin)

        expect(json_response[:data][:suggested_counters]).to be_a(Array)
      end

      it 'returns the opponent_pick and role in the response' do
        get '/api/v1/competitive/counters',
            params: { opponent_pick: 'Jinx', role: 'adc' },
            headers: auth_headers(admin)

        expect(json_response[:data][:opponent_pick]).to eq('Jinx')
        expect(json_response[:data][:role]).to eq('adc')
      end
    end

    context 'when opponent_pick is missing' do
      it 'returns 422' do
        get '/api/v1/competitive/counters',
            params: { role: 'mid' },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when role is missing' do
      it 'returns 422' do
        get '/api/v1/competitive/counters',
            params: { opponent_pick: 'Azir' },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
