# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftSuggester do
  let(:team_a) { %w[Jinx Thresh Azir Vi] }
  let(:team_b) { %w[Caitlyn Lulu Viktor Lee\ Sin] }

  before do
    %w[Garen Orianna Lissandra Shen Zed].each_with_index do |champ, i|
      create(:ai_champion_vector,
             champion_name: champ,
             vector_data: [0.5 + i * 0.02, 0.4, 0.2, 0.2, 0.4],
             games_count: 10 + i)
    end
  end

  describe '.call' do
    subject(:suggestions) { described_class.call(team_a:, team_b:) }

    it 'returns an array' do
      expect(suggestions).to be_an(Array)
    end

    it 'returns at most 3 suggestions' do
      expect(suggestions.size).to be <= 3
    end

    it 'does not suggest already picked champions' do
      all_picked = (team_a + team_b).map(&:downcase)
      suggestions.each { |s| expect(all_picked).not_to include(s.downcase) }
    end

    it 'suggests champions from the vector pool' do
      pool = AiChampionVector.pluck(:champion_name).map(&:downcase)
      suggestions.each { |s| expect(pool).to include(s.downcase) }
    end
  end
end
