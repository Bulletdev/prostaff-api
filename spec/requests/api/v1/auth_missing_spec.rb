# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth — endpoints faltantes', type: :request do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, organization: org, password: 'password123') }

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/refresh
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/auth/refresh' do
    context 'without refresh_token' do
      it 'returns 400' do
        post '/api/v1/auth/refresh'
        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :code)).to eq('MISSING_REFRESH_TOKEN')
      end
    end

    context 'with an invalid token string' do
      it 'returns 401' do
        post '/api/v1/auth/refresh', params: { refresh_token: 'not.a.jwt' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with an access_token instead of refresh_token' do
      it 'returns 401 (wrong token type)' do
        access_token = JwtService.encode({ user_id: user.id, type: 'access' })
        post '/api/v1/auth/refresh', params: { refresh_token: access_token }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a valid refresh_token' do
      let(:tokens) { JwtService.generate_tokens(user) }

      it 'returns 200' do
        post '/api/v1/auth/refresh', params: { refresh_token: tokens[:refresh_token] }
        expect(response).to have_http_status(:ok)
      end

      it 'returns a new access_token' do
        post '/api/v1/auth/refresh', params: { refresh_token: tokens[:refresh_token] }
        expect(json_response[:data][:access_token]).to be_present
      end

      it 'returns a new refresh_token' do
        post '/api/v1/auth/refresh', params: { refresh_token: tokens[:refresh_token] }
        expect(json_response[:data][:refresh_token]).to be_present
      end

      it 'invalidates the old refresh_token (rotation)' do
        old_refresh = tokens[:refresh_token]
        post '/api/v1/auth/refresh', params: { refresh_token: old_refresh }
        expect(response).to have_http_status(:ok)

        # Second use of same token must fail
        post '/api/v1/auth/refresh', params: { refresh_token: old_refresh }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with an expired refresh_token' do
      it 'returns 401' do
        expired = JwtService.encode(
          { user_id: user.id, type: 'refresh' },
          custom_expiration: 1.hour.ago.to_i
        )
        post '/api/v1/auth/refresh', params: { refresh_token: expired }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/logout
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/auth/logout' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/auth/logout'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns 200' do
        post '/api/v1/auth/logout', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'blacklists the token so subsequent requests fail' do
        headers = auth_headers(user)
        post '/api/v1/auth/logout', headers: headers

        get '/api/v1/auth/me', headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/forgot-password
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/auth/forgot-password' do
    context 'without email param' do
      it 'returns 400' do
        post '/api/v1/auth/forgot-password'
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with a registered email' do
      it 'returns 200 (does not reveal account existence)' do
        post '/api/v1/auth/forgot-password', params: { email: user.email }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with an unknown email' do
      it 'returns 200 (same response to prevent enumeration)' do
        post '/api/v1/auth/forgot-password', params: { email: 'nobody@example.com' }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/reset-password
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/auth/reset-password' do
    context 'without required params' do
      it 'returns 400 when token is missing' do
        post '/api/v1/auth/reset-password', params: { password: 'newpassword123' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns 400 when password is missing' do
        post '/api/v1/auth/reset-password', params: { token: 'sometoken' }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with mismatched password and confirmation' do
      it 'returns 400' do
        post '/api/v1/auth/reset-password', params: {
          token: 'sometoken',
          password: 'newpassword123',
          password_confirmation: 'different'
        }
        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :code)).to eq('PASSWORD_MISMATCH')
      end
    end

    context 'with an invalid/expired token' do
      it 'returns 400 with INVALID_RESET_TOKEN code' do
        post '/api/v1/auth/reset-password', params: {
          token: 'invalid-token-xyz',
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :code)).to eq('INVALID_RESET_TOKEN')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/player-login
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/auth/player-login' do
    context 'without credentials' do
      it 'returns 400' do
        post '/api/v1/auth/player-login'
        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :code)).to eq('MISSING_CREDENTIALS')
      end
    end

    context 'with invalid credentials' do
      it 'returns 401' do
        post '/api/v1/auth/player-login', params: {
          player_email: 'nobody@example.com',
          password: 'wrongpassword'
        }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/auth/me — token expirado
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/auth/me with expired token' do
    it 'returns 401' do
      expired_token = JwtService.encode(
        { user_id: user.id, type: 'access' },
        custom_expiration: 1.hour.ago.to_i
      )

      get '/api/v1/auth/me', headers: {
        'Authorization' => "Bearer #{expired_token}",
        'Content-Type' => 'application/json'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
