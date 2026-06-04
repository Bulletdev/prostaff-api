# frozen_string_literal: true

require 'rails_helper'

# Organizations controller spec.
#
# Routes (scoped to current user's organization via current_organization):
#   PATCH  /api/v1/organizations/:id        — update name/region/tagline
#   POST   /api/v1/organizations/:id/logo   — upload logo (S3)
#   PATCH  /api/v1/organizations/:id/lines  — update roster lines
#
# Authorization (require_admin_or_owner):
#   owner, admin, coach => allowed
#   analyst, viewer     => 403
#
# Multi-tenancy note: set_organization uses current_organization (not params[:id]).
# Each user can only ever reach their own organization's record.
# Cross-org protection is inherent: org_b user updating /organizations/org_a_id
# actually modifies org_b (their own), leaving org_a untouched.
RSpec.describe 'Organizations', type: :request do
  let(:organization) { create(:organization, tier: 'tier_2_semi_pro', region: 'BR') }
  let(:owner)        { create(:user, :owner, organization: organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }
  let(:coach)        { create(:user, :coach, organization: organization) }
  let(:analyst)      { create(:user, :analyst, organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/organizations/:id
  # ---------------------------------------------------------------------------

  describe 'PATCH /api/v1/organizations/:id' do
    let(:update_params) do
      { organization: { name: 'Updated Name', region: 'NA' } }.to_json
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as owner' do
      it 'returns 200' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
      end

      it 'updates the organization name' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(owner)

        expect(organization.reload.name).to eq('Updated Name')
      end

      it 'updates the region' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(owner)

        expect(organization.reload.region).to eq('NA')
      end

      it 'returns the serialized organization in the response' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(owner)

        org_data = json_response[:organization]
        expect(org_data[:name]).to eq('Updated Name')
        expect(org_data[:region]).to eq('NA')
        expect(org_data[:id]).to eq(organization.id)
      end
    end

    context 'when authenticated as admin' do
      it 'returns 200' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as coach' do
      it 'returns 200 (coaches can update org settings)' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as analyst' do
      it 'returns 403' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(analyst)

        expect(response).to have_http_status(:forbidden)
      end

      it 'does not update the organization' do
        original_name = organization.name

        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(analyst)

        expect(organization.reload.name).to eq(original_name)
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        patch "/api/v1/organizations/#{organization.id}",
              params: update_params,
              headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid region' do
      it 'returns 422' do
        patch "/api/v1/organizations/#{organization.id}",
              params: { organization: { region: 'INVALID_REGION' } }.to_json,
              headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a blank name' do
      it 'returns 422' do
        patch "/api/v1/organizations/#{organization.id}",
              params: { organization: { name: '' } }.to_json,
              headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    # Multi-tenancy note: set_organization binds to current_organization, not params[:id].
    # An org_b admin sending a PATCH to /organizations/org_a.id will update org_b
    # (their own org), leaving org_a unchanged. This is correct behavior.
    context 'cross-organization data isolation' do
      let(:other_org)  { create(:organization, region: 'EUW') }
      let(:other_admin) { create(:user, :admin, organization: other_org) }

      it 'does not modify org_a when org_b admin calls the endpoint' do
        original_name = organization.name

        patch "/api/v1/organizations/#{organization.id}",
              params: { organization: { name: 'Stolen Name', region: 'KR' } }.to_json,
              headers: auth_headers(other_admin)

        expect(organization.reload.name).to eq(original_name)
      end

      it 'returns 200 because org_b admin updates their own org (not org_a)' do
        patch "/api/v1/organizations/#{organization.id}",
              params: { organization: { name: 'Org B New Name', region: 'NA' } }.to_json,
              headers: auth_headers(other_admin)

        expect(response).to have_http_status(:ok)
        expect(other_org.reload.name).to eq('Org B New Name')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/organizations/:id/lines
  # ---------------------------------------------------------------------------

  describe 'PATCH /api/v1/organizations/:id/lines' do
    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/organizations/#{organization.id}/lines",
              params: { enabled_lines: ['main'] }.to_json,
              headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin with valid lines' do
      it 'returns 200' do
        patch "/api/v1/organizations/#{organization.id}/lines",
              params: { enabled_lines: ['main'] }.to_json,
              headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'returns the updated enabled_lines list' do
        patch "/api/v1/organizations/#{organization.id}/lines",
              params: { enabled_lines: ['main'] }.to_json,
              headers: auth_headers(admin)

        expect(json_response[:enabled_lines]).to be_an(Array)
        expect(json_response[:enabled_lines]).to include('main')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        patch "/api/v1/organizations/#{organization.id}/lines",
              params: { enabled_lines: ['main'] }.to_json,
              headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with no valid lines' do
      it 'returns 422' do
        patch "/api/v1/organizations/#{organization.id}/lines",
              params: { enabled_lines: ['invalid_line_xyz'] }.to_json,
              headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'cross-organization data isolation' do
      let(:other_org)   { create(:organization) }
      let(:other_admin) { create(:user, :admin, organization: other_org) }

      it 'does not modify org_a lines when org_b admin calls the endpoint' do
        original_lines = organization.enabled_lines.dup

        patch "/api/v1/organizations/#{organization.id}/lines",
              params: { enabled_lines: ['main'] }.to_json,
              headers: auth_headers(other_admin)

        expect(organization.reload.enabled_lines).to eq(original_lines)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/organizations/:id/logo — S3 upload
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/organizations/:id/logo' do
    let(:fake_s3_key) { "orgs/#{organization.id}/logo/test.png" }

    before do
      s3_service = instance_double(S3UploadService)
      allow(S3UploadService).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:upload).and_return({ key: fake_s3_key })
      allow(s3_service).to receive(:public_url)
        .with(fake_s3_key)
        .and_return("https://cdn.example.com/#{fake_s3_key}")
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/organizations/#{organization.id}/logo"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when no file is provided' do
      it 'returns 422' do
        post "/api/v1/organizations/#{organization.id}/logo",
             params: {},
             headers: auth_headers(admin).merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when authenticated as viewer without a file' do
      it 'returns 403 (role check fires before file handling)' do
        post "/api/v1/organizations/#{organization.id}/logo",
             params: {},
             headers: auth_headers(viewer).merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'cross-organization data isolation' do
      let(:other_org)   { create(:organization) }
      let(:other_admin) { create(:user, :admin, organization: other_org) }

      it 'does not update org_a logo when org_b admin calls the endpoint (updates their own org)' do
        original_logo = organization.logo_url

        # Without a file param, this returns 422 before any S3 call,
        # but org_a is never touched.
        post "/api/v1/organizations/#{organization.id}/logo",
             params: {},
             headers: auth_headers(other_admin).merge('Content-Type' => 'application/json')

        expect(organization.reload.logo_url).to eq(original_logo)
      end
    end
  end
end
