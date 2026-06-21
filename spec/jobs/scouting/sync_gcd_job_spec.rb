# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scouting::SyncGcdJob, type: :job do
  let(:scraper_url) { ENV.fetch('SCRAPER_API_URL', 'https://scraper.prostaff.gg') }
  let(:gcd_endpoint) { "#{scraper_url}/api/v1/gcd/players" }

  let(:sample_records) do
    [
      {
        'player_name'       => 'Titan',
        'team_name'         => 'LOUD',
        'region'            => 'CBLOL',
        'role'              => 'mid',
        'residency'         => 'BR',
        'contract_end_date' => 90.days.from_now.to_date.to_s,
        'source'            => 'leaguepedia_gcd'
      },
      {
        'player_name'       => 'Dynquedo',
        'team_name'         => 'Pain Gaming',
        'region'            => 'CBLOL',
        'role'              => 'jungle',
        'residency'         => 'BR',
        'contract_end_date' => nil,
        'source'            => 'leaguepedia_gcd'
      }
    ]
  end

  describe '#perform' do
    context 'when scraper returns data for a league' do
      before do
        stub_request(:get, gcd_endpoint)
          .with(query: hash_including('league' => 'CBLOL'))
          .to_return(
            status: 200,
            body: { players: sample_records }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Stub remaining leagues to return empty lists
        %w[LCK LEC LCS LPL].each do |league|
          stub_request(:get, gcd_endpoint)
            .with(query: hash_including('league' => league))
            .to_return(
              status: 200,
              body: { players: [] }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end
      end

      it 'upserts records into market_registrations without raising' do
        expect { described_class.new.perform }.not_to raise_error
      end

      it 'creates MarketRegistration records for returned players' do
        expect { described_class.new.perform }
          .to change(MarketRegistration, :count).by(2)
      end

      it 'persists the correct player_external_name' do
        described_class.new.perform
        names = MarketRegistration.pluck(:player_external_name)
        expect(names).to include('Titan', 'Dynquedo')
      end

      it 'idempotently upserts on a second run without duplicating records' do
        described_class.new.perform
        expect { described_class.new.perform }.not_to change(MarketRegistration, :count)
      end
    end

    context 'when the scraper returns an empty players list for a league' do
      before do
        Scouting::SyncGcdJob::LEAGUES.each do |league|
          stub_request(:get, gcd_endpoint)
            .with(query: hash_including('league' => league))
            .to_return(
              status: 200,
              body: { players: [] }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end

      it 'creates no MarketRegistration records' do
        expect { described_class.new.perform }.not_to change(MarketRegistration, :count)
      end
    end

    context 'when the scraper is unavailable for one league' do
      before do
        # CBLOL is unavailable
        stub_request(:get, gcd_endpoint)
          .with(query: hash_including('league' => 'CBLOL'))
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))

        # Remaining leagues succeed with data
        %w[LCK LEC LCS LPL].each do |league|
          stub_request(:get, gcd_endpoint)
            .with(query: hash_including('league' => league))
            .to_return(
              status: 200,
              body: { players: [] }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end
      end

      it 'does not raise and isolates the error to the failing league' do
        expect { described_class.new.perform }.not_to raise_error
      end

      it 'logs a warning for the unavailable league' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_matching(/SyncGcdJob.*Scraper unavailable.*CBLOL/))
        described_class.new.perform
      end
    end

    context 'job configuration' do
      it 'uses the default queue' do
        expect(described_class.new.sidekiq_options_hash['queue']).to eq('default')
      end

      it 'defines 5 default leagues' do
        expect(Scouting::SyncGcdJob::LEAGUES).to contain_exactly('CBLOL', 'LCK', 'LEC', 'LCS', 'LPL')
      end
    end
  end
end
