# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscordDmService do
  let(:requesting_org) { create(:organization) }
  let(:target_org)     { create(:organization) }
  let(:scrim_request)  do
    create(:scrim_request,
           requesting_organization: requesting_org,
           target_organization: target_org)
  end

  # Helpers to create users with discord_user_id set
  let!(:target_admin) do
    create(:user, :admin, organization: target_org, discord_user_id: 'test-discord-uid-1')
  end
  let!(:requesting_admin) do
    create(:user, :admin, organization: requesting_org, discord_user_id: 'test-discord-uid-2')
  end

  before do
    stub_const('DiscordDmService::BOT_WEBHOOK_URL', 'http://bot.test:4567')
    stub_const('DiscordDmService::BOT_WEBHOOK_SECRET', 'test-secret')
  end

  describe '.notify_new_invite' do
    context 'when bot webhook is configured' do
      let!(:dm_stub) do
        stub_request(:post, 'http://bot.test:4567/webhooks/dm')
          .to_return(status: 200, body: '{}')
      end

      it 'sends a DM to target org admins and does not raise' do
        expect { described_class.notify_new_invite(scrim_request) }.not_to raise_error
      end

      it 'posts to the bot webhook endpoint' do
        described_class.notify_new_invite(scrim_request)
        expect(dm_stub).to have_been_requested.at_least_once
      end
    end

    context 'when bot webhook is not configured' do
      before do
        stub_const('DiscordDmService::BOT_WEBHOOK_URL', nil)
      end

      it 'skips without raising' do
        expect { described_class.notify_new_invite(scrim_request) }.not_to raise_error
      end
    end

    context 'when bot webhook call fails' do
      before do
        stub_request(:post, 'http://bot.test:4567/webhooks/dm')
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'does not raise (rescues internally)' do
        expect { described_class.notify_new_invite(scrim_request) }.not_to raise_error
      end
    end
  end

  describe '.notify_accepted' do
    context 'when bot webhook is configured' do
      before do
        stub_request(:post, 'http://bot.test:4567/webhooks/dm')
          .to_return(status: 200, body: '{}')
      end

      it 'does not raise' do
        expect { described_class.notify_accepted(scrim_request) }.not_to raise_error
      end
    end
  end

  describe '.notify_declined' do
    context 'when bot webhook is configured' do
      before do
        stub_request(:post, 'http://bot.test:4567/webhooks/dm')
          .to_return(status: 200, body: '{}')
      end

      it 'does not raise' do
        expect { described_class.notify_declined(scrim_request) }.not_to raise_error
      end
    end
  end
end
