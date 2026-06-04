# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages API', type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin,  organization: organization) }
  let(:sender)       { create(:user, :analyst, organization: organization) }
  let(:recipient)    { create(:user, :analyst, organization: organization) }

  describe 'GET /api/v1/messages' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/messages', params: { recipient_id: recipient.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when recipient_id is missing' do
      it 'returns 400 bad request' do
        get '/api/v1/messages', headers: auth_headers(sender)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when recipient does not belong to the organization' do
      let(:outside_user) { create(:user, organization: create(:organization)) }

      it 'returns 404' do
        get '/api/v1/messages',
            params: { recipient_id: outside_user.id },
            headers: auth_headers(sender)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with a valid recipient' do
      let!(:msg_a) do
        create(:message,
               sender: sender,
               organization: organization,
               recipient_id: recipient.id,
               recipient_type: 'User',
               sender_type: 'User',
               content: 'Hello from sender')
      end

      let!(:msg_b) do
        create(:message,
               sender: recipient,
               organization: organization,
               recipient_id: sender.id,
               recipient_type: 'User',
               sender_type: 'User',
               content: 'Hello from recipient')
      end

      let!(:deleted_msg) do
        create(:message,
               sender: sender,
               organization: organization,
               recipient_id: recipient.id,
               recipient_type: 'User',
               sender_type: 'User',
               content: 'Deleted message',
               deleted: true)
      end

      it 'returns 200 and the conversation messages' do
        get '/api/v1/messages',
            params: { recipient_id: recipient.id },
            headers: auth_headers(sender)
        expect(response).to have_http_status(:ok)
      end

      it 'includes messages sent in both directions' do
        get '/api/v1/messages',
            params: { recipient_id: recipient.id },
            headers: auth_headers(sender)
        ids = json_response[:data][:messages].map { |m| m[:id] }
        expect(ids).to include(msg_a.id, msg_b.id)
      end

      it 'excludes soft-deleted messages' do
        get '/api/v1/messages',
            params: { recipient_id: recipient.id },
            headers: auth_headers(sender)
        ids = json_response[:data][:messages].map { |m| m[:id] }
        expect(ids).not_to include(deleted_msg.id)
      end

      it 'returns pagination metadata' do
        get '/api/v1/messages',
            params: { recipient_id: recipient.id },
            headers: auth_headers(sender)
        expect(json_response[:data][:pagination]).to include(:current_page, :per_page, :total_count)
      end

      it 'each message includes required fields' do
        get '/api/v1/messages',
            params: { recipient_id: recipient.id },
            headers: auth_headers(sender)
        msg = json_response[:data][:messages].first
        expect(msg).to include(:id, :content, :created_at, :recipient_id, :sender_type, :sender)
      end
    end
  end

  describe 'DELETE /api/v1/messages/:id' do
    context 'when unauthenticated' do
      let!(:msg) do
        create(:message, sender: sender, organization: organization,
                         recipient_id: recipient.id, recipient_type: 'User')
      end

      it 'returns 401' do
        delete "/api/v1/messages/#{msg.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the message author' do
      let!(:own_message) do
        create(:message,
               sender: sender,
               organization: organization,
               recipient_id: recipient.id,
               recipient_type: 'User',
               sender_type: 'User',
               content: 'My message')
      end

      it 'soft-deletes the message and returns 200' do
        delete "/api/v1/messages/#{own_message.id}", headers: auth_headers(sender)
        expect(response).to have_http_status(:ok)
        expect(own_message.reload.deleted).to be true
        expect(own_message.reload.deleted_at).to be_present
      end

      it 'does not hard-delete the record (preserves conversation history)' do
        delete "/api/v1/messages/#{own_message.id}", headers: auth_headers(sender)
        expect(Message.unscoped.find(own_message.id)).to be_present
      end
    end

    context 'when authenticated as a different non-admin user' do
      let(:other_user) { create(:user, :analyst, organization: organization) }
      let!(:senders_message) do
        create(:message,
               sender: sender,
               organization: organization,
               recipient_id: recipient.id,
               recipient_type: 'User',
               sender_type: 'User')
      end

      it 'returns 403 forbidden' do
        delete "/api/v1/messages/#{senders_message.id}", headers: auth_headers(other_user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not soft-delete the message' do
        delete "/api/v1/messages/#{senders_message.id}", headers: auth_headers(other_user)
        expect(senders_message.reload.deleted).to be false
      end
    end

    context 'when authenticated as admin' do
      let!(:senders_message) do
        create(:message,
               sender: sender,
               organization: organization,
               recipient_id: recipient.id,
               recipient_type: 'User',
               sender_type: 'User',
               content: 'Anyone can admin-delete this')
      end

      it 'can delete any message in the organization' do
        delete "/api/v1/messages/#{senders_message.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
        expect(senders_message.reload.deleted).to be true
      end
    end

    context 'when message does not exist' do
      it 'returns 404' do
        delete '/api/v1/messages/00000000-0000-0000-0000-000000000000',
               headers: auth_headers(sender)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'cross-organization isolation' do
    let(:other_organization) { create(:organization) }
    let(:other_user)         { create(:user, :admin, organization: other_organization) }
    let(:other_recipient)    { create(:user, :analyst, organization: other_organization) }

    let!(:org_message) do
      create(:message,
             sender: sender,
             organization: organization,
             recipient_id: recipient.id,
             recipient_type: 'User',
             sender_type: 'User',
             content: 'Org A private message')
    end

    let!(:other_org_message) do
      create(:message,
             sender: other_user,
             organization: other_organization,
             recipient_id: other_recipient.id,
             recipient_type: 'User',
             sender_type: 'User',
             content: 'Org B private message')
    end

    it 'user from another org cannot read messages from this org (recipient not found)' do
      get '/api/v1/messages',
          params: { recipient_id: recipient.id },
          headers: auth_headers(other_user)
      expect(response).to have_http_status(:not_found)
    end

    it 'user from another org cannot delete a message from this org' do
      delete "/api/v1/messages/#{org_message.id}", headers: auth_headers(other_user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
