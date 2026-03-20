# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftAnalyzer do
  let(:team_a) { %w[Jinx Thresh Azir Vi Garen] }
  let(:team_b) { %w[Caitlyn Lulu Viktor Lee\ Sin Malphite] }

  describe '.call' do
    subject(:result) { described_class.call(team_a:, team_b:) }

    it 'returns a Result struct' do
      expect(result).to be_a(described_class::Result)
    end

    it 'returns win_probability between 0 and 1' do
      expect(result.win_probability).to be_between(0.0, 1.0)
    end

    it 'returns confidence between 0 and 1' do
      expect(result.confidence).to be_between(0.0, 1.0)
    end

    it 'returns synergy_scores as a hash' do
      expect(result.synergy_scores).to be_a(Hash)
    end

    it 'returns counter_scores as a hash' do
      expect(result.counter_scores).to be_a(Hash)
    end

    it 'has synergy pairs for all intra-team combinations' do
      expected_pairs = team_a.combination(2).to_a + team_b.combination(2).to_a
      expect(result.synergy_scores.keys).to match_array(expected_pairs)
    end

    it 'has counter pairs for all cross-team matchups' do
      expected_pairs = team_a.product(team_b)
      expect(result.counter_scores.keys).to match_array(expected_pairs)
    end

    it 'sets low_sample based on confidence threshold' do
      expect(result.low_sample).to eq(result.confidence < 0.5)
    end

    it 'does not return suggested_picks for a full 5v5 draft' do
      expect(result.suggested_picks).to be_nil
    end

    context 'when team_a has 4 picks' do
      let(:team_a) { %w[Jinx Thresh Azir Vi] }

      before do
        create(:ai_champion_vector, champion_name: 'Garen',     vector_data: [0.6, 0.5, 0.2, 0.2, 0.5], games_count: 15)
        create(:ai_champion_vector, champion_name: 'Orianna',   vector_data: [0.7, 0.6, 0.3, 0.25, 0.6], games_count: 20)
        create(:ai_champion_vector, champion_name: 'Lissandra', vector_data: [0.65, 0.4, 0.25, 0.2, 0.5], games_count: 12)
      end

      it 'returns top-3 suggested picks' do
        expect(result.suggested_picks).to be_an(Array)
        expect(result.suggested_picks.size).to eq(3)
      end

      it 'does not suggest already picked champions' do
        all_picked = (team_a + team_b).map(&:downcase)
        result.suggested_picks.each do |suggestion|
          expect(all_picked).not_to include(suggestion.downcase)
        end
      end
    end
  end
end
