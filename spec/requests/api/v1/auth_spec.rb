# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }

  # Stub email deliveries so tests do not attempt real SMTP
  before { allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later) }
  before { allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now) }

  describe 'POST /api/v1/auth/login' do
    context 'with valid credentials' do
      it 'returns 200 with access and refresh tokens' do
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'Test123!@#' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to include(:access_token, :refresh_token)
      end

      it 'includes user and organization in response' do
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'Test123!@#' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(json_response[:data][:user]).to be_present
        expect(json_response[:data][:organization]).to be_present
      end
    end

    context 'with invalid password' do
      it 'returns 401' do
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'wrong' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with non-existent email' do
      it 'returns 401' do
        post '/api/v1/auth/login',
             params: { email: 'nobody@example.com', password: 'Test123!@#' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing credentials' do
      it 'returns 401' do
        post '/api/v1/auth/login',
             params: {}.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/auth/register' do
    let(:valid_params) do
      {
        user: {
          email: 'newuser@example.com',
          password: 'Test123!@#',
          full_name: 'Test User'
        },
        organization: {
          name: 'Brand New Org',
          region: 'BR'
        }
      }
    end

    context 'with valid params' do
      it 'returns 201 with tokens' do
        post '/api/v1/auth/register',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:created)
        expect(json_response[:data]).to include(:access_token, :refresh_token)
      end

      it 'creates an organization and user' do
        expect do
          post '/api/v1/auth/register',
               params: valid_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end.to change(Organization, :count).by(1).and change(User, :count).by(1)
      end
    end

    context 'with duplicate email' do
      before do
        create(:user, email: 'newuser@example.com')
      end

      it 'returns 422' do
        post '/api/v1/auth/register',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate organization name' do
      before do
        create(:organization, name: 'Brand New Org')
      end

      it 'returns 422' do
        post '/api/v1/auth/register',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /api/v1/auth/refresh' do
    let(:tokens) { JwtService.generate_tokens(user) }

    context 'with a valid refresh token' do
      it 'returns new access and refresh tokens' do
        # Allow Redis claims — stub TokenBlacklist to avoid Redis dependency in tests
        allow(TokenBlacklist).to receive(:blacklisted?).and_return(false)
        allow(TokenBlacklist).to receive(:claim_for_rotation).and_return(true)
        allow(TokenBlacklist).to receive(:add_to_blacklist).and_return(true)

        post '/api/v1/auth/refresh',
             params: { refresh_token: tokens[:refresh_token] }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to include(:access_token, :refresh_token)
      end
    end

    context 'with a missing refresh token' do
      it 'returns 400' do
        post '/api/v1/auth/refresh',
             params: {}.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/auth/logout' do
    context 'when authenticated' do
      it 'returns 200' do
        post '/api/v1/auth/logout', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/auth/logout', headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/auth/me' do
    context 'when authenticated' do
      it 'returns the current user' do
        get '/api/v1/auth/me', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:user]).to be_present
        expect(json_response[:data][:organization]).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/auth/me', headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/auth/forgot-password' do
    it 'always returns 200 to prevent email enumeration' do
      post '/api/v1/auth/forgot-password',
           params: { email: 'nonexistent@example.com' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns 400 when email param is missing' do
      post '/api/v1/auth/forgot-password',
           params: {}.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
