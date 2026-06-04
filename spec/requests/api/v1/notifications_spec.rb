# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications API', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  describe 'GET /api/v1/notifications' do
    let!(:unread_notification) { create(:notification, user: user, is_read: false) }
    let!(:read_notification)   { create(:notification, :read, user: user) }

    context 'when authenticated' do
      it 'returns 200 with all notifications for the current user' do
        get '/api/v1/notifications', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:notifications].size).to eq(2)
      end

      it 'includes unread_count in the response' do
        get '/api/v1/notifications', headers: auth_headers(user)

        expect(json_response[:data][:unread_count]).to eq(1)
      end

      it 'filters to only unread notifications when unread=true' do
        get '/api/v1/notifications', params: { unread: 'true' }, headers: auth_headers(user)

        expect(json_response[:data][:notifications].size).to eq(1)
        expect(json_response[:data][:notifications][0][:is_read]).to be(false)
      end

      it 'filters by type' do
        create(:notification, :match_type, user: user)

        get '/api/v1/notifications', params: { type: 'match' }, headers: auth_headers(user)

        notifications = json_response[:data][:notifications]
        expect(notifications.size).to eq(1)
      end

      it 'includes total and page metadata' do
        get '/api/v1/notifications', headers: auth_headers(user)

        expect(json_response[:data]).to include(:total, :page, :per_page, :total_pages)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/notifications'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }
      let!(:other_notification) { create(:notification, user: other_user) }

      it 'does not return notifications belonging to another user' do
        get '/api/v1/notifications', headers: auth_headers(other_user)

        ids = json_response[:data][:notifications].map { |n| n[:id] }
        expect(ids).not_to include(unread_notification.id)
        expect(ids).not_to include(read_notification.id)
      end
    end
  end

  describe 'GET /api/v1/notifications/unread_count' do
    let!(:unread_1) { create(:notification, user: user, is_read: false) }
    let!(:unread_2) { create(:notification, user: user, is_read: false) }
    let!(:read_one) { create(:notification, :read, user: user) }

    context 'when authenticated' do
      it 'returns the correct unread count' do
        get '/api/v1/notifications/unread_count', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:unread_count]).to eq(2)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/notifications/unread_count'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/notifications/:id' do
    let!(:notification) { create(:notification, user: user) }

    context 'when authenticated' do
      it 'returns the notification' do
        get "/api/v1/notifications/#{notification.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:notification][:id]).to eq(notification.id)
      end
    end

    context 'when notification belongs to another user' do
      let(:other_org)          { create(:organization) }
      let(:other_user)         { create(:user, :admin, organization: other_org) }
      let!(:other_notification) { create(:notification, user: other_user) }

      it 'returns 404' do
        get "/api/v1/notifications/#{other_notification.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/notifications/#{notification.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/notifications/:id/mark_as_read' do
    let!(:notification) { create(:notification, user: user, is_read: false) }

    context 'when authenticated' do
      it 'marks the notification as read and returns 200' do
        patch "/api/v1/notifications/#{notification.id}/mark_as_read",
              headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:notification][:is_read]).to be(true)
      end

      it 'decrements unread_count after mark_as_read' do
        initial_unread = user.notifications.unread.count

        patch "/api/v1/notifications/#{notification.id}/mark_as_read",
              headers: auth_headers(user)

        expect(user.notifications.reload.unread.count).to eq(initial_unread - 1)
      end
    end

    context 'when notification belongs to another user' do
      let(:other_org)          { create(:organization) }
      let(:other_user)         { create(:user, :admin, organization: other_org) }
      let!(:other_notification) { create(:notification, user: other_user, is_read: false) }

      it 'returns 404 and does not mark it as read' do
        patch "/api/v1/notifications/#{other_notification.id}/mark_as_read",
              headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
        expect(other_notification.reload.is_read).to be(false)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/notifications/#{notification.id}/mark_as_read"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/notifications/mark_all_as_read' do
    let!(:unread_1) { create(:notification, user: user, is_read: false) }
    let!(:unread_2) { create(:notification, user: user, is_read: false) }

    context 'when authenticated' do
      it 'marks all unread notifications as read' do
        patch '/api/v1/notifications/mark_all_as_read', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(user.notifications.reload.unread.count).to eq(0)
      end

      it 'returns the count of marked notifications' do
        patch '/api/v1/notifications/mark_all_as_read', headers: auth_headers(user)

        expect(json_response[:data][:marked_count]).to eq(2)
      end

      it 'does not affect notifications of other users' do
        other_user = create(:user, organization: organization)
        other_notif = create(:notification, user: other_user, is_read: false)

        patch '/api/v1/notifications/mark_all_as_read', headers: auth_headers(user)

        expect(other_notif.reload.is_read).to be(false)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        patch '/api/v1/notifications/mark_all_as_read'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/notifications/:id' do
    let!(:notification) { create(:notification, user: user) }

    context 'when authenticated' do
      it 'deletes the notification and returns 200' do
        delete "/api/v1/notifications/#{notification.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(Notification.find_by(id: notification.id)).to be_nil
      end
    end

    context 'when notification belongs to another user' do
      let(:other_org)          { create(:organization) }
      let(:other_user)         { create(:user, :admin, organization: other_org) }
      let!(:other_notification) { create(:notification, user: other_user) }

      it 'returns 404 and does not delete it' do
        delete "/api/v1/notifications/#{other_notification.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
        expect(Notification.find_by(id: other_notification.id)).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        delete "/api/v1/notifications/#{notification.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
