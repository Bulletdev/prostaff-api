# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Internal Organizations', type: :request do
  let(:organization) { create(:organization, tier: 'tier_3_amateur', subscription_plan: 'free', subscription_status: 'trial') }
  let(:user)         { create(:user, organization: organization) }
  let(:secret)       { ENV.fetch('INTERNAL_JWT_SECRET', 'test_internal_secret') }
  let(:auth_headers) { { 'Authorization' => "Bearer #{secret}", 'Content-Type' => 'application/json' } }

  describe 'PATCH /internal/organizations/by_user/:user_id/tier' do
    context 'without Authorization header' do
      it 'returns 401' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_2_semi_pro', subscription_plan: 'semi_pro', subscription_status: 'active' }.to_json,
              headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with wrong secret' do
      it 'returns 401' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_2_semi_pro', subscription_plan: 'semi_pro', subscription_status: 'active' }.to_json,
              headers: auth_headers.merge('Authorization' => 'Bearer wrong_secret')

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user does not exist' do
      it 'returns 404' do
        patch '/internal/organizations/by_user/99999999/tier',
              params: { tier: 'tier_2_semi_pro', subscription_plan: 'semi_pro', subscription_status: 'active' }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error]).to eq('user not found')
      end
    end

    context 'with invalid tier' do
      it 'returns 422' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_9_invalid', subscription_plan: 'semi_pro', subscription_status: 'active' }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to include('invalid tier')
      end
    end

    context 'on subscription activation (pro_monthly)' do
      it 'upgrades the organization to tier_2_semi_pro' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_2_semi_pro', subscription_plan: 'semi_pro', subscription_status: 'active' }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:ok)

        org = organization.reload
        expect(org.tier).to eq('tier_2_semi_pro')
        expect(org.subscription_plan).to eq('semi_pro')
        expect(org.subscription_status).to eq('active')
      end

      it 'returns the updated organization data' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_2_semi_pro', subscription_plan: 'semi_pro', subscription_status: 'active' }.to_json,
              headers: auth_headers

        data = json_response[:data]
        expect(data[:id]).to eq(organization.id)
        expect(data[:tier]).to eq('tier_2_semi_pro')
        expect(data[:subscription_status]).to eq('active')
      end
    end

    context 'on subscription cancellation' do
      before do
        organization.update!(tier: 'tier_2_semi_pro', subscription_plan: 'semi_pro', subscription_status: 'active')
      end

      it 'downgrades the organization to tier_3_amateur' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_3_amateur', subscription_plan: 'free', subscription_status: 'cancelled' }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:ok)

        org = organization.reload
        expect(org.tier).to eq('tier_3_amateur')
        expect(org.subscription_plan).to eq('free')
        expect(org.subscription_status).to eq('cancelled')
      end
    end

    context 'on enterprise activation' do
      it 'upgrades the organization to tier_1_professional' do
        patch "/internal/organizations/by_user/#{user.id}/tier",
              params: { tier: 'tier_1_professional', subscription_plan: 'enterprise', subscription_status: 'active' }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(organization.reload.tier).to eq('tier_1_professional')
      end
    end
  end
end
