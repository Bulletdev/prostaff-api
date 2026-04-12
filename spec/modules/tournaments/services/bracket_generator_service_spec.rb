# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BracketGeneratorService do
  let(:tournament) { create(:tournament, :in_progress, max_teams: 16) }

  subject(:result) { described_class.new(tournament).call }

  describe '#call' do
    it 'creates exactly 30 matches for a 16-team double elimination' do
      expect(result.values.flatten.count).to eq(30)
    end

    it 'creates 15 upper bracket matches' do
      ub = result.values.flatten.select { |m| m.bracket_side == 'upper' }
      expect(ub.count).to eq(15)
    end

    it 'creates 14 lower bracket matches' do
      lb = result.values.flatten.select { |m| m.bracket_side == 'lower' }
      expect(lb.count).to eq(14)
    end

    it 'creates 1 grand final match' do
      gf = result.values.flatten.select { |m| m.bracket_side == 'grand_final' }
      expect(gf.count).to eq(1)
    end

    it 'wires UB Round 1 matches with winner and loser next matches' do
      ubr1 = result['UB Round 1']
      ubr1.each do |m|
        expect(m.next_match_winner_id).to be_present
        expect(m.next_match_loser_id).to be_present
      end
    end

    it 'leaves Grand Final with no next matches' do
      gf = result['Grand Final'].first
      expect(gf.next_match_winner_id).to be_nil
      expect(gf.next_match_loser_id).to be_nil
    end

    it 'sets all matches to scheduled status' do
      all = result.values.flatten
      expect(all).to all(have_attributes(status: 'scheduled'))
    end

    it 'raises if bracket already exists' do
      described_class.new(tournament).call
      expect { described_class.new(tournament).call }.to raise_error(RuntimeError, /already generated/)
    end

    it 'is wrapped in a transaction — no partial brackets on failure' do
      allow(TournamentMatch).to receive(:create!).and_call_original
      allow(TournamentMatch).to receive(:create!).once.and_raise(ActiveRecord::RecordInvalid)

      expect { described_class.new(tournament).call }.to raise_error(ActiveRecord::RecordInvalid)
      expect(tournament.tournament_matches.count).to eq(0)
    end
  end
end
