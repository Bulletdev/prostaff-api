# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Manager::ContractExpiryAlertJob, type: :job do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }
  let(:player)       { create(:player, organization: organization) }

  # Build an active contract whose end_date falls exactly at 'target' days from today.
  def contract_expiring_in(days, metadata: {})
    create(:contract, :active,
           organization: organization,
           player: player,
           created_by: admin,
           end_date: Date.current + days.days,
           metadata: metadata)
  end

  describe '#perform' do
    # ── Queue configuration ────────────────────────────────────────────────

    it 'is on the default queue' do
      expect(described_class.new.class.get_sidekiq_options['queue']).to eq('default')
    end

    # ── 30-day threshold ─────────────────────────────────────────────────

    context 'when a contract expires in exactly 30 days' do
      let!(:contract) { contract_expiring_in(30) }

      it 'enqueues ContractAlertMailerJob with the correct arguments' do
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract.id, 30, 'alerted_30d')
        described_class.new.perform
      end

      it 'logs the alert' do
        expect(Rails.logger).to receive(:info).with(/ContractExpiryAlertJob.*days=30/)
        described_class.new.perform
      end
    end

    context 'when a contract expires within the +-1 day window around 30 days' do
      let!(:contract_minus_one) { contract_expiring_in(29) }
      let!(:contract_plus_one)  do
        create(:contract, :active,
               organization: organization,
               player: create(:player, organization: organization),
               created_by: admin,
               end_date: Date.current + 31.days)
      end

      it 'enqueues alert for the contract expiring in 29 days (lower edge of window)' do
        allow(Manager::ContractAlertMailerJob).to receive(:perform_async)
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract_minus_one.id, 30, 'alerted_30d')
        described_class.new.perform
      end

      it 'enqueues alert for the contract expiring in 31 days (upper edge of window)' do
        allow(Manager::ContractAlertMailerJob).to receive(:perform_async)
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract_plus_one.id, 30, 'alerted_30d')
        described_class.new.perform
      end
    end

    # ── Out-of-window contracts are ignored ───────────────────────────────

    context 'when a contract expires outside the +-1 day window' do
      let!(:early_contract) { contract_expiring_in(28) }
      let!(:late_contract) do
        create(:contract, :active,
               organization: organization,
               player: create(:player, organization: organization),
               created_by: admin,
               end_date: Date.current + 32.days)
      end

      it 'does not flag a contract expiring in 28 days for the 30d threshold' do
        described_class.new.perform
        expect(early_contract.reload.metadata).not_to have_key('alerted_30d')
      end

      it 'does not flag a contract expiring in 32 days for the 30d threshold' do
        described_class.new.perform
        expect(late_contract.reload.metadata).not_to have_key('alerted_30d')
      end
    end

    # ── Idempotency ───────────────────────────────────────────────────────

    context 'when a contract was already flagged for alerted_30d' do
      let!(:already_alerted) { contract_expiring_in(30, metadata: { 'alerted_30d' => true }) }

      it 'does not reprocess contracts already marked as alerted' do
        # The job filters out already-flagged contracts via the WHERE NOT clause.
        # We verify that the metadata value remains exactly true (not double-written)
        # and that the job does not raise.
        expect { described_class.new.perform }.not_to raise_error
        expect(already_alerted.reload.metadata['alerted_30d']).to be(true)
      end

      it 'does not enqueue ContractAlertMailerJob for the already-alerted contract' do
        expect(Manager::ContractAlertMailerJob).not_to receive(:perform_async)
          .with(already_alerted.id, anything, anything)
        described_class.new.perform
      end
    end

    # ── 90, 60, 14, 7 day thresholds ─────────────────────────────────────

    context 'multiple threshold coverage' do
      # Each contract needs a unique player — one player cannot hold multiple active contracts.
      let!(:contract_90) do
        create(:contract, :active,
               organization: organization,
               player: create(:player, organization: organization),
               created_by: admin,
               end_date: Date.current + 90.days)
      end
      let!(:contract_60) do
        create(:contract, :active,
               organization: organization,
               player: create(:player, organization: organization),
               created_by: admin,
               end_date: Date.current + 60.days)
      end
      let!(:contract_14) do
        create(:contract, :active,
               organization: organization,
               player: create(:player, organization: organization),
               created_by: admin,
               end_date: Date.current + 14.days)
      end
      let!(:contract_7) do
        create(:contract, :active,
               organization: organization,
               player: create(:player, organization: organization),
               created_by: admin,
               end_date: Date.current + 7.days)
      end

      it 'enqueues alert for the 90-day contract with alerted_90d' do
        allow(Manager::ContractAlertMailerJob).to receive(:perform_async)
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract_90.id, 90, 'alerted_90d')
        described_class.new.perform
      end

      it 'enqueues alert for the 60-day contract with alerted_60d' do
        allow(Manager::ContractAlertMailerJob).to receive(:perform_async)
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract_60.id, 60, 'alerted_60d')
        described_class.new.perform
      end

      it 'enqueues alert for the 14-day contract with alerted_14d' do
        allow(Manager::ContractAlertMailerJob).to receive(:perform_async)
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract_14.id, 14, 'alerted_14d')
        described_class.new.perform
      end

      it 'enqueues alert for the 7-day contract with alerted_7d' do
        allow(Manager::ContractAlertMailerJob).to receive(:perform_async)
        expect(Manager::ContractAlertMailerJob).to receive(:perform_async)
          .with(contract_7.id, 7, 'alerted_7d')
        described_class.new.perform
      end
    end

    # ── Non-active contracts are ignored ─────────────────────────────────

    context 'when a non-active contract has an end_date in the window' do
      let!(:draft_contract) do
        create(:contract,
               organization: organization,
               player: player,
               created_by: admin,
               status: 'draft',
               end_date: Date.current + 30.days)
      end

      it 'does not flag draft contracts' do
        described_class.new.perform
        expect(draft_contract.reload.metadata).not_to have_key('alerted_30d')
      end
    end

    # ── No errors raised ─────────────────────────────────────────────────

    it 'does not raise even when there are no contracts to process' do
      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
