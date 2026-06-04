# frozen_string_literal: true

require 'rails_helper'

# Auth boundary tests for the Authenticatable concern.
#
# Verifies that every authentication failure path returns the correct HTTP
# status code and that a properly-authenticated request succeeds.
#
# The protected endpoint used throughout is GET /api/v1/players — it requires
# a valid access token and is available to all authenticated users.
RSpec.describe 'Auth boundaries (Authenticatable concern)', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  # ---------------------------------------------------------------------------
  # Token absent
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — no token' do
    it 'returns 401 with UNAUTHORIZED code' do
      get '/api/v1/players', headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response.dig(:error, :code)).to eq('UNAUTHORIZED')
    end
  end

  # ---------------------------------------------------------------------------
  # Token present but malformed
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — malformed token' do
    it 'returns 401 for a random string' do
      get '/api/v1/players', headers: {
        'Authorization' => 'Bearer not.a.valid.jwt',
        'Content-Type' => 'application/json'
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 for an empty Bearer value' do
      get '/api/v1/players', headers: {
        'Authorization' => 'Bearer ',
        'Content-Type' => 'application/json'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Expired token
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — expired token' do
    it 'returns 401' do
      expired_token = JwtService.encode(
        { user_id: user.id, organization_id: organization.id, role: user.role, type: 'access' },
        custom_expiration: 1.hour.ago.to_i
      )

      get '/api/v1/players', headers: {
        'Authorization' => "Bearer #{expired_token}",
        'Content-Type' => 'application/json'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Token with nonexistent user_id
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — token references deleted/nonexistent user' do
    it 'returns 401' do
      ghost_token = JwtService.encode(
        { user_id: 999_999_999, organization_id: organization.id, type: 'access' }
      )

      get '/api/v1/players', headers: {
        'Authorization' => "Bearer #{ghost_token}",
        'Content-Type' => 'application/json'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Refresh token used as access token (must be rejected)
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — refresh token used as access token' do
    it 'returns 401 because refresh tokens carry type:refresh, not type:access' do
      refresh_token = JwtService.encode(
        { user_id: user.id, organization_id: organization.id, type: 'refresh' }
      )

      get '/api/v1/players', headers: {
        'Authorization' => "Bearer #{refresh_token}",
        'Content-Type' => 'application/json'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Revoked (blacklisted) token
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — blacklisted token' do
    it 'returns 401 after the token is blacklisted' do
      headers = auth_headers(user)

      # Blacklist the token that auth_headers generated
      token = headers['Authorization'].split(' ').last
      JwtService.blacklist_token(token)

      get '/api/v1/players', headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # Valid token — happy path
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/players — valid token' do
    it 'returns 200' do
      get '/api/v1/players', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-organization token: token from org_a used against org_b data
  #
  # The players endpoint scopes results to current_organization, so org_b's
  # player must not appear in org_a's response.
  # ---------------------------------------------------------------------------

  describe 'cross-organization token scoping' do
    let(:org_b)    { create(:organization) }
    let(:user_b)   { create(:user, :admin, organization: org_b) }
    let!(:player_b) { create(:player, organization: org_b) }

    it 'does not expose org_b data when authenticated as org_a user' do
      get '/api/v1/players', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :players)&.map { |p| p[:id] } || []
      expect(ids).not_to include(player_b.id)
    end

    it 'returns 404 when org_a user attempts to fetch an org_b player by ID' do
      player_b_id = player_b.id
      get "/api/v1/players/#{player_b_id}", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # require_admin! — non-admin user receives 403 on admin-only actions
  # ---------------------------------------------------------------------------

  describe 'admin-only actions' do
    let(:viewer_user) { create(:user, :viewer, organization: organization) }

    # DELETE /api/v1/players/:id requires admin
    it 'returns 403 when a viewer tries to delete a player' do
      player = create(:player, organization: organization)
      delete "/api/v1/players/#{player.id}", headers: auth_headers(viewer_user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
