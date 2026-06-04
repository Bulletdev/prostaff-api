# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Matches::ImportPlayerMatchesJob, type: :job do
  let(:organization) { create(:organization) }
  let(:player) do
    create(:player, organization: organization,
                    riot_puuid: 'test-puuid-import-001',
                    region: 'BR')
  end

  let(:riot_service) { instance_double(RiotApiService) }

  before do
    allow(RiotApiService).to receive(:new).and_return(riot_service)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:info)
  end

  after do
    Current.reset
  end

  describe '#perform' do
    context 'when player has no riot_puuid' do
      let(:player_no_puuid) { create(:player, organization: organization, riot_puuid: nil) }

      it 'returns early without calling the Riot API' do
        expect(riot_service).not_to receive(:get_match_history)

        described_class.new.perform(player_no_puuid.id, organization.id)
      end
    end

    context 'when the Riot API returns match IDs' do
      let(:match_ids) { %w[BR1_111 BR1_222 BR1_333] }

      before do
        allow(riot_service).to receive(:get_match_history).and_return(match_ids)
        allow(Matches::SyncMatchJob).to receive(:perform_later)
      end

      it 'enqueues a SyncMatchJob for each new match ID' do
        described_class.new.perform(player.id, organization.id)

        expect(Matches::SyncMatchJob).to have_received(:perform_later).exactly(3).times
      end

      it 'passes the match_id, organization_id, and region to each SyncMatchJob' do
        described_class.new.perform(player.id, organization.id)

        expect(Matches::SyncMatchJob).to have_received(:perform_later)
          .with('BR1_111', organization.id, 'BR')
        expect(Matches::SyncMatchJob).to have_received(:perform_later)
          .with('BR1_222', organization.id, 'BR')
      end

      it 'skips match IDs that already exist in the database' do
        create(:match, organization: organization, riot_match_id: 'BR1_111')

        described_class.new.perform(player.id, organization.id)

        expect(Matches::SyncMatchJob).to have_received(:perform_later).exactly(2).times
        expect(Matches::SyncMatchJob).not_to have_received(:perform_later).with('BR1_111', anything, anything)
      end
    end

    context 'when Riot API returns empty list' do
      before do
        allow(riot_service).to receive(:get_match_history).and_return([])
        allow(Matches::SyncMatchJob).to receive(:perform_later)
      end

      it 'does not enqueue any SyncMatchJob' do
        described_class.new.perform(player.id, organization.id)

        expect(Matches::SyncMatchJob).not_to have_received(:perform_later)
      end
    end

    context 'when the Riot API returns a RiotApiError' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .and_raise(RiotApiService::RiotApiError, 'Service unavailable')
      end

      it 'does not raise — logs the error and returns normally' do
        expect { described_class.new.perform(player.id, organization.id) }.not_to raise_error
      end

      it 'logs an error message containing the player id' do
        described_class.new.perform(player.id, organization.id)

        expect(Rails.logger).to have_received(:error)
          .with(include("ImportPlayerMatchesJob").and(include(player.id.to_s)))
      end
    end

    context 'when an unexpected StandardError is raised' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .and_raise(StandardError, 'network timeout')
      end

      it 're-raises so Sidekiq can retry' do
        expect { described_class.new.perform(player.id, organization.id) }
          .to raise_error(StandardError, 'network timeout')
      end

      it 'still clears Current.organization_id after the error' do
        begin
          described_class.new.perform(player.id, organization.id)
        rescue StandardError
          nil
        end

        expect(Current.organization_id).to be_nil
      end
    end

    context 'when player defaults region to BR when not set' do
      let(:player_no_region) do
        create(:player, organization: organization, riot_puuid: 'test-puuid-002', region: nil)
      end

      before do
        allow(riot_service).to receive(:get_match_history).and_return([])
        allow(Matches::SyncMatchJob).to receive(:perform_later)
      end

      it 'uses BR as the default region' do
        described_class.new.perform(player_no_region.id, organization.id)

        expect(riot_service).to have_received(:get_match_history).with(
          hash_including(region: 'BR')
        )
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
