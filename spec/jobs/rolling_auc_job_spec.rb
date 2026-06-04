# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RollingAucJob, type: :job do
  describe '#perform' do
    context 'when fewer than MIN_SAMPLE predictions exist' do
      before do
        allow(MlPredictionLog).to receive_message_chain(:with_outcome, :recent, :to_a)
          .and_return([])
      end

      it 'returns early without raising' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when sufficient predictions exist' do
      let(:logs) do
        Array.new(60) do |i|
          double('MlPredictionLog',
                 blue_won: i.even?,
                 predicted_win_prob: i.even? ? 0.7 : 0.3)
        end
      end

      before do
        allow(MlPredictionLog).to receive_message_chain(:with_outcome, :recent, :to_a)
          .and_return(logs)
      end

      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(MlPredictionLog).to receive(:with_outcome).and_raise(StandardError, 'DB error')
      end

      it 'does not raise (rescues internally)' do
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
