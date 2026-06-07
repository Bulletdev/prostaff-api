# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DirectMessageChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:sender)       { create(:user, :admin, organization: organization) }
  let(:recipient)    { create(:user, organization: organization) }

  before do
    stub_connection(
      current_user: sender,
      current_player: nil,
      current_org_id: organization.id
    )
  end

  describe '#subscribed' do
    context 'with a valid recipient in the same org' do
      it 'subscribes to the correct DM stream' do
        subscribe(recipient_id: recipient.id, recipient_type: 'User')
        expect(subscription).to be_confirmed
        expected_stream = Message.dm_stream_key(sender.id, recipient.id, organization.id)
        expect(subscription).to have_stream_from(expected_stream)
      end
    end

    context 'when recipient is a Player in the same org' do
      let(:player_recipient) { create(:player, organization: organization, player_access_enabled: true) }

      it 'subscribes using the player as recipient' do
        subscribe(recipient_id: player_recipient.id, recipient_type: 'Player')
        expect(subscription).to be_confirmed
        expected_stream = Message.dm_stream_key(sender.id, player_recipient.id, organization.id)
        expect(subscription).to have_stream_from(expected_stream)
      end
    end

    context 'when no recipient_id is provided' do
      it 'rejects the subscription' do
        subscribe(recipient_id: nil)
        expect(subscription).to be_rejected
      end
    end

    context 'when recipient does not exist' do
      it 'rejects the subscription' do
        subscribe(recipient_id: SecureRandom.uuid, recipient_type: 'User')
        expect(subscription).to be_rejected
      end
    end

    context 'when recipient belongs to a different organization' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, organization: other_org) }

      it 'rejects the subscription (cross-org isolation)' do
        subscribe(recipient_id: other_user.id, recipient_type: 'User')
        expect(subscription).to be_rejected
      end
    end

    context 'when sender tries to DM themselves' do
      it 'rejects the subscription' do
        subscribe(recipient_id: sender.id, recipient_type: 'User')
        expect(subscription).to be_rejected
      end
    end

    context 'when recipient_type defaults to User for unknown types' do
      it 'falls back to User lookup' do
        subscribe(recipient_id: recipient.id, recipient_type: 'Unknown')
        # Falls back to User lookup — recipient is a User, so it succeeds
        expect(subscription).to be_confirmed
      end
    end
  end

  describe '#speak' do
    before { subscribe(recipient_id: recipient.id, recipient_type: 'User') }

    context 'with valid content' do
      it 'creates a direct Message record' do
        expect do
          perform :speak, content: 'Hey!', recipient_id: recipient.id, recipient_type: 'User'
        end.to change(Message, :count).by(1)
      end

      it 'sets correct DM attributes' do
        perform :speak, content: 'Hey!', recipient_id: recipient.id, recipient_type: 'User'
        msg = Message.last
        expect(msg.user_id).to eq(sender.id)
        expect(msg.recipient_id).to eq(recipient.id)
        expect(msg.recipient_type).to eq('User')
        expect(msg.organization_id).to eq(organization.id)
        expect(msg.content).to eq('Hey!')
      end
    end

    context 'with blank content' do
      it 'transmits an error without creating a message' do
        expect do
          perform :speak, content: '', recipient_id: recipient.id
        end.not_to change(Message, :count)
        expect(transmissions.last).to include('error')
      end
    end

    context 'when content exceeds MAX_CONTENT_LENGTH' do
      it 'transmits an error without creating a message' do
        oversized = 'z' * (DirectMessageChannel::MAX_CONTENT_LENGTH + 1)
        expect do
          perform :speak, content: oversized, recipient_id: recipient.id
        end.not_to change(Message, :count)
        expect(transmissions.last).to include('error')
      end
    end
  end

  describe '#unsubscribed' do
    it 'stops all streams without error' do
      subscribe(recipient_id: recipient.id, recipient_type: 'User')
      expect { unsubscribe }.not_to raise_error
    end
  end
end
