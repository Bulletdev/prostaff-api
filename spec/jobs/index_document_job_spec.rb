# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::IndexDocumentJob, type: :job do
  let(:org)    { create(:organization) }
  let(:player) { create(:player, organization: org) }

  describe '#perform' do
    context 'when MEILISEARCH_CLIENT is nil' do
      before { stub_const('MEILISEARCH_CLIENT', nil) }

      it 'returns early without raising' do
        expect { described_class.perform_now('Player', player.id) }.not_to raise_error
      end
    end

    context 'when record does not exist' do
      let(:fake_client) { instance_double('Meilisearch::Client') }
      let(:fake_index)  { instance_double('Meilisearch::Index') }

      before do
        stub_const('MEILISEARCH_CLIENT', fake_client)
        allow(fake_client).to receive(:index).and_return(fake_index)
        allow(Player).to receive(:meili_index_name).and_return('players')
      end

      it 'returns early without calling add_or_update_documents' do
        expect(fake_index).not_to receive(:add_or_update_documents)
        described_class.perform_now('Player', '00000000-0000-0000-0000-000000000000')
      end
    end

    context 'when Meilisearch raises an error' do
      let(:fake_client) { instance_double('Meilisearch::Client') }
      let(:fake_index)  { instance_double('Meilisearch::Index') }

      before do
        stub_const('MEILISEARCH_CLIENT', fake_client)
        allow(fake_client).to receive(:index).and_return(fake_index)
        allow(Player).to receive(:meili_index_name).and_return('players')
        # Stub find_by at class level because OrganizationScoped default_scope returns nil
        # when Current.organization_id is not set (as in unit test context)
        allow(Player).to receive(:find_by).and_return(player)
        allow(player).to receive(:to_meili_document).and_return({})
        allow(fake_index).to receive(:add_or_update_documents).and_raise(StandardError, 'Meili down')
      end

      it 're-raises so Sidekiq can retry' do
        expect { described_class.perform_now('Player', player.id) }.to raise_error(StandardError, 'Meili down')
      end
    end

    it 'is enqueued on the search queue' do
      expect(described_class.queue_name).to eq('search')
    end
  end
end
