# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, full_name: 'Original Name') }

  describe 'GET /api/v1/profile' do
    context 'when authenticated' do
      it 'returns current user profile' do
        get '/api/v1/profile', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(user.id)
        expect(json['email']).to eq(user.email)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/profile'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/profile' do
    let(:valid_params) do
      {
        user: {
          full_name: 'Updated Name',
          timezone: 'America/New_York',
          language: 'en-US'
        }
      }.to_json
    end

    context 'with valid params' do
      it 'updates user profile' do
        patch '/api/v1/profile', headers: auth_headers(user), params: valid_params

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Profile updated successfully')

        user.reload
        expect(user.full_name).to eq('Updated Name')
        expect(user.timezone).to eq('America/New_York')
      end

      it 'creates audit log' do
        expect do
          patch '/api/v1/profile', headers: auth_headers(user), params: valid_params
        end.to change { AuditLog.unscoped.count }.by_at_least(1)

        audit_log = AuditLog.unscoped.find_by(action: 'update_profile')
        expect(audit_log).to be_present
        expect(audit_log.action).to eq('update_profile')
        expect(audit_log.entity_type).to eq('User')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        { user: { full_name: 'a' * 300 } }.to_json
      end

      it 'returns unprocessable entity' do
        patch '/api/v1/profile', headers: auth_headers(user), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end
    end
  end

  describe 'PATCH /api/v1/profile/password' do
    let(:current_password) { 'Test123!@#' }
    let(:password_user) { create(:user, organization: organization, password: current_password) }

    context 'with correct current password' do
      let(:valid_params) do
        {
          current_password: current_password,
          password: 'NewPass456!@#',
          password_confirmation: 'NewPass456!@#'
        }.to_json
      end

      it 'updates password' do
        patch '/api/v1/profile/password', headers: auth_headers(password_user), params: valid_params

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Password updated successfully')

        password_user.reload
        expect(password_user.authenticate('NewPass456!@#')).to be_truthy
      end

      it 'creates audit log' do
        expect do
          patch '/api/v1/profile/password', headers: auth_headers(password_user), params: valid_params
        end.to change { AuditLog.unscoped.count }.by_at_least(1)

        audit_log = AuditLog.unscoped.find_by(action: 'change_password')
        expect(audit_log).to be_present
        expect(audit_log.action).to eq('change_password')
      end
    end

    context 'with incorrect current password' do
      let(:invalid_params) do
        {
          current_password: 'wrongpassword',
          password: 'NewPass456!@#',
          password_confirmation: 'NewPass456!@#'
        }.to_json
      end

      it 'returns unprocessable entity' do
        patch '/api/v1/profile/password', headers: auth_headers(password_user), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']['message']).to eq('Current password is incorrect')
      end
    end
  end

  describe 'PATCH /api/v1/profile/notifications' do
    let(:valid_params) do
      {
        notification_preferences: {
          email: false,
          player_updates: true,
          match_reminders: false
        }
      }.to_json
    end

    it 'updates notification preferences' do
      patch '/api/v1/profile/notifications', headers: auth_headers(user), params: valid_params

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Notification preferences updated successfully')

      user.reload
      expect(user.notification_preferences['email'].to_s).to eq('false')
      expect(user.notification_preferences['player_updates'].to_s).to eq('true')
    end
  end
end
