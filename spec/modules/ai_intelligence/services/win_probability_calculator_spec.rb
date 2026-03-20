# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WinProbabilityCalculator do
  let(:team_a) { %w[Jinx Thresh Azir Vi Garen] }
  let(:team_b) { %w[Caitlyn Lulu Viktor Lee\ Sin Malphite] }

  describe '.call' do
    context 'with no historical data (all neutral)' do
      it 'returns probability close to 0.5' do
        result = described_class.call(team_a:, team_b:, synergies: {}, counters: {})
        expect(result[:score]).to be_within(0.05).of(0.5)
      end

      it 'returns zero confidence' do
        result = described_class.call(team_a:, team_b:, synergies: {}, counters: {})
        expect(result[:confidence]).to eq(0.0)
      end
    end

    context 'when team_a has strong counter advantage' do
      before do
        team_a.each do |a|
          team_b.each do |b|
            create(:ai_champion_matrix, champion_a: a, champion_b: b, wins_a: 8, total_games: 10)
          end
        end
      end

      it 'returns probability above 0.5' do
        result = described_class.call(team_a:, team_b:, synergies: {}, counters: {})
        expect(result[:score]).to be > 0.5
      end

      it 'returns high confidence' do
        result = described_class.call(team_a:, team_b:, synergies: {}, counters: {})
        expect(result[:confidence]).to be_within(0.01).of(1.0)
      end
    end

    context 'when team_b has counter advantage' do
      before do
        team_a.each do |a|
          team_b.each do |b|
            create(:ai_champion_matrix, champion_a: a, champion_b: b, wins_a: 2, total_games: 10)
          end
        end
      end

      it 'returns probability below 0.5' do
        result = described_class.call(team_a:, team_b:, synergies: {}, counters: {})
        expect(result[:score]).to be < 0.5
      end
    end

    it 'returns score between 0 and 1' do
      result = described_class.call(team_a:, team_b:, synergies: {}, counters: {})
      expect(result[:score]).to be_between(0.0, 1.0)
    end
  end
end
