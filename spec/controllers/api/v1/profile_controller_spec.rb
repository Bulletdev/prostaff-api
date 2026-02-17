# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ProfileController, type: :controller do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:auth_token) { JwtService.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{auth_token}"
  end

  describe 'GET #show' do
    it 'returns current user profile' do
      get :show

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(user.id)
      expect(json['email']).to eq(user.email)
    end
  end

  describe 'PATCH #update' do
    context 'with valid params' do
      let(:valid_params) do
        {
          user: {
            full_name: 'Updated Name',
            timezone: 'America/New_York',
            language: 'en-US'
          }
        }
      end

      it 'updates user profile' do
        patch :update, params: valid_params

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Profile updated successfully')

        user.reload
        expect(user.full_name).to eq('Updated Name')
        expect(user.timezone).to eq('America/New_York')
      end

      it 'creates audit log' do
        expect {
          patch :update, params: valid_params
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq('update_profile')
        expect(audit_log.entity_type).to eq('User')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        { user: { full_name: 'a' * 300 } }
      end

      it 'returns unprocessable entity' do
        patch :update, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('errors')
      end
    end
  end

  describe 'PATCH #update_password' do
    let(:current_password) { 'password123' }
    let(:user_with_password) { create(:user, organization: organization, password: current_password) }

    before do
      auth_token = JwtService.encode(user_id: user_with_password.id)
      request.headers['Authorization'] = "Bearer #{auth_token}"
    end

    context 'with correct current password' do
      let(:valid_params) do
        {
          user: {
            current_password: current_password,
            new_password: 'newpassword123'
          }
        }
      end

      it 'updates password' do
        patch :update_password, params: valid_params

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Password updated successfully')

        user_with_password.reload
        expect(user_with_password.authenticate('newpassword123')).to be_truthy
      end

      it 'creates audit log' do
        expect {
          patch :update_password, params: valid_params
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq('change_password')
      end
    end

    context 'with incorrect current password' do
      let(:invalid_params) do
        {
          user: {
            current_password: 'wrongpassword',
            new_password: 'newpassword123'
          }
        }
      end

      it 'returns unauthorized' do
        patch :update_password, params: invalid_params

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Current password is incorrect')
      end
    end
  end

  describe 'PATCH #update_notifications' do
    let(:valid_params) do
      {
        user: {
          notifications_enabled: false,
          notification_preferences: {
            email: false,
            player_updates: true,
            match_reminders: false
          }
        }
      }
    end

    it 'updates notification preferences' do
      patch :update_notifications, params: valid_params

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Notification preferences updated successfully')
      expect(json['notifications_enabled']).to be false

      user.reload
      expect(user.notifications_enabled).to be false
      expect(user.notification_preferences['email']).to be false
      expect(user.notification_preferences['player_updates']).to be true
    end
  end
end
