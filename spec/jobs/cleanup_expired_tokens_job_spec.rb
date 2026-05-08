# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authentication::CleanupExpiredTokensJob, type: :job do
  describe '#perform' do
    it 'calls PasswordResetToken.cleanup_old_tokens' do
      expect(PasswordResetToken).to receive(:cleanup_old_tokens).and_return(0)
      allow(TokenBlacklist).to receive(:cleanup_expired).and_return(0)
      described_class.perform_now
    end

    it 'calls TokenBlacklist.cleanup_expired' do
      allow(PasswordResetToken).to receive(:cleanup_old_tokens).and_return(0)
      expect(TokenBlacklist).to receive(:cleanup_expired).and_return(0)
      described_class.perform_now
    end

    it 'does not raise when both methods return 0' do
      allow(PasswordResetToken).to receive(:cleanup_old_tokens).and_return(0)
      allow(TokenBlacklist).to receive(:cleanup_expired).and_return(0)
      expect { described_class.perform_now }.not_to raise_error
    end

    it 're-raises errors so Sidekiq can retry' do
      allow(PasswordResetToken).to receive(:cleanup_old_tokens).and_raise(ActiveRecord::StatementInvalid, 'DB error')
      allow(TokenBlacklist).to receive(:cleanup_expired).and_return(0)
      expect { described_class.perform_now }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'is enqueued on the default queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end
end
