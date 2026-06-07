# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Organizations API', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user)   { create(:user, :admin, organization: organization) }
  let(:owner_user)   { create(:user, :owner, organization: organization) }
  let(:viewer_user)  { create(:user, :viewer, organization: organization) }

  let!(:org_a) { create(:organization) }
  let!(:org_b) { create(:organization) }

  describe 'GET /api/v1/admin/organizations' do
    context 'when authenticated as admin' do
      it 'returns 200 with all organizations' do
        get '/api/v1/admin/organizations', headers: auth_headers(admin_user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:organizations]).to be_an(Array)
        expect(json_response[:data][:organizations].size).to be >= 3
      end

      it 'includes pagination metadata' do
        get '/api/v1/admin/organizations', headers: auth_headers(admin_user)

        expect(json_response[:data][:pagination]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end

      it 'returns organization objects with expected fields' do
        get '/api/v1/admin/organizations', headers: auth_headers(admin_user)

        orgs = json_response[:data][:organizations]
        orgs.each do |org|
          expect(org).to include(:id, :name, :tier, :users_count, :created_at)
        end
      end

      it 'filters by tier' do
        tier1_org = create(:organization, tier: 'tier_1_professional')

        get '/api/v1/admin/organizations', params: { tier: 'tier_1_professional' },
                                           headers: auth_headers(admin_user)

        returned_ids = json_response[:data][:organizations].map { |o| o[:id] }
        expect(returned_ids).to include(tier1_org.id)
      end
    end

    context 'when authenticated as owner' do
      it 'returns 200' do
        get '/api/v1/admin/organizations', headers: auth_headers(owner_user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as viewer (non-admin)' do
      it 'returns 403 forbidden' do
        get '/api/v1/admin/organizations', headers: auth_headers(viewer_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/admin/organizations'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
