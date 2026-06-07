# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimChatChannel, type: :channel do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:user_a) { create(:user, :admin, organization: org_a) }
  let(:user_b) { create(:user, :admin, organization: org_b) }
  let(:scrim)  { create(:scrim, organization: org_a) }

  before do
    stub_connection(current_user: user_a, current_org_id: org_a.id)
  end

  describe '#subscribed' do
    context 'when the user belongs to the owning organization' do
      it 'subscribes and opens the scrim stream' do
        subscribe(scrim_id: scrim.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("scrim_chat_#{scrim.id}")
      end
    end

    context 'when scrim is linked to a ScrimRequest (cross-org)' do
      let(:scrim_request) do
        create(:scrim_request, requesting_organization: org_a, target_organization: org_b)
      end

      let(:cross_scrim) do
        create(:scrim, organization: org_a, scrim_request_id: scrim_request.id)
      end

      it 'uses the canonical scrim_request stream key' do
        subscribe(scrim_id: cross_scrim.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("scrim_request_chat_#{scrim_request.id}")
      end

      context 'when user is from the opposing organization' do
        before do
          stub_connection(current_user: user_b, current_org_id: org_b.id)
        end

        it 'allows the opposing org participant to subscribe' do
          subscribe(scrim_id: cross_scrim.id)
          expect(subscription).to be_confirmed
        end
      end
    end

    context 'when scrim_id is not provided' do
      it 'rejects the subscription' do
        subscribe(scrim_id: nil)
        expect(subscription).to be_rejected
      end
    end

    context 'when scrim does not belong to the user org and has no scrim request' do
      let(:other_scrim) { create(:scrim, organization: org_b) }

      it 'rejects the subscription (no data leakage)' do
        subscribe(scrim_id: other_scrim.id)
        expect(subscription).to be_rejected
      end
    end

    context 'when scrim_id does not exist' do
      it 'rejects the subscription' do
        subscribe(scrim_id: SecureRandom.uuid)
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    it 'stops all streams without error' do
      subscribe(scrim_id: scrim.id)
      expect { unsubscribe }.not_to raise_error
    end
  end

  describe '#speak' do
    before { subscribe(scrim_id: scrim.id) }

    context 'with valid content' do
      it 'creates a ScrimMessage' do
        expect do
          perform :speak, content: 'GG WP'
        end.to change(ScrimMessage, :count).by(1)
      end

      it 'associates the message with the correct scrim and user' do
        perform :speak, content: 'GG WP'
        msg = ScrimMessage.last
        expect(msg.scrim_id).to eq(scrim.id)
        expect(msg.user_id).to eq(user_a.id)
      end
    end

    context 'with blank content' do
      it 'transmits an error and does not create a message' do
        expect do
          perform :speak, content: ''
        end.not_to change(ScrimMessage, :count)
        expect(transmissions.last).to include('error')
      end
    end

    context 'when content exceeds MAX_CONTENT_LENGTH' do
      it 'transmits an error and does not create a message' do
        oversized = 'y' * (ScrimChatChannel::MAX_CONTENT_LENGTH + 1)
        expect do
          perform :speak, content: oversized
        end.not_to change(ScrimMessage, :count)
        expect(transmissions.last).to include('error')
      end
    end
  end
end
