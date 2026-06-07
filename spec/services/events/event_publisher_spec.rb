# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::EventPublisher do
  let(:user_id)  { SecureRandom.uuid }
  let(:org_id)   { SecureRandom.uuid }
  let(:type)     { 'scrim_request.accepted' }
  let(:payload)  { { scrim_request_id: SecureRandom.uuid } }

  describe '.publish' do
    context 'with valid arguments' do
      it 'enqueues EventPublishJob without raising' do
        expect do
          described_class.publish(
            user_id: user_id,
            org_id: org_id,
            type: type,
            payload: payload
          )
        end.not_to raise_error
      end

      it 'enqueues the job with correct arguments' do
        expect(Events::EventPublishJob).to receive(:perform_later).with(
          user_id: user_id.to_s,
          org_id: org_id.to_s,
          type: type,
          payload: payload
        )

        described_class.publish(
          user_id: user_id,
          org_id: org_id,
          type: type,
          payload: payload
        )
      end

      it 'converts user_id and org_id to strings' do
        integer_user_id = 12_345
        integer_org_id  = 67_890

        expect(Events::EventPublishJob).to receive(:perform_later).with(
          user_id: integer_user_id.to_s,
          org_id: integer_org_id.to_s,
          type: type,
          payload: {}
        )

        described_class.publish(
          user_id: integer_user_id,
          org_id: integer_org_id,
          type: type
        )
      end

      it 'defaults payload to empty hash when omitted' do
        expect(Events::EventPublishJob).to receive(:perform_later).with(
          hash_including(payload: {})
        )

        described_class.publish(user_id: user_id, org_id: org_id, type: type)
      end
    end

    context 'with missing required fields' do
      it 'returns without enqueuing when type is blank' do
        expect(Events::EventPublishJob).not_to receive(:perform_later)

        result = described_class.publish(user_id: user_id, org_id: org_id, type: '')
        expect(result).to be_nil
      end

      it 'returns without enqueuing when user_id is blank' do
        expect(Events::EventPublishJob).not_to receive(:perform_later)

        described_class.publish(user_id: '', org_id: org_id, type: type)
      end

      it 'returns without enqueuing when org_id is blank' do
        expect(Events::EventPublishJob).not_to receive(:perform_later)

        described_class.publish(user_id: user_id, org_id: '', type: type)
      end

      it 'does not raise even when fields are missing' do
        expect do
          described_class.publish(user_id: nil, org_id: nil, type: nil)
        end.not_to raise_error
      end
    end

    context 'when perform_later raises' do
      it 'swallows the error and does not propagate it' do
        allow(Events::EventPublishJob).to receive(:perform_later).and_raise(StandardError, 'Redis down')

        expect do
          described_class.publish(user_id: user_id, org_id: org_id, type: type)
        end.not_to raise_error
      end
    end
  end

  describe 'REDIS_CHANNEL_PREFIX' do
    it 'is set to the expected value' do
      expect(described_class::REDIS_CHANNEL_PREFIX).to eq('prostaff:events')
    end
  end
end
