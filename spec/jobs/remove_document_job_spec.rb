# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::RemoveDocumentJob, type: :job do
  describe '#perform' do
    context 'when MEILISEARCH_CLIENT is nil' do
      before { stub_const('MEILISEARCH_CLIENT', nil) }

      it 'returns early without raising' do
        expect { described_class.perform_now('Player', 'some-uuid') }.not_to raise_error
      end
    end

    context 'when Meilisearch client is configured' do
      let(:fake_client) { instance_double('Meilisearch::Client') }
      let(:fake_index)  { instance_double('Meilisearch::Index') }

      before do
        stub_const('MEILISEARCH_CLIENT', fake_client)
        allow(fake_client).to receive(:index).and_return(fake_index)
        allow(Player).to receive(:meili_index_name).and_return('players')
      end

      it 'calls delete_document with the given id' do
        record_id = 'some-uuid'
        expect(fake_index).to receive(:delete_document).with(record_id)
        described_class.perform_now('Player', record_id)
      end

      it 're-raises errors so Sidekiq can retry' do
        allow(fake_index).to receive(:delete_document).and_raise(StandardError, 'Meili down')
        expect { described_class.perform_now('Player', 'some-uuid') }.to raise_error(StandardError)
      end
    end

    it 'is enqueued on the search queue' do
      expect(described_class.queue_name).to eq('search')
    end
  end
end
