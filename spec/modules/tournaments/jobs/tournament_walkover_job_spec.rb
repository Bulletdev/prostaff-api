# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tournaments::TournamentWalkoverJob, type: :job do
  let(:tournament) { create(:tournament, :in_progress) }
  let(:team_a)     { create(:tournament_team, :approved, tournament: tournament) }
  let(:team_b)     { create(:tournament_team, :approved, tournament: tournament) }
  let(:match) do
    create(:tournament_match, :checkin_open, tournament: tournament,
                                             team_a: team_a, team_b: team_b)
  end

  describe '#perform' do
    context 'when both teams checked in' do
      before do
        create(:team_checkin, tournament_match: match, tournament_team: team_a)
        create(:team_checkin, tournament_match: match, tournament_team: team_b)
      end

      it 'does nothing — normal flow already started' do
        described_class.new.perform(match.id)
        expect(match.reload.status).to eq('checkin_open')
      end
    end

    context 'when only team_a checked in' do
      before { create(:team_checkin, tournament_match: match, tournament_team: team_a) }

      it 'applies walkover with team_a as winner' do
        described_class.new.perform(match.id)
        expect(match.reload.winner_id).to eq(team_a.id)
      end

      it 'sets match status to walkover' do
        described_class.new.perform(match.id)
        expect(match.reload.status).to eq('walkover')
      end
    end

    context 'when only team_b checked in' do
      before { create(:team_checkin, tournament_match: match, tournament_team: team_b) }

      it 'applies walkover with team_b as winner' do
        described_class.new.perform(match.id)
        expect(match.reload.winner_id).to eq(team_b.id)
      end
    end

    context 'when neither team checked in' do
      it 'sets match to walkover with no winner' do
        described_class.new.perform(match.id)
        expect(match.reload.status).to eq('walkover')
        expect(match.reload.winner_id).to be_nil
      end
    end

    context 'when match is not in checkin_open status' do
      before { match.update!(status: 'in_progress') }

      it 'does nothing' do
        described_class.new.perform(match.id)
        expect(match.reload.status).to eq('in_progress')
      end
    end

    context 'when match does not exist' do
      it 'returns without raising' do
        expect { described_class.new.perform('nonexistent-uuid') }.not_to raise_error
      end
    end
  end
end
