# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/ai/recommend-pick', type: :request do
  let(:organization) { create(:organization, tier: 'tier_1_professional') }
  let(:user)         { create(:user, organization: organization) }

  let(:base_params) do
    {
      our_picks:      %w[Jinx Thresh Azir Vi],
      opponent_picks: %w[Caitlyn Lulu Viktor LeeSin],
      our_bans:       %w[Zed],
      opponent_bans:  %w[Syndra],
      patch:          '16.08',
      league:         'LCK'
    }
  end

  let(:ml_success_response) do
    {
      source: 'ml_v2',
      model_version: 'v2',
      recommendations: []
    }
  end

  before do
    allow(AiRecommendationService).to receive(:call).and_return(ml_success_response)
    allow(ChampionWinrateService).to receive(:win_rate_for).and_return(0.52)
  end

  # ---------------------------------------------------------------------------
  # Auth boundary — unauthenticated
  # ---------------------------------------------------------------------------
  context 'when unauthenticated (no token)' do
    it 'returns 401' do
      post '/api/v1/ai/recommend-pick',
           params: base_params.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization — organization without predictive_analytics access
  # ---------------------------------------------------------------------------
  context 'when authenticated but organization is tier_2 (no predictive_analytics)' do
    let(:restricted_org)  { create(:organization, tier: 'tier_2_semi_pro') }
    let(:restricted_user) { create(:user, organization: restricted_org) }

    it 'returns 403' do
      post '/api/v1/ai/recommend-pick',
           params: base_params.to_json,
           headers: auth_headers(restricted_user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns code UPGRADE_REQUIRED' do
      post '/api/v1/ai/recommend-pick',
           params: base_params.to_json,
           headers: auth_headers(restricted_user)

      expect(json_response.dig(:error, :code)).to eq('UPGRADE_REQUIRED')
    end
  end

  context 'when authenticated but organization is tier_3 (no predictive_analytics)' do
    let(:amateur_org)  { create(:organization, tier: 'tier_3_amateur') }
    let(:amateur_user) { create(:user, organization: amateur_org) }

    it 'returns 403' do
      post '/api/v1/ai/recommend-pick',
           params: base_params.to_json,
           headers: auth_headers(amateur_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # Authenticated tier_1 — role_needed propagation
  # ---------------------------------------------------------------------------
  context 'when authenticated with a tier_1 organization' do
    let(:headers) { auth_headers(user) }

    context 'with role_needed: "mid"' do
      it 'passes role_needed: "mid" to AiRecommendationService' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.merge(role_needed: 'mid').to_json,
             headers: headers

        expect(AiRecommendationService).to have_received(:call).with(
          hash_including(role_needed: 'mid')
        )
      end
    end

    context 'without role_needed param' do
      it 'passes role_needed: nil to AiRecommendationService' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.to_json,
             headers: headers

        expect(AiRecommendationService).to have_received(:call).with(
          hash_including(role_needed: nil)
        )
      end
    end

    context 'with role_needed: "" (empty string)' do
      it 'passes role_needed: "" to AiRecommendationService without filtering' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.merge(role_needed: '').to_json,
             headers: headers

        expect(AiRecommendationService).to have_received(:call).with(
          hash_including(role_needed: '')
        )
      end
    end

    context 'with role_needed: "INVALID_ROLE_XYZ" (unknown value)' do
      it 'passes the value as-is to AiRecommendationService (no controller-level validation)' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.merge(role_needed: 'INVALID_ROLE_XYZ').to_json,
             headers: headers

        expect(AiRecommendationService).to have_received(:call).with(
          hash_including(role_needed: 'INVALID_ROLE_XYZ')
        )
      end
    end

    # -------------------------------------------------------------------------
    # Response shape — ML success path
    # -------------------------------------------------------------------------
    context 'when ML service responds successfully' do
      it 'returns 200' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'sets X-AI-Source header to ml_v2' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.to_json,
             headers: headers

        expect(response.headers['X-AI-Source']).to eq('ml_v2')
      end

      it 'returns a data payload in the body' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.to_json,
             headers: headers

        expect(json_response[:data]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # Response shape — ML fallback path (legacy)
    # -------------------------------------------------------------------------
    context 'when ML service falls back to legacy' do
      let(:legacy_response) do
        {
          source: 'legacy',
          model_version: nil,
          recommendations: [
            {
              champion: 'Garen',
              score: nil,
              win_probability: nil,
              synergy_score: nil,
              counter_score: nil,
              reasoning_tokens: []
            }
          ]
        }
      end

      before do
        allow(AiRecommendationService).to receive(:call).and_return(legacy_response)
      end

      it 'returns 200 (not 503) when falling back to legacy' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'sets X-AI-Source header to legacy' do
        post '/api/v1/ai/recommend-pick',
             params: base_params.to_json,
             headers: headers

        expect(response.headers['X-AI-Source']).to eq('legacy')
      end
    end
  end
end
