# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RiotApiPingJob, type: :job do
  describe '#perform' do
    context 'when RIOT_API_KEY is not configured' do
      before { allow(ENV).to receive(:fetch).and_call_original }

      it 'skips the ping without raising' do
        stub_const('ENV', ENV.to_h.merge('RIOT_API_KEY' => nil))
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when RIOT_API_KEY is present and Riot API responds with success' do
      before do
        stub_const('ENV', ENV.to_h.merge('RIOT_API_KEY' => 'test-api-key'))

        stub_request(:get, 'https://br1.api.riotgames.com/lol/status/v4/platform-data')
          .with(headers: { 'X-Riot-Token' => 'test-api-key' })
          .to_return(status: 200, body: { name: 'BR', slug: 'br' }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when Riot API returns a non-success status' do
      before do
        stub_const('ENV', ENV.to_h.merge('RIOT_API_KEY' => 'test-api-key'))

        stub_request(:get, 'https://br1.api.riotgames.com/lol/status/v4/platform-data')
          .to_return(status: 429, headers: { 'Retry-After' => '60' })
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when Riot API is unreachable' do
      before do
        stub_const('ENV', ENV.to_h.merge('RIOT_API_KEY' => 'test-api-key'))

        stub_request(:get, 'https://br1.api.riotgames.com/lol/status/v4/platform-data')
          .to_raise(Net::OpenTimeout)
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'job configuration' do
      it 'uses the low queue' do
        expect(described_class.queue_name).to eq('low')
      end
    end
  end
end
