# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftSuggester do
  # team_a: Jinx (adc), Thresh (support), Azir (mid), Vi (jungle) — 4 picks, top open
  let(:team_a) { %w[Jinx Thresh Azir Vi] }
  let(:team_b) { %w[Caitlyn Lulu Viktor Lee\ Sin] }

  before do
    # Garen/Shen = top, Orianna/Lissandra/Zed = mid
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

    context 'role coverage filter with 4 picks in team_a' do
      # team_a has adc + support + mid + jungle covered; top is open.
      # Pool has Garen/Shen (top) and Orianna/Lissandra/Zed (mid).
      # Mid is already filled by Azir, so Orianna/Lissandra/Zed should be excluded.
      # Garen and Shen (top) should be included since top is open.
      it 'excludes candidates whose role is already filled' do
        mid_champions = %w[Orianna Lissandra Zed].map(&:downcase)
        suggestions.each { |s| expect(mid_champions).not_to include(s.downcase) }
      end

      it 'includes candidates whose role is not yet filled' do
        top_champions = %w[Garen Shen].map(&:downcase)
        expect(suggestions.map(&:downcase)).to include(*top_champions).or \
          include(top_champions.first).or include(top_champions.last)
      end
    end

    context 'role coverage filter with fewer than 4 picks' do
      # With 3 picks, role filter is disabled — all non-taken champions are eligible.
      let(:team_a) { %w[Jinx Thresh Azir] }

      it 'does not filter by role when team_a has fewer than 4 picks' do
        mid_champions = %w[Orianna Lissandra Zed].map(&:downcase)
        # At least one mid champion must be eligible (filter is off)
        expect(suggestions.map(&:downcase) & mid_champions).not_to be_empty
      end
    end

    context 'when a candidate role is unknown (not in CHAMPION_ROLES)' do
      before do
        create(:ai_champion_vector,
               champion_name: 'UnknownChamp',
               vector_data: [0.99, 0.9, 0.9, 0.9, 0.9],
               games_count: 100)
      end

      it 'includes the unknown champion conservatively' do
        expect(suggestions.map(&:downcase)).to include('unknownchamp')
      end
    end

    context 'when bans are provided' do
      subject(:suggestions) { described_class.call(team_a:, team_b:, bans: %w[Garen Shen]) }

      it 'does not suggest banned champions' do
        expect(suggestions.map(&:downcase)).not_to include('garen', 'shen')
      end
    end
  end
end
