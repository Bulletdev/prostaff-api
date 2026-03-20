# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/ai/draft/analyze', type: :request do
  let(:org)  { create(:organization, tier: 'tier_1_professional') }
  let(:user) { create(:user, organization: org) }
  let(:headers) { auth_headers(user) }

  let(:valid_params) do
    {
      team_a: %w[Jinx Thresh Azir Vi Garen],
      team_b: %w[Caitlyn Lulu Viktor Lee\ Sin Malphite]
    }
  end

  describe 'authenticated Tier 1 org' do
    it 'returns 200 with correct schema' do
      post '/api/v1/ai/draft/analyze', params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      data = body['data']

      expect(data).to include('win_probability', 'confidence', 'low_sample',
                              'top_synergies', 'top_counters', 'suggested_picks')
    end

    it 'returns win_probability between 0 and 1' do
      post '/api/v1/ai/draft/analyze', params: valid_params.to_json, headers: headers
      data = JSON.parse(response.body)['data']
      expect(data['win_probability']).to be_between(0.0, 1.0)
    end

    it 'returns top_synergies as array' do
      post '/api/v1/ai/draft/analyze', params: valid_params.to_json, headers: headers
      data = JSON.parse(response.body)['data']
      expect(data['top_synergies']).to be_an(Array)
    end

    it 'returns top_counters as array' do
      post '/api/v1/ai/draft/analyze', params: valid_params.to_json, headers: headers
      data = JSON.parse(response.body)['data']
      expect(data['top_counters']).to be_an(Array)
    end
  end

  describe 'unauthenticated request' do
    it 'returns 401' do
      post '/api/v1/ai/draft/analyze', params: valid_params.to_json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Tier 2 org (no predictive_analytics access)' do
    let(:tier2_org)  { create(:organization, tier: 'tier_2_semi_pro') }
    let(:tier2_user) { create(:user, organization: tier2_org) }
    let(:tier2_headers) { auth_headers(tier2_user) }

    it 'returns 403 with UPGRADE_REQUIRED code' do
      post '/api/v1/ai/draft/analyze', params: valid_params.to_json, headers: tier2_headers
      expect(response).to have_http_status(:forbidden)

      body = JSON.parse(response.body)
      expect(body.dig('error', 'code')).to eq('UPGRADE_REQUIRED')
    end
  end

  describe 'missing required params' do
    it 'returns 400 when team_a is missing' do
      post '/api/v1/ai/draft/analyze', params: { team_b: %w[Caitlyn Lulu] }.to_json, headers: headers
      expect(response).to have_http_status(:bad_request)
    end
  end
end
