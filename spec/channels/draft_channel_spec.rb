# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:draft_plan)   { create(:draft_plan, organization: organization, created_by: user, updated_by: user) }

  before do
    stub_connection(current_user: user, current_player: nil, current_org_id: organization.id)
  end

  describe '#subscribed' do
    context 'with a valid draft_id belonging to the user org' do
      it 'subscribes to the org-scoped draft stream' do
        subscribe(draft_id: draft_plan.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("draft_#{organization.id}_#{draft_plan.id}")
      end
    end

    context 'when draft_id is missing' do
      it 'rejects the subscription' do
        subscribe(draft_id: nil)
        expect(subscription).to be_rejected
      end
    end

    context 'when draft_id does not exist' do
      it 'rejects the subscription' do
        subscribe(draft_id: SecureRandom.uuid)
        expect(subscription).to be_rejected
      end
    end

    context 'when draft belongs to a different organization (cross-org isolation)' do
      let(:other_org)   { create(:organization) }
      let(:other_user)  { create(:user, :admin, organization: other_org) }
      let(:other_draft) do
        create(:draft_plan, organization: other_org, created_by: other_user, updated_by: other_user)
      end

      it 'rejects the subscription and does not expose foreign draft stream' do
        subscribe(draft_id: other_draft.id)
        expect(subscription).to be_rejected
      end
    end

    context 'when current_org_id is blank' do
      before do
        stub_connection(current_user: user, current_player: nil, current_org_id: nil)
      end

      it 'rejects the subscription' do
        subscribe(draft_id: draft_plan.id)
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    it 'stops all streams without error' do
      subscribe(draft_id: draft_plan.id)
      expect { unsubscribe }.not_to raise_error
    end
  end

  describe '#picks_updated' do
    # NOTE: ActionCable runs with the Redis adapter in the Docker container
    # (RAILS_ENV=development). The test-adapter helpers (have_broadcasted_to, broadcasts())
    # are unavailable; instead we assert on ActionCable.server.broadcast directly.
    let(:fake_result) do
      DraftAnalyzer::Result.new(
        win_probability: 0.57,
        confidence: 0.80,
        source: 'ml',
        low_sample: false,
        suggested_picks: ['Jinx'],
        synergy_scores: {},
        counter_scores: {}
      )
    end

    before do
      subscribe(draft_id: draft_plan.id)
      allow(DraftAnalyzer).to receive(:call).and_return(fake_result)
      allow(SynergyMatrixService).to receive(:call).and_return(
        { champions: [], matrix: [], top_pairs: [], weakest_pairs: [] }
      )
      allow(ChampionWinrateService).to receive(:bulk_lookup).and_return({})
      allow(ActionCable.server).to receive(:broadcast)
    end

    context 'with valid picks (team_a non-empty)' do
      it 'calls ActionCable.server.broadcast for the draft stream' do
        perform :picks_updated,
                team_a: %w[Garen Ahri Jinx Thresh Graves],
                team_b: %w[Yasuo Zed Caitlyn Lulu Renekton],
                patch: '14.10'

        expect(ActionCable.server).to have_received(:broadcast)
          .with("draft_#{organization.id}_#{draft_plan.id}", hash_including(type: 'ai_update'))
      end

      it 'broadcasts a win_probability payload in [0.0, 1.0]' do
        perform :picks_updated,
                team_a: %w[Garen Ahri],
                team_b: [],
                patch: '14.10'

        expect(ActionCable.server).to have_received(:broadcast) do |_stream, payload|
          win_prob = payload.dig(:payload, :win_probability)
          expect(win_prob).to be_between(0.0, 1.0)
        end
      end

      it 'includes expected keys in the broadcast payload' do
        perform :picks_updated, team_a: %w[Jinx Ahri], team_b: [], patch: '14.10'

        expect(ActionCable.server).to have_received(:broadcast) do |_stream, payload|
          expect(payload[:type]).to eq('ai_update')
          expect(payload[:payload]).to include(
            :win_probability, :confidence, :source, :suggested_picks
          )
        end
      end
    end

    context 'with empty teams' do
      it 'does not call ActionCable.server.broadcast' do
        perform :picks_updated, team_a: [], team_b: []
        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end
  end
end
