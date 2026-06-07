# frozen_string_literal: true

require 'rails_helper'

# Tier authorization tests for the TierAuthorization concern.
#
# TierAuthorization fires before_action on :create and :update for controllers
# that include it (ScrimsController, OpponentTeamsController).
#
# Feature matrix (from TierFeatures::TIER_FEATURES):
#   tier_3_amateur       => features: vod_reviews, champion_pools, schedules
#   tier_2_semi_pro      => adds scrims, draft_analysis, team_composition, opponent_database
#   tier_1_professional  => full feature set
#
# Tier-gated create endpoints tested here:
#   POST /api/v1/scrims/scrims       — requires scrims (tier_2+)
#   POST /api/v1/scrims/opponent-teams — requires opponent_database (tier_2+)
RSpec.describe 'TierAuthorization concern', type: :request do
  # ---------------------------------------------------------------------------
  # Shared scrim payload
  # ---------------------------------------------------------------------------

  let(:scrim_params) do
    {
      scrim: {
        scheduled_at: 2.days.from_now.iso8601,
        games_planned: 3
      }
    }.to_json
  end

  let(:opponent_team_params) do
    {
      opponent_team: {
        name: 'Test Team',
        region: 'BR'
      }
    }.to_json
  end

  # ---------------------------------------------------------------------------
  # tier_3_amateur — cannot access scrims or opponent_database
  # ---------------------------------------------------------------------------

  describe 'tier_3_amateur organization' do
    let(:org)  { create(:organization, tier: 'tier_3_amateur') }
    let(:user) { create(:user, :admin, organization: org) }

    describe 'POST /api/v1/scrims/scrims' do
      it 'returns 403 with upgrade information' do
        post '/api/v1/scrims/scrims',
             params: scrim_params,
             headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end

      it 'includes current_tier and required_tier in the response' do
        post '/api/v1/scrims/scrims',
             params: scrim_params,
             headers: auth_headers(user)

        expect(json_response[:current_tier]).to eq('tier_3_amateur')
        expect(json_response[:required_tier]).to be_present
        expect(json_response[:upgrade_url]).to be_present
      end

      it 'includes the blocked feature name' do
        post '/api/v1/scrims/scrims',
             params: scrim_params,
             headers: auth_headers(user)

        expect(json_response[:feature]).to eq('scrims')
      end
    end

    describe 'POST /api/v1/scrims/opponent-teams' do
      it 'returns 403' do
        post '/api/v1/scrims/opponent-teams',
             params: opponent_team_params,
             headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end

      it 'references the opponent_database feature' do
        post '/api/v1/scrims/opponent-teams',
             params: opponent_team_params,
             headers: auth_headers(user)

        expect(json_response[:feature]).to eq('opponent_database')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # tier_2_semi_pro — can access scrims and opponent_database
  # ---------------------------------------------------------------------------

  describe 'tier_2_semi_pro organization' do
    let(:org)  { create(:organization, tier: 'tier_2_semi_pro') }
    let(:user) { create(:user, :admin, organization: org) }

    describe 'POST /api/v1/scrims/scrims' do
      it 'does not return 403 (tier check passes)' do
        post '/api/v1/scrims/scrims',
             params: scrim_params,
             headers: auth_headers(user)

        # 201 on success, or 422 on validation — either way, NOT a tier 403
        expect(response).not_to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # tier_1_professional — full access
  # ---------------------------------------------------------------------------

  describe 'tier_1_professional organization' do
    let(:org)  { create(:organization, tier: 'tier_1_professional') }
    let(:user) { create(:user, :admin, organization: org) }

    describe 'POST /api/v1/scrims/scrims' do
      it 'does not return 403 (tier check passes)' do
        post '/api/v1/scrims/scrims',
             params: scrim_params,
             headers: auth_headers(user)

        expect(response).not_to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Unauthenticated request — auth runs before tier check, so 401 is expected
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/scrims/scrims — no token' do
    it 'returns 401 (auth guard fires before tier check)' do
      post '/api/v1/scrims/scrims',
           params: scrim_params,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Match limit enforcement (check_match_limit fires on matches#create when
  # TierAuthorization is included — currently only scrims and opponent_teams
  # include the concern, so this tests the has_feature_access? helper directly)
  # ---------------------------------------------------------------------------

  describe 'has_feature_access? helper — tier boundary for competitive_data' do
    it 'tier_3_amateur cannot access competitive_data feature' do
      org = create(:organization, tier: 'tier_3_amateur')
      expect(org.can_access?('competitive_data')).to be(false)
    end

    it 'tier_1_professional can access competitive_data feature' do
      org = create(:organization, tier: 'tier_1_professional')
      expect(org.can_access?('competitive_data')).to be(true)
    end

    it 'tier_2_semi_pro can access scrims feature' do
      org = create(:organization, tier: 'tier_2_semi_pro')
      expect(org.can_access?('scrims')).to be(true)
    end

    it 'tier_3_amateur cannot access scrims feature' do
      org = create(:organization, tier: 'tier_3_amateur')
      expect(org.can_access?('scrims')).to be(false)
    end
  end
end
