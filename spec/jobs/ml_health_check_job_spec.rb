# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MlHealthCheckJob, type: :job do
  describe '#perform' do
    context 'when ML service is healthy' do
      before do
        stub_request(:get, /localhost:8001\/health/)
          .to_return(
            status: 200,
            body: { model_loaded: true, status: 'ok' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when ML service returns model_loaded=false' do
      before do
        stub_request(:get, /localhost:8001\/health/)
          .to_return(
            status: 200,
            body: { model_loaded: false }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when ML service returns non-success status' do
      before do
        stub_request(:get, /localhost:8001\/health/)
          .to_return(status: 503, body: 'Service Unavailable')
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when ML service times out' do
      before do
        stub_request(:get, /localhost:8001\/health/)
          .to_timeout
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when ML service is unreachable' do
      before do
        stub_request(:get, /localhost:8001\/health/)
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when ML service returns invalid JSON' do
      before do
        stub_request(:get, /localhost:8001\/health/)
          .to_return(status: 200, body: 'not-json', headers: { 'Content-Type' => 'text/plain' })
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'job configuration' do
      it 'uses the low_priority queue' do
        expect(described_class.queue_name).to eq('low_priority')
      end
    end
  end
end
