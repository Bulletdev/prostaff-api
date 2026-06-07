# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TournamentChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:tournament)   { create(:tournament) }

  before do
    stub_connection(current_user: user, current_org_id: organization.id)
  end

  describe '#subscribed' do
    context 'with a valid tournament_id' do
      it 'subscribes and opens the tournament stream' do
        subscribe(tournament_id: tournament.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("tournament_#{tournament.id}")
      end
    end

    context 'when tournament_id is missing' do
      it 'rejects the subscription' do
        subscribe(tournament_id: nil)
        expect(subscription).to be_rejected
      end
    end

    context 'when tournament_id does not exist' do
      it 'rejects the subscription' do
        subscribe(tournament_id: SecureRandom.uuid)
        expect(subscription).to be_rejected
      end
    end

    context 'when subscribing as an anonymous connection (no current_user)' do
      before do
        stub_connection(current_user: nil, current_org_id: nil)
      end

      it 'still accepts a valid tournament subscription (spectator access)' do
        subscribe(tournament_id: tournament.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("tournament_#{tournament.id}")
      end
    end
  end

  describe '#unsubscribed' do
    it 'stops all streams without error' do
      subscribe(tournament_id: tournament.id)
      expect { unsubscribe }.not_to raise_error
    end
  end
end
