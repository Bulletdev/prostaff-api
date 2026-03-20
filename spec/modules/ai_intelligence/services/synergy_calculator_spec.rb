# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SynergyCalculator do
  describe '.call' do
    context 'when both champions have vectors' do
      before do
        create(:ai_champion_vector, champion_name: 'Jinx',   vector_data: [0.8, 0.6, 0.3, 0.25, 0.7], games_count: 20)
        create(:ai_champion_vector, champion_name: 'Thresh', vector_data: [0.7, 0.2, 0.1, 0.15, 0.1], games_count: 15)
      end

      subject(:result) { described_class.call(champion_a: 'Jinx', champion_b: 'Thresh') }

      it 'returns a score between 0 and 1' do
        expect(result[:score]).to be_between(0.0, 1.0)
      end

      it 'returns the minimum games_count of the two champions' do
        expect(result[:games]).to eq(15)
      end

      it 'is case-insensitive' do
        result_lower = described_class.call(champion_a: 'jinx', champion_b: 'thresh')
        expect(result_lower[:score]).to eq(result[:score])
      end
    end

    context 'when identical vectors are compared (perfect cosine similarity)' do
      before do
        vec = [0.6, 0.5, 0.3, 0.25, 0.4]
        create(:ai_champion_vector, champion_name: 'ChampA', vector_data: vec, games_count: 10)
        create(:ai_champion_vector, champion_name: 'ChampB', vector_data: vec, games_count: 10)
      end

      it 'returns score close to 1.0' do
        result = described_class.call(champion_a: 'ChampA', champion_b: 'ChampB')
        expect(result[:score]).to be_within(0.001).of(1.0)
      end
    end

    context 'when one champion has no vector' do
      before do
        create(:ai_champion_vector, champion_name: 'Jinx', vector_data: [0.8, 0.6, 0.3, 0.25, 0.7], games_count: 20)
      end

      it 'returns low-confidence default score' do
        result = described_class.call(champion_a: 'Jinx', champion_b: 'UnknownChamp')
        expect(result[:score]).to eq(0.5)
        expect(result[:confidence]).to eq(:low)
      end
    end
  end
end
