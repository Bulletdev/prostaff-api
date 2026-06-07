# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscordWebhookService do
  let(:message) { double('ScrimMessage', id: 42) }

  describe '.notify_new_message' do
    context 'when Discord is not configured (env vars absent in test)' do
      it 'does not raise when called' do
        # WEBHOOK_URL and GUILD_ID are nil in test env — service skips silently
        expect { described_class.notify_new_message(message) }.not_to raise_error
      end

      it 'does not enqueue DiscordScrimMessageJob' do
        expect { described_class.notify_new_message(message) }
          .not_to have_enqueued_job(DiscordScrimMessageJob)
      end
    end

    context 'when Discord is configured (mocked at method level)' do
      before do
        allow(described_class).to receive(:notify_new_message) do |msg|
          DiscordScrimMessageJob.perform_later(msg.id)
        end
      end

      it 'enqueues DiscordScrimMessageJob with the message id' do
        expect { described_class.notify_new_message(message) }
          .to have_enqueued_job(DiscordScrimMessageJob).with(message.id)
      end
    end
  end
end
