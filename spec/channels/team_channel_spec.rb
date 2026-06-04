# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  before do
    stub_connection(current_user: user, current_player: nil, current_org_id: organization.id)
  end

  describe '#subscribed' do
    it 'subscribes to the org-scoped stream' do
      subscribe
      expect(subscription).to have_stream_from("team_room_#{organization.id}")
    end

    it 'is successfully subscribed' do
      subscribe
      expect(subscription).to be_confirmed
    end

    context 'when current_org_id is blank' do
      before do
        stub_connection(current_user: user, current_player: nil, current_org_id: nil)
      end

      it 'rejects the subscription' do
        subscribe
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    it 'stops all streams on unsubscribe' do
      subscribe
      expect { unsubscribe }.not_to raise_error
    end
  end

  describe '#speak' do
    before { subscribe }

    context 'with valid content' do
      it 'creates a Message record' do
        expect do
          perform :speak, content: 'Hello team'
        end.to change(Message, :count).by(1)
      end

      it 'creates the message with correct attributes' do
        perform :speak, content: 'Hello team'
        message = Message.last
        expect(message.organization_id).to eq(organization.id)
        expect(message.content).to eq('Hello team')
        expect(message.sender_type).to eq('User')
        expect(message.user_id).to eq(user.id)
      end
    end

    context 'with blank content' do
      it 'transmits an error without creating a message' do
        expect do
          perform :speak, content: '   '
        end.not_to change(Message, :count)
        expect(transmissions.last).to include('error' => 'Message content cannot be blank')
      end
    end

    context 'when content exceeds maximum length' do
      it 'transmits an error without creating a message' do
        oversized = 'x' * (TeamChannel::MAX_CONTENT_LENGTH + 1)
        expect do
          perform :speak, content: oversized
        end.not_to change(Message, :count)
        expect(transmissions.last).to include('error')
      end
    end

    context 'when connected as a player' do
      let(:player) { create(:player, organization: organization) }

      before do
        stub_connection(current_user: nil, current_player: player, current_org_id: organization.id)
        subscribe
      end

      it 'creates message with sender_type Player' do
        perform :speak, content: 'Player here'
        message = Message.last
        expect(message.sender_type).to eq('Player')
        expect(message.user_id).to eq(player.id)
      end
    end
  end
end
