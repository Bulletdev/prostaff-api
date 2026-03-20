# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CounterCalculator do
  describe '.call' do
    context 'when matrix entry exists with sufficient games' do
      before do
        create(:ai_champion_matrix, champion_a: 'Azir', champion_b: 'Viktor', wins_a: 7, total_games: 10)
      end

      subject(:result) { described_class.call(attacker: 'Azir', defender: 'Viktor') }

      it 'returns correct win_rate score' do
        expect(result[:score]).to eq(0.7)
      end

      it 'returns positive advantage for attacker' do
        expect(result[:advantage]).to eq(0.2)
      end

      it 'returns full confidence (10 games = min sample)' do
        expect(result[:confidence]).to eq(1.0)
      end

      it 'returns game count' do
        expect(result[:games]).to eq(10)
      end

      it 'is case-insensitive' do
        result_lower = described_class.call(attacker: 'azir', defender: 'viktor')
        expect(result_lower[:score]).to eq(result[:score])
      end
    end

    context 'when matrix entry has fewer than MIN_GAMES' do
      before do
        create(:ai_champion_matrix, champion_a: 'Jinx', champion_b: 'Caitlyn', wins_a: 3, total_games: 5)
      end

      it 'returns partial confidence' do
        result = described_class.call(attacker: 'Jinx', defender: 'Caitlyn')
        expect(result[:confidence]).to eq(0.5)
      end
    end

    context 'when no matrix entry exists' do
      it 'returns neutral defaults' do
        result = described_class.call(attacker: 'UnknownA', defender: 'UnknownB')
        expect(result[:score]).to eq(0.5)
        expect(result[:advantage]).to eq(0.0)
        expect(result[:confidence]).to eq(0.0)
      end
    end
  end
end
