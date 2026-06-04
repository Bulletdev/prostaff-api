# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscordScrimMessageJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:opponent)     { create(:opponent_team, name: 'Rival Team') }
  let(:scrim) do
    create(:scrim,
           organization: organization,
           opponent_team: opponent,
           games_planned: 3,
           games_completed: 0)
  end
  let(:scrim_message) do
    # Build the message without triggering callbacks that fire Discord/AC
    msg = ScrimMessage.new(
      scrim: scrim,
      user: user,
      organization: organization,
      content: 'gg wp'
    )
    msg.save!(validate: true)
    msg
  end

  before do
    # OrganizationScoped default_scope requires Current.organization_id to be set.
    # Without it, scrim.opponent_team traversal returns nil.
    Current.organization_id = organization.id

    # Prevent ActionCable from firing during scrim_message creation
    allow(ActionCable.server).to receive(:broadcast)
    # Prevent DiscordWebhookService from enqueuing another job inside notify_new_message
    allow(DiscordWebhookService).to receive(:notify_new_message)
  end

  after do
    Current.reset
  end

  describe '#perform' do
    context 'when DISCORD_BOT_WEBHOOK_URL and DISCORD_GUILD_ID are configured' do
      before do
        stub_const('DiscordWebhookService::WEBHOOK_URL', 'http://discord-bot.example.com')
        stub_const('DiscordWebhookService::GUILD_ID',    'test-guild-id')
        stub_const('DiscordWebhookService::WEBHOOK_SECRET', 'secret-token')
      end

      context 'when Discord bot responds with 200' do
        before do
          stub_request(:post, 'http://discord-bot.example.com/webhooks/scrim-message')
            .to_return(status: 200, body: '{"ok":true}', headers: { 'Content-Type' => 'application/json' })
        end

        it 'does not raise an error' do
          expect do
            described_class.new.perform(scrim_message.id)
          end.not_to raise_error
        end
      end

      context 'when Discord bot responds with 429 (rate limited)' do
        before do
          stub_request(:post, 'http://discord-bot.example.com/webhooks/scrim-message')
            .to_return(status: 429, headers: { 'Retry-After' => '60' })
        end

        it 'raises Faraday::Error so Sidekiq can retry' do
          expect do
            described_class.new.perform(scrim_message.id)
          end.to raise_error(Faraday::Error)
        end
      end

      context 'when Discord bot responds with 503 (service unavailable)' do
        before do
          stub_request(:post, 'http://discord-bot.example.com/webhooks/scrim-message')
            .to_return(status: 503, body: 'Service Unavailable')
        end

        it 'raises Faraday::Error so Sidekiq can retry' do
          expect do
            described_class.new.perform(scrim_message.id)
          end.to raise_error(Faraday::Error)
        end
      end
    end

    context 'when DISCORD_BOT_WEBHOOK_URL is not configured' do
      before do
        stub_const('DiscordWebhookService::WEBHOOK_URL', nil)
        stub_const('DiscordWebhookService::GUILD_ID',    nil)
        stub_const('DiscordWebhookService::WEBHOOK_SECRET', nil)
      end

      it 'returns without posting to Discord' do
        expect do
          described_class.new.perform(scrim_message.id)
        end.not_to raise_error
      end
    end

    context 'when the message_id does not exist' do
      it 'returns without raising an error' do
        expect do
          described_class.new.perform(999_999_999)
        end.not_to raise_error
      end
    end

    context 'SSRF protection' do
      before do
        stub_const('DiscordWebhookService::GUILD_ID', 'test-guild-id')
        stub_const('DiscordWebhookService::WEBHOOK_SECRET', nil)
      end

      it 'raises ArgumentError when webhook URL uses a blocked metadata host' do
        stub_const('DiscordWebhookService::WEBHOOK_URL', 'http://169.254.169.254/latest/meta-data')

        expect do
          described_class.new.perform(scrim_message.id)
        end.to raise_error(ArgumentError, /Blocked webhook host/)
      end

      it 'raises ArgumentError when webhook URL uses a non-http scheme' do
        stub_const('DiscordWebhookService::WEBHOOK_URL', 'ftp://discord-bot.example.com')

        expect do
          described_class.new.perform(scrim_message.id)
        end.to raise_error(ArgumentError, /Invalid webhook URL scheme/)
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
