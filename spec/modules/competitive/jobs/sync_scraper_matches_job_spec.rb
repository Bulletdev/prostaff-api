# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Competitive::SyncScraperMatchesJob, type: :job do
  let(:organization) { create(:organization) }

  let(:enriched_match) do
    {
      'riot_enriched' => true,
      'match_id' => 'CBLOL_2024_match_001',
      'league' => 'CBLOL',
      'blue_team' => 'paiN Gaming',
      'red_team' => 'LOUD',
      'match_date' => 2.days.ago.iso8601,
      'game_number' => 1
    }
  end

  let(:scraper_response) do
    { 'total' => 1, 'league' => 'CBLOL', 'count' => 1, 'matches' => [enriched_match] }
  end

  describe '#perform' do
    context 'when organization is not found' do
      it 'logs an error and does not raise' do
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.new.perform(SecureRandom.uuid, league: 'CBLOL')
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(include('Organization'))
      end
    end

    context 'when scraper returns no matches' do
      before do
        scraper_instance = instance_double(ProStaffScraperService)
        allow(ProStaffScraperService).to receive(:new).and_return(scraper_instance)
        allow(scraper_instance).to receive(:fetch_matches).and_return({ 'matches' => [] })
      end

      it 'does not raise and imports nothing' do
        expect { described_class.new.perform(organization.id, league: 'CBLOL') }
          .not_to raise_error
      end
    end

    context 'when scraper returns enriched matches' do
      let(:scraper_instance)   { instance_double(ProStaffScraperService) }
      let(:importer_instance)  { instance_double(ScraperImporterService) }

      before do
        allow(ProStaffScraperService).to receive(:new).and_return(scraper_instance)
        allow(ScraperImporterService).to receive(:new).with(organization).and_return(importer_instance)

        # Return one batch then empty to end the loop
        allow(scraper_instance).to receive(:fetch_matches).and_return(
          scraper_response,
          { 'matches' => [] }
        )
        allow(importer_instance).to receive(:import_batch).and_return(
          { imported: 1, skipped_duplicate: 0, skipped_unenriched: 0, errors: 0 }
        )
        allow(AiIntelligence::RebuildChampionMatrixJob).to receive(:perform_later)
      end

      it 'calls import_batch with the fetched matches' do
        described_class.new.perform(organization.id, league: 'CBLOL', our_team: 'paiN Gaming')

        expect(importer_instance).to have_received(:import_batch).with(
          [enriched_match],
          our_team: 'paiN Gaming'
        )
      end

      it 'enqueues RebuildChampionMatrixJob when matches are imported' do
        described_class.new.perform(organization.id, league: 'CBLOL')

        expect(AiIntelligence::RebuildChampionMatrixJob).to have_received(:perform_later)
      end
    end

    context 'when scraper is unavailable (UnavailableError)' do
      before do
        scraper_instance = instance_double(ProStaffScraperService)
        allow(ProStaffScraperService).to receive(:new).and_return(scraper_instance)
        allow(scraper_instance).to receive(:fetch_matches)
          .and_raise(ProStaffScraperService::UnavailableError, 'scraper down')
      end

      it 'raises the error (job is configured to retry_on UnavailableError)' do
        expect do
          described_class.new.perform(organization.id, league: 'CBLOL')
        end.to raise_error(ProStaffScraperService::UnavailableError)
      end
    end

    context 'when scraper returns UnauthorizedError' do
      before do
        scraper_instance = instance_double(ProStaffScraperService)
        allow(ProStaffScraperService).to receive(:new).and_return(scraper_instance)
        allow(scraper_instance).to receive(:fetch_matches)
          .and_raise(ProStaffScraperService::UnauthorizedError, 'invalid key')
      end

      it 'raises the error (job is configured to discard_on UnauthorizedError)' do
        expect do
          described_class.new.perform(organization.id, league: 'CBLOL')
        end.to raise_error(ProStaffScraperService::UnauthorizedError)
      end
    end

    context 'when importer does not import any matches' do
      let(:scraper_instance)  { instance_double(ProStaffScraperService) }
      let(:importer_instance) { instance_double(ScraperImporterService) }

      before do
        allow(ProStaffScraperService).to receive(:new).and_return(scraper_instance)
        allow(ScraperImporterService).to receive(:new).and_return(importer_instance)
        allow(scraper_instance).to receive(:fetch_matches).and_return(
          scraper_response,
          { 'matches' => [] }
        )
        allow(importer_instance).to receive(:import_batch).and_return(
          { imported: 0, skipped_duplicate: 1, skipped_unenriched: 0, errors: 0 }
        )
        allow(AiIntelligence::RebuildChampionMatrixJob).to receive(:perform_later)
      end

      it 'does not enqueue RebuildChampionMatrixJob when no matches were imported' do
        described_class.new.perform(organization.id, league: 'CBLOL')

        expect(AiIntelligence::RebuildChampionMatrixJob).not_to have_received(:perform_later)
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
